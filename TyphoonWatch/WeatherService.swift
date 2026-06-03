import Foundation
import CoreLocation

// MARK: - Weather models

struct WeatherDay: Identifiable {
    let id = UUID()
    let date: Date
    let tempMax: Double
    let tempMin: Double
    let precipProbability: Int
    let weatherCode: Int

    var icon: String {
        switch weatherCode {
        case 0:           return "sun.max.fill"
        case 1, 2:        return "cloud.sun.fill"
        case 3:           return "cloud.fill"
        case 45, 48:      return "cloud.fog.fill"
        case 51, 53, 55,
             61, 63, 65:  return "cloud.rain.fill"
        case 71, 73, 75:  return "cloud.snow.fill"
        case 80, 81, 82:  return "cloud.heavyrain.fill"
        case 95, 96, 99:  return "cloud.bolt.rain.fill"
        default:          return "cloud.fill"
        }
    }

    var conditionJa: String {
        switch weatherCode {
        case 0:           return "快晴"
        case 1:           return "晴れ"
        case 2:           return "晴れ時々曇り"
        case 3:           return "曇り"
        case 45, 48:      return "霧"
        case 51, 53, 55:  return "霧雨"
        case 61, 63, 65:  return "雨"
        case 71, 73, 75:  return "雪"
        case 80, 81, 82:  return "強い雨"
        case 95, 96, 99:  return "雷雨"
        default:          return "不明"
        }
    }

    var conditionEn: String {
        switch weatherCode {
        case 0:           return "Clear"
        case 1:           return "Sunny"
        case 2:           return "Partly Cloudy"
        case 3:           return "Overcast"
        case 45, 48:      return "Fog"
        case 51, 53, 55:  return "Drizzle"
        case 61, 63, 65:  return "Rain"
        case 71, 73, 75:  return "Snow"
        case 80, 81, 82:  return "Heavy Rain"
        case 95, 96, 99:  return "Thunderstorm"
        default:          return "Unknown"
        }
    }

    var condition: String { Lang.pick(conditionJa, conditionEn) }
}

struct WeatherCurrent {
    let temperature: Double
    let windSpeed: Double
    let windDirection: Int
    let humidity: Int
    let precipProbability: Int
    let weatherCode: Int

    var icon: String {
        WeatherDay(date: Date(), tempMax: 0, tempMin: 0,
                   precipProbability: 0, weatherCode: weatherCode).icon
    }
    var condition: String {
        WeatherDay(date: Date(), tempMax: 0, tempMin: 0,
                   precipProbability: 0, weatherCode: weatherCode).condition
    }

    var windDirectionLabel: String {
        let dirs: [String]
        if Lang.isJapanese {
            dirs = ["北","北北東","北東","東北東","東","東南東","南東","南南東",
                    "南","南南西","南西","西南西","西","西北西","北西","北北西"]
        } else {
            dirs = ["N","NNE","NE","ENE","E","ESE","SE","SSE",
                    "S","SSW","SW","WSW","W","WNW","NW","NNW"]
        }
        let idx = Int((Double(windDirection) / 22.5).rounded()) % 16
        return dirs[idx]
    }
}

struct WeatherSnapshot {
    let current: WeatherCurrent
    let daily: [WeatherDay]
    let locationName: String
}

// MARK: - Open-Meteo response models

private struct OpenMeteoResponse: Decodable {
    let daily: OpenMeteoDailyData
    let hourly: OpenMeteoHourlyData
}

private struct OpenMeteoDailyData: Decodable {
    let time: [String]
    let temperature_2m_max: [Double?]
    let temperature_2m_min: [Double?]
    let precipitation_probability_max: [Int?]
    let weathercode: [Int?]
}

private struct OpenMeteoHourlyData: Decodable {
    let time: [String]
    let temperature_2m: [Double?]
    let precipitation_probability: [Int?]
    let windspeed_10m: [Double?]
    let winddirection_10m: [Int?]
    let relativehumidity_2m: [Int?]
}

// MARK: - Service

@MainActor
final class WeatherViewModel: ObservableObject {
    @Published var snapshot: WeatherSnapshot?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = WeatherService()
    private let geocoder = CLGeocoder()

    func load(latitude: Double, longitude: Double) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let weather = try await service.fetch(latitude: latitude, longitude: longitude)
            // Reverse geocode for location name
            let loc = CLLocation(latitude: latitude, longitude: longitude)
            let placemarks = try? await geocoder.reverseGeocodeLocation(loc)
            let name = placemarks?.first?.locality
                ?? placemarks?.first?.administrativeArea
                ?? "\(String(format: "%.1f", latitude))N \(String(format: "%.1f", longitude))E"
            snapshot = WeatherSnapshot(current: weather.current, daily: weather.daily, locationName: name)
        } catch {
            errorMessage = Lang.pick("天気データを取得できませんでした", "Could not fetch weather data")
        }
    }
}

struct WeatherService {
    func fetch(latitude: Double, longitude: Double) async throws -> (current: WeatherCurrent, daily: [WeatherDay]) {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude",   value: String(format: "%.4f", latitude)),
            .init(name: "longitude",  value: String(format: "%.4f", longitude)),
            .init(name: "daily",      value: "temperature_2m_max,temperature_2m_min,precipitation_probability_max,weathercode"),
            .init(name: "hourly",     value: "temperature_2m,precipitation_probability,windspeed_10m,winddirection_10m,relativehumidity_2m"),
            .init(name: "timezone",   value: "Asia/Tokyo"),
            .init(name: "forecast_days", value: "7")
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        return parse(decoded)
    }

    private func parse(_ r: OpenMeteoResponse) -> (current: WeatherCurrent, daily: [WeatherDay]) {
        // Current: find nearest hourly index to now
        let now = Date()
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        let hourlyDates = r.hourly.time.compactMap { fmt.date(from: $0) }
        let nowIdx = hourlyDates.enumerated().min(by: { abs($0.element.timeIntervalSince(now)) < abs($1.element.timeIntervalSince(now)) })?.offset ?? 0

        let current = WeatherCurrent(
            temperature:       (r.hourly.temperature_2m[safe: nowIdx] ?? nil)          ?? 20,
            windSpeed:         (r.hourly.windspeed_10m[safe: nowIdx] ?? nil)           ?? 0,
            windDirection:     (r.hourly.winddirection_10m[safe: nowIdx] ?? nil)       ?? 0,
            humidity:          (r.hourly.relativehumidity_2m[safe: nowIdx] ?? nil)     ?? 0,
            precipProbability: (r.hourly.precipitation_probability[safe: nowIdx] ?? nil) ?? 0,
            weatherCode:       (r.daily.weathercode[safe: 0] ?? nil)                   ?? 0
        )

        let dailyFmt = DateFormatter()
        dailyFmt.dateFormat = "yyyy-MM-dd"
        let daily: [WeatherDay] = r.daily.time.enumerated().compactMap { i, dateStr in
            guard let date = dailyFmt.date(from: dateStr) else { return nil }
            return WeatherDay(
                date: date,
                tempMax:           (r.daily.temperature_2m_max[safe: i] ?? nil)             ?? 25,
                tempMin:           (r.daily.temperature_2m_min[safe: i] ?? nil)             ?? 18,
                precipProbability: (r.daily.precipitation_probability_max[safe: i] ?? nil)  ?? 0,
                weatherCode:       (r.daily.weathercode[safe: i] ?? nil)                    ?? 0
            )
        }
        return (current, daily)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
