import XCTest

/// The Overview dashboard against the store `-UITestSeed` prepares.
@MainActor
final class OverviewUITests: XCTestCase {
    /// The fixture's opening balance.
    private let openingBalance = Decimal(1_000_000)
    /// The fixture's debit: today's spend, the month's only spend, and the newest recent row.
    private let debit = Decimal(250)
    /// The fixture's credit.
    private let credit = Decimal(5_000)

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testOverviewShowsTheSeededBalanceSummaryCategoryActivityAndHealth() {
        let app = launchedWithSeed()

        // The hero combines the balance, last read time, and today's spend into one announcement.
        let hero = element("label BEGINSWITH %@", ["Combined balance"], in: app)
        XCTAssertTrue(hero.waitForExistence(timeout: 10), "The balance hero did not appear")
        XCTAssertTrue(
            hero.label.contains(usd(openingBalance - debit + credit)),
            "The hero reads \(hero.label), which does not hold the combined balance"
        )
        XCTAssertTrue(
            hero.label.contains(usd(debit)),
            "The hero reads \(hero.label), which does not report today's spend"
        )

        assertLabel("overview.month.spent", contains: usd(debit), in: app)
        assertLabel("overview.month.received", contains: usd(credit), in: app)
        assertLabel("overview.month.net", contains: usd(credit - debit), in: app)

        // A bank message arrived today and one failed, and nothing has parsed successfully.
        assertLabel("overview.health.lastSuccess", contains: "Never", in: app)
        let failures = app.descendants(matching: .any)["overview.health.failureCount"]
        assertExists("overview.health.failureCount", in: app)
        // The row announces its label and its figure together, so the count is the last word.
        XCTAssertEqual(
            failures.label.split(separator: " ").last,
            "1",
            "The health card reports \(failures.label) failures"
        )
    }

    func testTheActivityChartCarriesPerDayValuesAndATableLikeSummary() {
        let app = launchedWithSeed()

        let chart = element("label == %@", ["Spending, last seven days"], in: app)
        XCTAssertTrue(chart.waitForExistence(timeout: 10), "The activity chart does not announce itself")

        // The table-like alternative: the week's total, then each of the seven days.
        let table = chart.value as? String ?? ""
        let rows = table.components(separatedBy: "\n")
        XCTAssertEqual(rows.count, 8, "The chart's summary is not a title plus seven rows: \(table)")
        XCTAssertTrue(rows[0].contains("Total \(usd(debit))"), "The summary does not total the week: \(table)")
        XCTAssertTrue(
            rows.dropFirst().allSatisfy { $0.contains(usd(0)) || $0.contains(usd(debit)) },
            table
        )

        // And each bar keeps its own day and amount for anyone stepping through them. The weekday
        // comes from the run's own date, so the assertion holds whichever day the suite runs.
        let todayWeekday = Date.now.formatted(.dateTime.weekday(.wide))
        let today = element("label BEGINSWITH %@", [todayWeekday], in: app)
        XCTAssertTrue(today.exists, "The chart has no bar for \(todayWeekday)")
        XCTAssertEqual(today.value as? String, usd(debit), "Today's bar reads \(String(describing: today.value))")
    }

    func testTheTopCategoriesAndRecentActivityShowTheSeededSpend() {
        let app = launchedWithSeed()

        // The only spend this month is one Dining debit, so it is 100% of the month's categories.
        let category = app.descendants(matching: .any)["overview.category.row"].firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: 10), "The top categories card is missing its row")
        XCTAssertTrue(category.label.contains("Dining"), "The category row reads \(category.label)")
        XCTAssertTrue(category.label.contains(usd(debit)), "The category row reads \(category.label)")
        XCTAssertTrue(category.label.contains("100%"), "The category row reads \(category.label)")

        // The debit is the newest row, so it heads the recent list.
        let recent = app.descendants(matching: .any)["overview.recent.row"].firstMatch
        XCTAssertTrue(recent.waitForExistence(timeout: 5), "The recent list is missing its rows")
        XCTAssertTrue(recent.label.contains("Starbucks"), "The recent row reads \(recent.label)")
        XCTAssertTrue(recent.label.contains("Dining"), "The recent row reads \(recent.label)")
        XCTAssertTrue(recent.label.contains(usd(debit)), "The recent row reads \(recent.label)")
    }

    func testAnEmptyStoreOffersFinishSetup() {
        let app = XCUIApplication()
        // Skipping onboarding saves settings but seeds nothing, so there is no account.
        app.launchArguments = ["-UITestMode", "-UITestSkipOnboarding"]
        app.launch()

        let finishSetup = app.buttons["overview.finishSetup"]
        XCTAssertTrue(finishSetup.waitForExistence(timeout: 10), "The empty state did not appear")
        finishSetup.tap()

        // Settings opens on the list whose first row adds the missing account.
        XCTAssertTrue(
            app.buttons["settings.accounts"].waitForExistence(timeout: 5),
            "Finish setup did not open the Settings tab"
        )
    }

    private func launchedWithSeed() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-UITestSkipOnboarding", "-UITestSeed"]
        app.launch()
        return app
    }

    /// The fixture settings are the app's defaults — USD with Western grouping — which this target
    /// cannot import, so the expected string repeats those rules over the same amounts.
    private func usd(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        let digits = formatter.string(from: NSDecimalNumber(decimal: amount)) ?? amount.description
        return "$" + digits
    }

    /// The first element in the hierarchy whose label matches the predicate.
    private func element(
        _ format: String,
        _ arguments: [any CVarArg],
        in app: XCUIApplication
    ) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: format, argumentArray: arguments))
            .firstMatch
    }

    private func assertLabel(
        _ identifier: String,
        contains expected: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: 5), "\(identifier) is missing", file: file, line: line)
        XCTAssertTrue(
            element.label.contains(expected),
            "\(identifier) reads \(element.label), which does not contain \(expected)",
            file: file,
            line: line
        )
    }

    private func assertExists(
        _ identifier: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            app.descendants(matching: .any)[identifier].waitForExistence(timeout: 5),
            "\(identifier) is missing",
            file: file,
            line: line
        )
    }
}
