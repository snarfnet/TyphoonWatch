import XCTest
@testable import TyphoonWatch

final class LayoutMetricsTests: XCTestCase {
    func testUltraCompactWidthKeepsControlsUsable() {
        let metrics = LayoutMetrics(width: 320, height: 568)

        XCTAssertTrue(metrics.isNarrow)
        XCTAssertEqual(metrics.refreshButtonSize, 44)
        XCTAssertEqual(metrics.regionPickerHeight, 50)
        XCTAssertEqual(metrics.panelPadding, 9)
        XCTAssertEqual(metrics.metricColumns.count, 1)
        XCTAssertGreaterThanOrEqual(metrics.mapHeight, 136)
        XCTAssertLessThanOrEqual(metrics.mapHeight, 164)
    }

    func testIPhoneSEWidthKeepsDenseReadableLayout() {
        let metrics = LayoutMetrics(width: 357, height: 667)

        XCTAssertTrue(metrics.isNarrow)
        XCTAssertEqual(metrics.refreshButtonSize, 44)
        XCTAssertEqual(metrics.regionPickerHeight, 50)
        XCTAssertEqual(metrics.metricColumns.count, 2)
        XCTAssertGreaterThanOrEqual(metrics.mapHeight, 148)
        XCTAssertLessThanOrEqual(metrics.mapHeight, 176)
        XCTAssertLessThanOrEqual(metrics.feedLimit, 3)
    }

    func testRegularCompactWidthUsesFullContentDensity() {
        let metrics = LayoutMetrics(width: 430, height: 932)

        XCTAssertFalse(metrics.isNarrow)
        XCTAssertEqual(metrics.metricColumns.count, 2)
        XCTAssertGreaterThanOrEqual(metrics.mapHeight, 220)
        XCTAssertEqual(metrics.feedLimit, 6)
    }
}
