import SwiftUI
import CoreLocation

// MARK: - Location manager

struct EquatableCoordinate: Equatable {
    let latitude: Double
    let longitude: Double
}

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate: EquatableCoordinate?
    @Published var authStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func requestIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        coordinate = EquatableCoordinate(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse
            || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}

// MARK: - WeatherTab root

struct WeatherTab: View {
    @StateObject private var locMgr = LocationManager()
    @StateObject private var weatherVM = WeatherViewModel()

    // Fallback: Tokyo
    private let defaultLat = 35.6812
    private let defaultLon = 139.7671

    var body: some View {
        GeometryReader { proxy in
            let safeWidth = max(1, proxy.size.width - proxy.safeAreaInsets.leading - proxy.safeAreaInsets.trailing)
            let edgeInset: CGFloat = safeWidth <= 340 ? 6 : (safeWidth <= 390 ? 9 : 18)
            let contentWidth = min(430, max(1, safeWidth - edgeInset * 2))
            let metrics = LayoutMetrics(width: contentWidth, height: proxy.size.height)

            ZStack(alignment: .top) {
                // Same backdrop as main screen
                LinearGradient(
                    colors: [Color(hex: 0x0A3E46), Color(hex: 0x061520)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: metrics.sectionSpacing) {
                        weatherHeader(metrics)
                        if let snap = weatherVM.snapshot {
                            currentCard(snap.current, location: snap.locationName, metrics: metrics)
                            dailyCard(snap.daily, metrics: metrics)
                        } else if weatherVM.isLoading {
                            loadingCard(metrics)
                        } else if let err = weatherVM.errorMessage {
                            errorCard(err, metrics: metrics)
                        } else {
                            placeholderCard(metrics)
                        }
                    }
                    .frame(width: contentWidth, alignment: .topLeading)
                    .padding(.horizontal, edgeInset)
                    .frame(width: safeWidth, alignment: .center)
                    .padding(.top, max(12, proxy.safeAreaInsets.top + 8))
                    .padding(.bottom, max(22, proxy.safeAreaInsets.bottom + 22))
                }
                .scrollIndicators(.hidden)
            }
        }
        .onChange(of: locMgr.coordinate) { _, coord in
            guard let coord else { return }
            Task { await weatherVM.load(latitude: coord.latitude, longitude: coord.longitude) }
        }
        .task {
            locMgr.requestIfNeeded()
            // Load with default immediately; update when location arrives
            await weatherVM.load(latitude: defaultLat, longitude: defaultLon)
        }
    }

    // MARK: Header

    private func weatherHeader(_ metrics: LayoutMetrics) -> some View {
        CompactPanel(metrics: metrics, style: .hero) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(Lang.pick("天気予報", "Weather Forecast"))
                        .font(.system(size: metrics.titleSize, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(Lang.pick("Open-Meteo 7日間", "Open-Meteo 7-Day"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
                .layoutPriority(1)

                Spacer(minLength: 6)

                Button {
                    Task {
                        let lat = locMgr.coordinate?.latitude ?? defaultLat
                        let lon = locMgr.coordinate?.longitude ?? defaultLon
                        await weatherVM.load(latitude: lat, longitude: lon)
                    }
                } label: {
                    Image(systemName: weatherVM.isLoading ? "waveform" : "arrow.clockwise")
                        .font(.headline.weight(.bold))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.13), in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .accessibilityLabel(Lang.pick("天気を更新", "Refresh weather"))
            }
        }
    }

    // MARK: Current conditions

    private func currentCard(_ current: WeatherCurrent, location: String, metrics: LayoutMetrics) -> some View {
        CompactPanel(metrics: metrics) {
            VStack(alignment: .leading, spacing: 12) {
                Label(location, systemImage: "location.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.cyan.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: current.icon)
                        .font(.system(size: 48))
                        .symbolRenderingMode(.multicolor)
                        .frame(width: 60)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(current.temperature.rounded()))°C")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(current.condition)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    WeatherMetricTile(
                        icon: "wind",
                        title: Lang.pick("風速", "Wind"),
                        value: "\(Int(current.windSpeed.rounded())) km/h \(current.windDirectionLabel)"
                    )
                    WeatherMetricTile(
                        icon: "humidity.fill",
                        title: Lang.pick("湿度", "Humidity"),
                        value: "\(current.humidity)%"
                    )
                    WeatherMetricTile(
                        icon: "umbrella.fill",
                        title: Lang.pick("降水確率", "Rain Prob."),
                        value: "\(current.precipProbability)%"
                    )
                    WeatherMetricTile(
                        icon: "thermometer.medium",
                        title: Lang.pick("体感", "Feels Like"),
                        value: "\(Int(current.temperature.rounded()))°C"
                    )
                }
            }
        }
    }

    // MARK: 7-day forecast

    private func dailyCard(_ days: [WeatherDay], metrics: LayoutMetrics) -> some View {
        CompactPanel(metrics: metrics) {
            VStack(alignment: .leading, spacing: 10) {
                Label(
                    Lang.pick("7日間の予報", "7-Day Forecast"),
                    systemImage: "calendar"
                )
                .font(.headline.weight(.black))
                .foregroundStyle(.white)

                ForEach(days) { day in
                    dailyRow(day, metrics: metrics)
                }
            }
        }
    }

    private func dailyRow(_ day: WeatherDay, metrics: LayoutMetrics) -> some View {
        HStack(spacing: 10) {
            Text(day.date.weekdayLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 32, alignment: .leading)
                .lineLimit(1)

            Image(systemName: day.icon)
                .font(.title3)
                .symbolRenderingMode(.multicolor)
                .frame(width: 28)

            Text(day.condition)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Rain probability bar
            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .font(.caption2)
                    .foregroundStyle(.cyan.opacity(0.8))
                Text("\(day.precipProbability)%")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.cyan.opacity(0.9))
                    .frame(width: 32, alignment: .trailing)
            }

            HStack(spacing: 4) {
                Text("\(Int(day.tempMin.rounded()))°")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.55))
                Text("/")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
                Text("\(Int(day.tempMax.rounded()))°")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: State cards

    private func loadingCard(_ metrics: LayoutMetrics) -> some View {
        CompactPanel(metrics: metrics) {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(.cyan)
                Text(Lang.pick("天気データを取得中…", "Loading weather…"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
        }
    }

    private func errorCard(_ message: String, metrics: LayoutMetrics) -> some View {
        CompactPanel(metrics: metrics) {
            VStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.5))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
        }
    }

    private func placeholderCard(_ metrics: LayoutMetrics) -> some View {
        CompactPanel(metrics: metrics) {
            Text(Lang.pick("位置情報を取得中…", "Detecting location…"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
        }
    }
}

// MARK: - Supporting views

private struct WeatherMetricTile: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(.cyan.opacity(0.85))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                Text(value)
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Date helpers

private extension Date {
    var weekdayLabel: String {
        if Lang.isJapanese {
            let f = DateFormatter()
            f.locale = Locale(identifier: "ja_JP")
            f.dateFormat = "E"
            return f.string(from: self)
        } else {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US")
            f.dateFormat = "EEE"
            return f.string(from: self)
        }
    }
}
