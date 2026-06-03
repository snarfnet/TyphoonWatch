import Foundation
import SwiftUI

@MainActor
final class TyphoonViewModel: ObservableObject {
    @Published var storm = TyphoonService.sampleStorm
    @Published var selectedRegion = AppData.regions[0]
    @Published var isLoading = false
    @Published var statusText = "サンプル"

    private let service = TyphoonService()

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            storm = try await service.fetchLatestStorm()
            statusText = "Digital Typhoon"
        } catch {
            storm = TyphoonService.sampleStorm
            statusText = "オフライン"
        }
    }

    var risk: RiskSnapshot {
        TyphoonService.risk(for: storm.points, region: selectedRegion)
    }
}

struct TyphoonService {
    func fetchLatestStorm() async throws -> TyphoonStorm {
        let year = Calendar.current.component(.year, from: Date())
        let url = URL(string: "https://agora.ex.nii.ac.jp/digital-typhoon/mf-json/wnp/\(year).ja.json")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let features = try JSONDecoder().decode([MovingFeature].self, from: data)
        let storms = features.compactMap(Self.normalize(feature:))

        guard let latest = storms.max(by: { $0.updatedAt < $1.updatedAt }) else {
            throw URLError(.cannotParseResponse)
        }

        return latest
    }

    static func risk(for points: [TyphoonPoint], region: MonitorRegion) -> RiskSnapshot {
        let closest = points.min { lhs, rhs in
            distanceKm(from: lhs, to: region) < distanceKm(from: rhs, to: region)
        }

        let closestKm = closest.map { distanceKm(from: $0, to: region) } ?? 9_999
        let maxWind = points.compactMap(\.wind).max()
        let distanceScore = max(0, 100 - closestKm / 6)
        let windScore = min(100, Double(maxWind ?? 0) * 1.2)
        let score = distanceScore * 0.62 + windScore * 0.38

        let level: RiskLevel
        let summary: String
        let actions: [String]

        if score > 72 {
            level = .alert
            summary = "台風が近く、風雨の影響を強く受けるおそれがあります。公式発表と避難情報を短い間隔で確認してください。"
            actions = ["警報と避難情報を確認", "停電、断水、交通停止に備える", "海沿いや川沿いに近づかない"]
        } else if score > 44 {
            level = .caution
            summary = "接近の可能性があります。雨、風、交通の乱れを早めに確認しておくと安心です。"
            actions = ["48時間以内の予報を確認", "雨雲レーダーと風予報を見る", "屋外の飛びやすい物を片付ける"]
        } else {
            level = .watch
            summary = "今のところ接近度は低めです。進路が変わる前提で、更新を確認してください。"
            actions = ["1日2回、進路を確認", "離島移動や欠航情報を見る", "発達傾向が強まったら通知対象に入れる"]
        }

        return RiskSnapshot(
            level: level,
            score: score,
            closestKm: closestKm,
            closestAt: closest?.time,
            maxWind: maxWind,
            summary: summary,
            actions: actions
        )
    }

    private static func normalize(feature: MovingFeature) -> TyphoonStorm? {
        guard let geometry = feature.temporalGeometry else { return nil }
        let pressure = feature.temporalProperties.first { $0.uom == "hPa" }
        let wind = feature.temporalProperties.first { $0.uom == "kt" }
        let formatter = ISO8601DateFormatter()

        let points: [TyphoonPoint] = geometry.coordinates.enumerated().compactMap { index, coordinate in
            guard coordinate.count >= 2,
                  geometry.datetimes.indices.contains(index),
                  let date = formatter.date(from: geometry.datetimes[index]) else { return nil }

            return TyphoonPoint(
                time: date,
                latitude: coordinate[1],
                longitude: coordinate[0],
                pressure: pressure?.values[safe: index].flatMap(Int.init),
                wind: wind?.values[safe: index].flatMap(Int.init),
                isForecast: false
            )
        }

        guard let latest = points.last, !points.isEmpty else { return nil }

        return TyphoonStorm(
            name: feature.properties?.name ?? "台風データ",
            source: "Digital Typhoon Mf-JSON",
            updatedAt: latest.time,
            points: points
        )
    }

    private static func distanceKm(from point: TyphoonPoint, to region: MonitorRegion) -> Double {
        let earth = 6_371.0
        let dLat = (region.latitude - point.latitude).degreesToRadians
        let dLon = (region.longitude - point.longitude).degreesToRadians
        let lat1 = point.latitude.degreesToRadians
        let lat2 = region.latitude.degreesToRadians
        let h = pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLon / 2), 2)
        return 2 * earth * asin(sqrt(h))
    }

    static let sampleStorm = TyphoonStorm(
        name: "台風サンプル 03W",
        source: "サンプルデータ",
        updatedAt: Date(),
        points: [
            .init(time: Date().addingTimeInterval(-21_600), latitude: 20.1, longitude: 131.7, pressure: 985, wind: 45, isForecast: false),
            .init(time: Date(), latitude: 21.0, longitude: 130.8, pressure: 975, wind: 55, isForecast: false),
            .init(time: Date().addingTimeInterval(43_200), latitude: 24.2, longitude: 128.4, pressure: 960, wind: 70, isForecast: true),
            .init(time: Date().addingTimeInterval(86_400), latitude: 26.4, longitude: 128.1, pressure: 965, wind: 65, isForecast: true),
            .init(time: Date().addingTimeInterval(129_600), latitude: 29.1, longitude: 129.0, pressure: 975, wind: 55, isForecast: true),
            .init(time: Date().addingTimeInterval(172_800), latitude: 32.4, longitude: 131.2, pressure: 985, wind: 45, isForecast: true)
        ]
    )
}

private struct MovingFeature: Decodable {
    let temporalProperties: [TemporalProperty]
    let temporalGeometry: TemporalGeometry?
    let properties: FeatureProperties?
}

private struct TemporalProperty: Decodable {
    let name: String?
    let uom: String?
    let values: [String]
}

private struct TemporalGeometry: Decodable {
    let datetimes: [String]
    let coordinates: [[Double]]
}

private struct FeatureProperties: Decodable {
    let name: String?
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
}
