import XCTest

/// The four root tabs appear once onboarding is skipped.
@MainActor
final class AppShellUITests: XCTestCase {
    func testRootTabsAppear() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-UITestSkipOnboarding"]
        app.launch()
        XCTAssertTrue(app.tab("Overview").waitForExistence(timeout: 5))
        XCTAssertTrue(app.tab("Transactions").exists)
        XCTAssertTrue(app.tab("Insights").exists)
        XCTAssertTrue(app.tab("Settings").exists)
    }
}
