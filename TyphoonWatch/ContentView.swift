import SwiftUI

struct ContentView: View {
    @StateObject private var model = TyphoonViewModel()

    var body: some View {
        TabView {
            typhoonTab
                .tabItem {
                    Label(
                        Lang.pick("台風", "Typhoon"),
                        systemImage: "hurricane"
                    )
                }

            WeatherTab()
                .tabItem {
                    Label(
                        Lang.pick("天気予報", "Weather"),
                        systemImage: "cloud.sun.fill"
                    )
                }
        }
        .tint(.cyan)
        .preferredColorScheme(.dark)
    }

    // MARK: - Typhoon tab

    private var typhoonTab: some View {
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
                    Text(Lang.pick("現在の判断", "Current Assessment"))
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
                    Picker(Lang.pick("地域を選択", "Select Region"), selection: $model.selectedRegion) {
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
                            Text(Lang.pick("変更", "Change"))
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
                    MetricTile(
                        title: Lang.pick("最接近", "Closest"),
                        value: model.risk.closestAt?.compactTime ?? Lang.pick("不明", "N/A")
                    )
                    MetricTile(
                        title: Lang.pick("最短距離", "Distance"),
                        value: "\(Int(model.risk.closestKm.rounded())) km"
                    )
                    MetricTile(
                        title: Lang.pick("最大風速", "Max Wind"),
                        value: model.risk.maxWind.map { "\($0) kt" } ?? Lang.pick("不明", "N/A"),
                        helpTopic: .windSpeed
                    )
                    MetricTile(
                        title: Lang.pick("データ", "Source"),
                        value: model.statusText
                    )
                }
            }
        }
    }

    private func trackCard(_ metrics: LayoutMetrics) -> some View {
        CompactPanel(metrics: metrics) {
            VStack(alignment: .leading, spacing: 10) {
                // Header with help toggle
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Label(
                            Lang.pick("進路", "Track"),
                            systemImage: "scope"
                        )
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
                    Spacer(minLength: 6)
                    HelpButton(topic: .trackMap)
                }

                TrackMap(points: model.storm.points, region: model.selectedRegion)
                    .frame(height: metrics.mapHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityLabel(Lang.pick("台風の進路図", "Typhoon track map"))
                    .accessibilityIdentifier("typhoonTrackMap")

                // Legend card
                TrackLegendView(metrics: metrics)

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
                HStack {
                    Label(
                        Lang.pick("データ元", "Data Sources"),
                        systemImage: "antenna.radiowaves.left.and.right"
                    )
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    Spacer(minLength: 6)
                    HelpButton(topic: .categories)
                }

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
                HStack {
                    Label(
                        Lang.pick("観測リスト", "Observation List"),
                        systemImage: "list.bullet.rectangle"
                    )
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    Spacer(minLength: 6)
                    HelpButton(topic: .pressure)
                }

                ForEach(model.storm.points.suffix(metrics.timelineLimit)) { point in
                    timelineRow(point, metrics: metrics)
                }
            }
        }
    }

    private func timelineRow(_ point: TyphoonPoint, metrics: LayoutMetrics) -> some View {
        let intensityColor = point.intensity.color
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Intensity dot
                Circle()
                    .fill(intensityColor)
                    .frame(width: 8, height: 8)

                Text(point.time.compactTime)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if point.isForecast {
                    Text(Lang.pick("予報", "Fcst"))
                        .font(.caption2.weight(.black))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(hex: 0xF2B84B).opacity(0.22), in: Capsule())
                        .foregroundStyle(Color(hex: 0xF2B84B))
                }

                Text(point.intensity.label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(intensityColor)
                    .lineLimit(1)

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
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text("\(point.wind.map(String.init) ?? "--") kt")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(intensityColor)
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
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text("\(point.wind.map(String.init) ?? "--") kt")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(intensityColor)
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
            drawLabels(context: &context, size: size)
        }
    }

    // MARK: Grid

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

    // MARK: Track (color-coded + arrows + dashed forecast)

    private func drawTrack(context: inout GraphicsContext, size: CGSize) {
        guard points.count > 1 else { return }
        let projected = points.map { project($0, size: size) }

        // Draw segments between consecutive points
        for i in 0..<(points.count - 1) {
            let from = projected[i]
            let to   = projected[i + 1]
            let segColor = points[i].intensity.color
            let isForecastSeg = points[i].isForecast || points[i + 1].isForecast

            var segPath = Path()
            segPath.move(to: from)
            segPath.addLine(to: to)

            if isForecastSeg {
                // Dashed line for forecast
                context.stroke(
                    segPath,
                    with: .color(segColor.opacity(0.85)),
                    style: StrokeStyle(lineWidth: 3, dash: [6, 4])
                )
            } else {
                context.stroke(
                    segPath,
                    with: .color(segColor),
                    style: StrokeStyle(lineWidth: 4)
                )
            }

            // Draw arrowhead at midpoint
            let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
            drawArrow(context: &context, at: mid, from: from, to: to, color: segColor)
        }

        // Draw dots for each point
        for (i, pt) in projected.enumerated() {
            let radius: CGFloat = points[i].isForecast ? 4.5 : 6
            let circle = Path(ellipseIn: CGRect(
                x: pt.x - radius, y: pt.y - radius,
                width: radius * 2, height: radius * 2
            ))
            context.fill(circle, with: .color(points[i].intensity.color))
            context.stroke(circle, with: .color(.white.opacity(0.9)), lineWidth: 1.5)
        }
    }

    private func drawArrow(context: inout GraphicsContext, at mid: CGPoint, from: CGPoint, to: CGPoint, color: Color) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 8 else { return }
        let ux = dx / len, uy = dy / len
        let px = -uy, py = ux          // perpendicular
        let aLen: CGFloat = 6
        let aWidth: CGFloat = 4

        var arrow = Path()
        arrow.move(to: CGPoint(x: mid.x + ux * aLen, y: mid.y + uy * aLen))
        arrow.addLine(to: CGPoint(x: mid.x - ux * aLen + px * aWidth, y: mid.y - uy * aLen + py * aWidth))
        arrow.addLine(to: CGPoint(x: mid.x - ux * aLen - px * aWidth, y: mid.y - uy * aLen - py * aWidth))
        arrow.closeSubpath()
        context.fill(arrow, with: .color(color))
    }

    // MARK: Region marker

    private func drawRegion(context: inout GraphicsContext, size: CGSize) {
        let p = project(latitude: region.latitude, longitude: region.longitude, size: size)
        let marker = Path(ellipseIn: CGRect(x: p.x - 8, y: p.y - 8, width: 16, height: 16))
        context.fill(marker, with: .color(.white))
        context.stroke(marker, with: .color(Color(hex: 0xFF6A4A)), lineWidth: 3)
    }

    // MARK: Inline labels (N/S compass hints)

    private func drawLabels(context: inout GraphicsContext, size: CGSize) {
        context.draw(
            Text(Lang.pick("北", "N"))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.45)),
            at: CGPoint(x: 10, y: 10)
        )
        context.draw(
            Text(Lang.pick("南", "S"))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.45)),
            at: CGPoint(x: 10, y: size.height - 10)
        )
    }

    // MARK: Projection

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
    var helpTopic: HelpTopic? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                if let topic = helpTopic {
                    HelpButton(topic: topic)
                }
            }
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

// MARK: - Help system

enum HelpTopic {
    case windSpeed
    case pressure
    case categories
    case trackMap

    var title: String {
        switch self {
        case .windSpeed:  return Lang.pick("風速の目安", "Wind Speed Guide")
        case .pressure:   return Lang.pick("気圧の目安", "Pressure Guide")
        case .categories: return Lang.pick("台風の種類", "Typhoon Categories")
        case .trackMap:   return Lang.pick("進路図の見方", "How to Read the Map")
        }
    }

    var lines: [(icon: String, text: String)] {
        switch self {
        case .windSpeed:
            return [
                ("wind",           Lang.pick("17m/s以上 → 暴風域", "≥17 m/s → Storm force")),
                ("tornado",        Lang.pick("25m/s以上 → 強風域", "≥25 m/s → Strong gale")),
                ("exclamationmark.triangle.fill",
                                   Lang.pick("30m/s → 屋根が飛ぶ可能性", "30 m/s → Roof damage risk")),
                ("bolt.fill",      Lang.pick("45m/s → 電柱が倒れる", "45 m/s → Utility poles may fall")),
                ("info.circle",    Lang.pick("1 kt ≒ 0.51 m/s", "1 kt ≈ 0.51 m/s"))
            ]
        case .pressure:
            return [
                ("gauge.with.dots.needle.67percent",
                                   Lang.pick("1000hPa → 平均的な台風", "1000 hPa → Average typhoon")),
                ("gauge.with.dots.needle.33percent",
                                   Lang.pick("980hPa → 強い台風", "980 hPa → Strong typhoon")),
                ("gauge.with.dots.needle.bottom.0percent",
                                   Lang.pick("960hPa → 非常に強い台風", "960 hPa → Very strong typhoon")),
                ("exclamationmark.3",
                                   Lang.pick("930hPa以下 → 猛烈", "≤930 hPa → Violent typhoon")),
                ("info.circle",    Lang.pick("数字が小さいほど強い", "Lower = stronger storm"))
            ]
        case .categories:
            return [
                ("circle.fill",    Lang.pick("熱帯低気圧 (<34kt) 緑", "Tropical Depression (<34kt) green")),
                ("circle.fill",    Lang.pick("熱帯暴風雨 (34-63kt) 黄", "Tropical Storm (34-63kt) yellow")),
                ("circle.fill",    Lang.pick("台風 (64-99kt) オレンジ", "Typhoon (64-99kt) orange")),
                ("circle.fill",    Lang.pick("猛烈な台風 (≥100kt) 赤", "Super Typhoon (≥100kt) red"))
            ]
        case .trackMap:
            return [
                ("line.diagonal",  Lang.pick("実線 → 実績の進路", "Solid line → Actual track")),
                ("line.diagonal",  Lang.pick("破線 → 予報進路", "Dashed line → Forecast track")),
                ("arrow.up.right", Lang.pick("矢印 → 移動方向", "Arrow → Direction of movement")),
                ("circle.fill",    Lang.pick("丸の色 → 強度", "Dot color → Intensity")),
                ("mappin.circle",  Lang.pick("白丸 → 選択地点", "White dot → Selected location"))
            ]
        }
    }
}

private struct HelpButton: View {
    let topic: HelpTopic
    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.cyan.opacity(0.75))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(topic.title)
        .sheet(isPresented: $showSheet) {
            HelpSheet(topic: topic)
        }
    }
}

private struct HelpSheet: View {
    let topic: HelpTopic
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: 0x061F27).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(topic.lines.enumerated()), id: \.offset) { _, line in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: line.icon)
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(.cyan)
                                    .frame(width: 24)
                                Text(line.text)
                                    .font(.body)
                                    .foregroundStyle(.white.opacity(0.88))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle(topic.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(Lang.pick("閉じる", "Close")) { dismiss() }
                        .foregroundStyle(.cyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Track legend

private struct TrackLegendView: View {
    let metrics: LayoutMetrics

    private let items: [(color: Color, label: String, style: String)] = [
        (TyphoonIntensity.tropicalDepression.color, TyphoonIntensity.tropicalDepression.label, Lang.pick("実線", "Solid")),
        (TyphoonIntensity.tropicalStorm.color,      TyphoonIntensity.tropicalStorm.label,      Lang.pick("実線", "Solid")),
        (TyphoonIntensity.typhoon.color,            TyphoonIntensity.typhoon.label,            Lang.pick("実線", "Solid")),
        (TyphoonIntensity.superTyphoon.color,       TyphoonIntensity.superTyphoon.label,       Lang.pick("実線", "Solid"))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Lang.pick("凡例", "Legend"))
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer(minLength: 0)
                // Forecast vs actual hint
                HStack(spacing: 4) {
                    // Solid line sample
                    Rectangle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 16, height: 2)
                    Text(Lang.pick("実績", "Actual"))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                    // Dashed line sample
                    dashedLineSample
                    Text(Lang.pick("予報", "Forecast"))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            let columns = metrics.isNarrow
                ? [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]
                : Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(items, id: \.label) { item in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 8, height: 8)
                        Text(item.label)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private var dashedLineSample: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { _ in
                Rectangle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 4, height: 2)
            }
        }
    }
}

private extension Date {
    var compactTime: String {
        formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }
}

// Color(hex:) is defined in Models.swift

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
