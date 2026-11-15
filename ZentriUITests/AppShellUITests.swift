import XCTest

/// The four root tabs appear once onboarding is skipped.
@MainActor
final class AppShellUITests: XCTestCase {
    func testRootTabsAppear() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-UITestSkipOnboarding"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Overview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Transactions"].exists)
        XCTAssertTrue(app.tabBars.buttons["Insights"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }
}
