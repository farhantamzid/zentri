import XCTest

/// The largest accessibility text size (AX5) against the seeded store: the balance, the tabs, the
/// charts' VoiceOver labels, and the settings recovery screen must all stay on screen and reachable.
///
/// The suite runs on iPhone, iPhone Duo, and iPad; nothing in it is device-specific.
@MainActor
final class AccessibilityUITests: XCTestCase {
    private static let largestTextSize = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testTheOverviewBalanceAndTheTabsStayOnScreen() {
        let app = launched(["-UITestSkipOnboarding", "-UITestSeed"])
        let window = app.windows.firstMatch

        // The fixture's balance: 1,000,000 opening, a 250 debit, and a 5,000 credit.
        let hero = element("label BEGINSWITH %@", ["Combined balance"], in: app)
        XCTAssertTrue(hero.waitForExistence(timeout: 10), "The balance hero did not appear")
        XCTAssertTrue(hero.label.contains("$1,004,750.00"), "The hero reads \(hero.label)")
        XCTAssertTrue(hero.isHittable, "The balance hero is not on screen")
        assertFitsHorizontally(hero, in: window, "The balance hero")

        for title in ["Overview", "Transactions", "Insights", "Settings"] {
            let tab = app.tabBars.buttons[title]
            XCTAssertTrue(tab.exists, "The \(title) tab is missing")
            XCTAssertTrue(tab.isHittable, "The \(title) tab is not reachable")
            assertFitsHorizontally(tab, in: window, "The \(title) tab")
        }
    }

    func testTheChartsKeepTheirVoiceOverLabels() {
        let app = launched(["-UITestSkipOnboarding", "-UITestSeed", "-UITestSeedInsights"])

        // Overview's week: the chart names itself and every bar names its day.
        let week = element("label == %@", ["Spending, last seven days"], in: app)
        XCTAssertTrue(scrollUntilExists(week, in: app), "The activity chart has no accessibility label")
        let todayWeekday = Date.now.formatted(.dateTime.weekday(.wide))
        let today = element("label BEGINSWITH %@", [todayWeekday], in: app)
        XCTAssertTrue(today.exists, "The activity chart has no labelled bar for \(todayWeekday)")
        XCTAssertFalse((today.value as? String ?? "").isEmpty, "Today's bar has no amount")

        // Insights' daily chart.
        app.tabBars.buttons["Insights"].tap()
        let daily = app.descendants(matching: .any)["insights.dailyChart"].firstMatch
        XCTAssertTrue(scrollUntilExists(daily, in: app), "The daily spending chart is missing")
        XCTAssertEqual(daily.label, "Daily spending")
    }

    func testTheSettingsRecoveryScreenKeepsBothActionsReachable() {
        let app = launched(["-UITestUnreadableSettings"])
        let window = app.windows.firstMatch

        let useDefaults = app.buttons["Use Defaults"]
        let restore = app.buttons["recovery.restoreBackup"]
        XCTAssertTrue(useDefaults.waitForExistence(timeout: 10), "The recovery screen did not appear")

        for (button, name) in [(useDefaults, "Use Defaults"), (restore, "Restore Backup")] {
            XCTAssertTrue(scrollUntilHittable(button, in: app), "\(name) cannot be reached")
            assertFitsHorizontally(button, in: window, name)
        }
    }

    private func launched(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode"] + arguments + Self.largestTextSize
        app.launch()
        return app
    }

    /// The first element in the hierarchy whose label matches the predicate.
    private func element(_ format: String, _ arguments: [any CVarArg], in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: format, argumentArray: arguments))
            .firstMatch
    }

    private func scrollUntilExists(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        var swipes = 0
        while !element.waitForExistence(timeout: 2) && swipes < 12 {
            app.swipeUp()
            swipes += 1
        }
        return element.exists
    }

    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.waitForExistence(timeout: 5) else { return false }
        var swipes = 0
        while !element.isHittable && swipes < 12 {
            app.swipeUp()
            swipes += 1
        }
        return element.isHittable
    }

    /// Fails when the element runs past either side of the window, which is how a layout that does
    /// not wrap at large text sizes loses its content.
    private func assertFitsHorizontally(
        _ element: XCUIElement,
        in window: XCUIElement,
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let frame = element.frame
        let bounds = window.frame
        XCTAssertGreaterThanOrEqual(frame.minX, bounds.minX - 0.5, "\(name) runs off the leading edge", file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, bounds.maxX + 0.5, "\(name) runs off the trailing edge", file: file, line: line)
    }
}
