import XCTest
import UIKit

final class TyphoonWatchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCompactHomeContentIsVisible() throws {
        let app = launchApp()
        assertCompactHomeIsUsable(in: app)
    }

    func testCompactHomeContentSupportsLargeText() throws {
        let app = launchApp(preferredContentSize: .accessibilityMedium)
        assertCompactHomeIsUsable(in: app)
    }

    private func launchApp(preferredContentSize: UIContentSizeCategory? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        if let preferredContentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", preferredContentSize.rawValue]
        }
        app.launch()
        return app
    }

    private func assertCompactHomeIsUsable(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let title = app.staticTexts["台風を観測"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Home title should exist on compact iPhone.", file: file, line: line)
        XCTAssertTrue(title.isHittable, "Home title should be visible in the compact viewport.", file: file, line: line)

        let refreshButton = app.buttons["最新データを取得"].firstMatch
        XCTAssertTrue(refreshButton.waitForExistence(timeout: 5), "Refresh button should exist on compact iPhone.", file: file, line: line)
        XCTAssertTrue(refreshButton.isHittable, "Refresh button should be visible and tappable on compact iPhone.", file: file, line: line)

        let trackMap = app.otherElements["typhoonTrackMap"].firstMatch
        scrollUntilVisible(trackMap, in: app, file: file, line: line)
        XCTAssertTrue(trackMap.isHittable, "Track map should be reachable in the compact scrolling layout.", file: file, line: line)

        let firstFeed = app.descendants(matching: .any)["dataFeed-0"].firstMatch
        scrollUntilVisible(firstFeed, in: app, file: file, line: line)
        XCTAssertTrue(firstFeed.isHittable, "First data source link should be reachable and tappable on compact iPhone.", file: file, line: line)
    }

    private func scrollUntilVisible(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<10 where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.exists, "Expected element to exist after scrolling.", file: file, line: line)
    }
}
