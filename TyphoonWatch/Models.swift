import Foundation

struct MonitorRegion: Identifiable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
}

struct TyphoonPoint: Identifiable, Hashable {
    let id = UUID()
    let time: Date
    let latitude: Double
    let longitude: Double
    let pressure: Int?
    let wind: Int?
    let isForecast: Bool
}

struct TyphoonStorm: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var source: String
    var updatedAt: Date
    var points: [TyphoonPoint]
}

struct RiskSnapshot {
    let level: RiskLevel
    let score: Double
    let closestKm: Double
    let closestAt: Date?
    let maxWind: Int?
    let summary: String
    let actions: [String]
}

enum RiskLevel: String {
    case watch = "監視"
    case caution = "注意"
    case alert = "警戒"

    var colorHex: UInt {
        switch self {
        case .watch: return 0x63D4B2
        case .caution: return 0xF2B84B
        case .alert: return 0xFF6A4A
        }
    }
}

enum AppData {
    static let regions: [MonitorRegion] = [
        .init(id: "okinawa", name: "沖縄本島", latitude: 26.21, longitude: 127.68),
        .init(id: "miyako", name: "宮古島", latitude: 24.80, longitude: 125.28),
        .init(id: "kagoshima", name: "鹿児島", latitude: 31.60, longitude: 130.56),
        .init(id: "tokyo", name: "東京", latitude: 35.68, longitude: 139.76),
        .init(id: "osaka", name: "大阪", latitude: 34.69, longitude: 135.50),
        .init(id: "sendai", name: "仙台", latitude: 38.27, longitude: 140.87)
    ]

    static let feeds: [DataFeed] = [
        .init(name: "気象庁", detail: "公式の台風情報、警報、雲の動き", url: "https://www.jma.go.jp/bosai/map.html#contents=typhoon"),
        .init(name: "Digital Typhoon", detail: "西太平洋の台風進路データ", url: "https://agora.ex.nii.ac.jp/digital-typhoon/"),
        .init(name: "NOAA NHC GIS", detail: "予報円、風域、警戒域のGISデータ", url: "https://mapservices.weather.noaa.gov/tropical/rest/services/tropical/NHC_tropical_weather/MapServer?f=pjson"),
        .init(name: "JTWC", detail: "米軍合同台風警報センター", url: "https://www.metoc.navy.mil/jtwc/jtwc.html"),
        .init(name: "JAXA GSMaP", detail: "衛星による雨量データ", url: "https://sharaku.eorc.jaxa.jp/GSMaP/"),
        .init(name: "NASA Worldview", detail: "衛星画像レイヤー", url: "https://worldview.earthdata.nasa.gov/")
    ]
}

struct DataFeed: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let detail: String
    let url: String
}
