import SwiftUI

struct ContentView: View {
    @StateObject private var model = TyphoonViewModel()

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let safeWidth = max(1, proxy.size.width - proxy.safeAreaInsets.leading - proxy.safeAreaInsets.trailing)
                let edgeInset: CGFloat = safeWidth <= 340 ? 6 : (safeWidth <= 390 ? 9 : 18)
                let contentWidth = min(430, max(1, safeWidth - edgeInset * 2))
                let metrics = LayoutMetrics(width: contentWidth, height: proxy.size.height)

                ZStack(alignment: .top) {
                    Image("TyphoonHeroBackdrop")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .overlay(Color.black.opacity(0.46))

                    ScrollView {
                        VStack(spacing: metrics.sectionSpacing) {
                            header(metrics)
                            riskDeck(metrics)
                            trackCard(metrics)
                            feedStrip(metrics)
                            timelineCard(metrics)
                        }
                        .frame(width: contentWidth, alignment: .topLeading)
                        .padding(.horizontal, edgeInset)
                        .frame(width: safeWidth, alignment: .center)
                        .padding(.top, max(12, proxy.safeAreaInsets.top + 8))
                        .padding(.bottom, max(22, proxy.safeAreaInsets.bottom + 22))
                    }
                    .scrollIndicators(.hidden)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .accessibilityIdentifier("typhoonWatchContentScroll")
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .accessibilityIdentifier("typhoonWatchRoot")
            }
            .navigationBarHidden(true)
            .task {
                await model.refresh()
            }
            .refreshable {
                await model.refresh()
            }
        }
        .tint(.cyan)
    }

    private func header(_ metrics: LayoutMetrics) -> some View {
        CompactPanel(metrics: metrics, style: .hero) {
            VStack(alignment: .leading, spacing: metrics.headerSpacing) {
                HStack(alignment: .top, spacing: metrics.headerActionSpacing) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("台風を観測")
                            .font(.system(size: metrics.titleSize, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Text(model.storm.name)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 6)

                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Image(systemName: model.isLoading ? "waveform" : "arrow.clockwise")
                            .font(.headline.weight(.bold))
                            .frame(width: metrics.refreshButtonSize, height: metrics.refreshButtonSize)
                            .background(Color.white.opacity(0.13), in: Circle())
                    }
                    .frame(width: metrics.refreshButtonSize, height: metrics.refreshButtonSize)
                    .accessibilityLabel("最新データを取得")
                    .buttonStyle(.plain)
                }

                Group {
                    if metrics.isNarrow {
                        VStack(alignment: .leading, spacing: 3) {
                            Label(model.statusText, systemImage: model.isLoading ? "arrow.triangle.2.circlepath" : "checkmark.seal.fill")
                            Text(model.storm.updatedAt.compactTime)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Label(model.statusText, systemImage: model.isLoading ? "arrow.triangle.2.circlepath" : "checkmark.seal.fill")
                            Spacer(minLength: 6)
                            Text(model.storm.updatedAt.compactTime)
                        }
                    }
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            }
        }
    }

    private func riskDeck(_ metrics: LayoutMetrics) -> some View {
        CompactPanel(metrics: metrics) {
            VStack(alignment: .leading, spacing: metrics.innerSpacing) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("現在の判断")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan.opacity(0.9))
                    VStack(alignment: .leading, spacing: 6) {
                        if metrics.isNarrow {
                            Text(model.selectedRegion.name)
                                .font(.system(size: metrics.headlineSize, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)

                            RiskBadge(level: model.risk.level)
                        } else {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(model.selectedRegion.name)
                                    .font(.system(size: metrics.headlineSize, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)

                                RiskBadge(level: model.risk.level)
                            }
                        }
                    }
                }

                Menu {
                    Picker("地域を選択", selection: $model.selectedRegion) {
                        ForEach(AppData.regions) { region in
                            Text(region.name).tag(region)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "location.viewfinder")
                            .frame(width: 18)
                        Text(model.selectedRegion.name)
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .layoutPriority(1)
                        Spacer(minLength: 0)
                        if !metrics.isNarrow {
                            Text("変更")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(.white.opacity(0.66))
                        }
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.black))
                            .foregroundStyle(.cyan.opacity(0.9))
                    }
                    .padding(.horizontal, metrics.controlHorizontalPadding)
                    .padding(.vertical, 10)
                    .frame(minHeight: metrics.regionPickerHeight)
                    .background(Color.white.opacity(metrics.controlBackgroundOpacity), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.cyan.opacity(metrics.controlStrokeOpacity), lineWidth: 1)
                    )
                    .foregroundStyle(.white)
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel("地域を選択")
                .buttonStyle(.plain)

                Text(model.risk.summary)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .lineLimit(metrics.summaryLineLimit)
                    .minimumScaleFactor(0.92)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                ProgressView(value: min(model.risk.score, 100), total: 100)
                    .tint(Color(hex: model.risk.level.colorHex))
                    .scaleEffect(x: 1, y: 1.6, anchor: .center)

                HStack(spacing: 8) {
                    Text("リスク目安")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.62))
                    Spacer(minLength: 0)
                    Text("\(Int(min(model.risk.score, 100).rounded()))%")
                        .font(.caption.weight(.black))
                        .foregroundStyle(Color(hex: model.risk.level.colorHex))
                }
                .accessibilityLabel("リスク目安 \(Int(min(model.risk.score, 100).rounded()))パーセント")

                LazyVGrid(columns: metrics.metricColumns, spacing: 8) {
                    MetricTile(title: "最接近", value: model.risk.closestAt?.compactTime ?? "不明")
                    MetricTile(title: "最短距離", value: "\(Int(model.risk.closestKm.rounded())) km")
                    MetricTile(title: "最大風速", value: model.risk.maxWind.map { "\($0) kt" } ?? "不明")
                    MetricTile(title: "データ", value: model.statusText)
                }
            }
        }
    }

    private func trackCard(_ metrics: LayoutMetrics) -> some View {
        CompactPanel(metrics: metrics) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Label("進路", systemImage: "scope")
                        .font(.headline.weight(.black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(model.storm.source)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.64))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .foregroundStyle(.white)

                TrackMap(points: model.storm.points, region: model.selectedRegion)
                    .frame(height: metrics.mapHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityLabel("台風の進路図")
                    .accessibilityIdentifier("typhoonTrackMap")

                VStack(spacing: 7) {
                    ForEach(model.risk.actions, id: \.self) { action in
                        Label(action, systemImage: "checkmark.circle.fill")
                            .font(metrics.actionFont.weight(.bold))
                            .lineLimit(metrics.actionLineLimit)
                            .minimumScaleFactor(0.74)
                            .labelStyle(.titleAndIcon)
                            .padding(.horizontal, metrics.actionHorizontalPadding)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(.white.opacity(0.88))
                    }
                }
            }
        }
    }

    private func feedStrip(_ metrics: LayoutMetrics) -> some View {
        CompactPanel(metrics: metrics) {
            VStack(alignment: .leading, spacing: 10) {
                Label("データ元", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)

                VStack(spacing: 8) {
                    ForEach(Array(AppData.feeds.prefix(metrics.feedLimit).enumerated()), id: \.element.id) { index, feed in
                        Link(destination: URL(string: feed.url)!) {
                            HStack(spacing: metrics.feedRowSpacing) {
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.caption.weight(.black))
                                    .frame(width: metrics.feedIconSize, height: metrics.feedIconSize)
                                    .background(Color.white.opacity(0.1), in: Circle())

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(feed.name)
                                        .font(.subheadline.weight(.black))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.78)
                                    Text(feed.detail)
                                        .font(metrics.feedDetailFont)
                                        .foregroundStyle(.white.opacity(0.62))
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .layoutPriority(1)

                                Spacer(minLength: 0)

                                if !metrics.isNarrow {
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.black))
                                        .foregroundStyle(.white.opacity(0.42))
                                }
                            }
                            .padding(metrics.feedRowPadding)
                            .frame(minHeight: metrics.feedRowHeight)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(metrics.controlBackgroundOpacity), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(metrics.feedStrokeOpacity), lineWidth: 1)
                            )
                            .foregroundStyle(.white)
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .accessibilityLabel("\(feed.name)、\(feed.detail)")
                        .accessibilityHint("外部サイトを開きます")
                        .accessibilityIdentifier("dataFeed-\(index)")
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func timelineCard(_ metrics: LayoutMetrics) -> some View {
        CompactPanel(metrics: metrics) {
            VStack(alignment: .leading, spacing: 10) {
                Label("観測リスト", systemImage: "list.bullet.rectangle")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)

                ForEach(model.storm.points.suffix(metrics.timelineLimit)) { point in
                    timelineRow(point, metrics: metrics)
                }
            }
        }
    }

    private func timelineRow(_ point: TyphoonPoint, metrics: LayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(point.time.compactTime)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if point.isForecast {
                    Text("予報")
                        .font(.caption2.weight(.black))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(hex: 0xF2B84B).opacity(0.22), in: Capsule())
                        .foregroundStyle(Color(hex: 0xF2B84B))
                }

                Spacer(minLength: 0)
            }

            if metrics.isNarrow {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(point.latitude, specifier: "%.1f")N \(point.longitude, specifier: "%.1f")E")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    HStack(spacing: 10) {
                        Text("\(point.pressure.map(String.init) ?? "--") hPa")
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text("\(point.wind.map(String.init) ?? "--") kt")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.cyan.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    Text("\(point.latitude, specifier: "%.1f")N \(point.longitude, specifier: "%.1f")E")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Spacer(minLength: 0)

                    Text("\(point.pressure.map(String.init) ?? "--") hPa")
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text("\(point.wind.map(String.init) ?? "--") kt")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, metrics.timelineVerticalPadding)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct LayoutMetrics {
    let width: CGFloat
    let height: CGFloat

    var isNarrow: Bool { width <= 375 }
    var sectionSpacing: CGFloat { isNarrow ? 9 : 14 }
    var innerSpacing: CGFloat { isNarrow ? 10 : 12 }
    var headerSpacing: CGFloat { isNarrow ? 8 : 12 }
    var headerActionSpacing: CGFloat { isNarrow ? 6 : 10 }
    var summaryLineLimit: Int { isNarrow ? 3 : 4 }
    var titleSize: CGFloat { width <= 340 ? 22 : (isNarrow ? 24 : 32) }
    var headlineSize: CGFloat { width <= 340 ? 19 : (isNarrow ? 20 : 24) }
    var refreshButtonSize: CGFloat { 44 }
    var regionPickerHeight: CGFloat { isNarrow ? 50 : 44 }
    var controlHorizontalPadding: CGFloat { width <= 340 ? 9 : 12 }
    var controlBackgroundOpacity: Double { isNarrow ? 0.12 : 0.09 }
    var controlStrokeOpacity: Double { isNarrow ? 0.34 : 0.22 }
    var feedStrokeOpacity: Double { isNarrow ? 0.14 : 0.0 }
    var panelPadding: CGFloat { width <= 340 ? 9 : (isNarrow ? 11 : 14) }
    var panelCornerRadius: CGFloat { isNarrow ? 10 : 12 }
    var mapHeight: CGFloat {
        let availableWidth = width - panelPadding * 2
        let ratio: CGFloat = width <= 340 ? 0.54 : (isNarrow ? 0.58 : 0.72)
        let compactMinimum: CGFloat = width <= 340 ? 136 : 148
        let compactMaximum: CGFloat = width <= 340 ? 164 : 176
        return min(isNarrow ? compactMaximum : 280, max(isNarrow ? compactMinimum : 220, availableWidth * ratio))
    }
    var actionFont: Font { isNarrow ? .caption : .caption2 }
    var actionHorizontalPadding: CGFloat { width <= 340 ? 8 : 9 }
    var feedDetailFont: Font { isNarrow ? .caption : .caption2 }
    var actionLineLimit: Int { isNarrow ? 2 : 3 }
    var feedLimit: Int { isNarrow ? 3 : 6 }
    var feedIconSize: CGFloat { width <= 340 ? 24 : 26 }
    var feedRowSpacing: CGFloat { width <= 340 ? 8 : 10 }
    var feedRowPadding: CGFloat { width <= 340 ? 8 : 10 }
    var feedRowHeight: CGFloat { isNarrow ? 58 : 52 }
    var timelineLimit: Int { isNarrow ? 6 : 8 }
    var timelineVerticalPadding: CGFloat { isNarrow ? 6 : 7 }
    var metricColumns: [GridItem] {
        if width <= 330 {
            return [GridItem(.flexible(), spacing: 8)]
        }
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)
    }
}

private struct RiskBadge: View {
    let level: RiskLevel

    var body: some View {
        Text(level.rawValue)
            .font(.caption.weight(.black))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color(hex: level.colorHex).opacity(0.22), in: Capsule())
            .foregroundStyle(Color(hex: level.colorHex))
            .lineLimit(1)
    }
}

private struct TrackMap: View {
    let points: [TyphoonPoint]
    let region: MonitorRegion

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .linearGradient(
                Gradient(colors: [Color(hex: 0x155F6B), Color(hex: 0x061F27)]),
                startPoint: .zero,
                endPoint: CGPoint(x: size.width, y: size.height)
            ))

            drawGrid(context: &context, size: size)
            drawTrack(context: &context, size: size)
            drawRegion(context: &context, size: size)
        }
    }

    private func drawGrid(context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        stride(from: 0.0, through: size.width, by: 44).forEach { x in
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }
        stride(from: 0.0, through: size.height, by: 44).forEach { y in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(path, with: .color(.white.opacity(0.12)), lineWidth: 1)
    }

    private func drawTrack(context: inout GraphicsContext, size: CGSize) {
        let projected = points.map { project($0, size: size) }
        guard projected.count > 1 else { return }

        var path = Path()
        path.move(to: projected[0])
        projected.dropFirst().forEach { path.addLine(to: $0) }
        context.stroke(path, with: .color(Color(hex: 0xF7E7A4)), lineWidth: 4)

        for (index, point) in projected.enumerated() {
            let circle = Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12))
            let fill = index >= projected.count - 3 ? Color(hex: 0xFF6A4A) : Color(hex: 0x74D1C6)
            context.fill(circle, with: .color(fill))
            context.stroke(circle, with: .color(.white.opacity(0.9)), lineWidth: 1.5)
        }
    }

    private func drawRegion(context: inout GraphicsContext, size: CGSize) {
        let p = project(latitude: region.latitude, longitude: region.longitude, size: size)
        let marker = Path(ellipseIn: CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16))
        context.fill(marker, with: .color(.white))
        context.stroke(marker, with: .color(Color(hex: 0xFF6A4A)), lineWidth: 3)
    }

    private func project(_ point: TyphoonPoint, size: CGSize) -> CGPoint {
        project(latitude: point.latitude, longitude: point.longitude, size: size)
    }

    private func project(latitude: Double, longitude: Double, size: CGSize) -> CGPoint {
        let bounds = (minLat: 18.0, maxLat: 46.0, minLon: 120.0, maxLon: 148.0)
        let padding = 22.0
        let x = padding + ((longitude - bounds.minLon) / (bounds.maxLon - bounds.minLon)) * (size.width - padding * 2)
        let y = padding + ((bounds.maxLat - latitude) / (bounds.maxLat - bounds.minLat)) * (size.height - padding * 2)
        return CGPoint(
            x: min(max(x, padding), size.width - padding),
            y: min(max(y, padding), size.height - padding)
        )
    }
}

private struct CompactPanel<Content: View>: View {
    enum Style {
        case standard
        case hero
    }

    let metrics: LayoutMetrics
    let style: Style
    let content: Content

    init(metrics: LayoutMetrics, style: Style = .standard, @ViewBuilder content: () -> Content) {
        self.metrics = metrics
        self.style = style
        self.content = content()
    }

    var body: some View {
        content
            .padding(metrics.panelPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: metrics.panelCornerRadius, style: .continuous)
                        .fill(style == .hero ? Color(hex: 0x0A3E46).opacity(0.84) : Color.white.opacity(0.08))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: metrics.panelCornerRadius, style: .continuous))

                    Image("RadarPanelTexture")
                        .resizable()
                        .scaledToFill()
                        .opacity(0.16)
                        .blendMode(.screen)
                        .clipShape(RoundedRectangle(cornerRadius: metrics.panelCornerRadius, style: .continuous))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: metrics.panelCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: metrics.panelCornerRadius, style: .continuous))
    }
}

private struct MetricTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(value)
                .font(.subheadline.weight(.black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 54, alignment: .center)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private extension Date {
    var compactTime: String {
        formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }
}

private extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

#Preview("iPhone SE") {
    ContentView()
        .previewDevice("iPhone SE (3rd generation)")
}

#Preview("320pt Compact") {
    ContentView()
        .frame(width: 320, height: 568)
}

#Preview("iPhone SE Large Text") {
    ContentView()
        .previewDevice("iPhone SE (3rd generation)")
        .dynamicTypeSize(.accessibility1)
}
