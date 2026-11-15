import XCTest

/// The Insights tab against the dashboard fixture plus two months of spending.
///
/// This month holds Starbucks (Dining, −250) and Salary (+5,000) from the dashboard fixture, and a
/// Grab ride (Transport, −750) from the insights fixture: 1,000 spent, a quarter of it on Dining.
/// Last month holds Dining −500 and Transport −300, so Dining is half what it was. Every row is
/// dated from the run's own clock, so the test holds on any day of any month.
@MainActor
final class InsightsUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testTheMonthShowsCategoriesObservationsAndChartsAndDrillsIntoTransactions() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-UITestSkipOnboarding", "-UITestSeed", "-UITestSeedInsights"]
        app.launch()
        app.tabBars.buttons["Insights"].tap()

        // The selected month is this month.
        let month = app.staticTexts["insights.month"]
        XCTAssertTrue(month.waitForExistence(timeout: 10), "The month selector is missing")
        XCTAssertEqual(month.label, monthName(Date.now))
        assertLabel("insights.totalSpend", contains: usd(1_000), in: app)

        // The ranked list gives each category its share of the month.
        let dining = categoryRow("Dining", in: app)
        XCTAssertTrue(dining.waitForExistence(timeout: 5), "The category list has no Dining row")
        XCTAssertTrue(dining.label.contains("25%"), "The Dining row reads \(dining.label)")
        XCTAssertTrue(categoryRow("Transport", in: app).label.contains("75%"))

        // A deterministic observation compares Dining with last month.
        let observation = app.descendants(matching: .any)
            .matching(identifier: "insights.observation")
            .matching(NSPredicate(format: "label == %@", "Dining is 50% lower than last month."))
            .firstMatch
        XCTAssertTrue(observation.exists, "The month-over-month observation is missing")

        // The daily chart announces itself.
        let dailyChart = app.descendants(matching: .any)["insights.dailyChart"].firstMatch
        XCTAssertTrue(dailyChart.exists, "The daily spending chart is missing")
        XCTAssertEqual(dailyChart.label, "Daily spending")

        // Changing the month updates the totals; "This month" comes back.
        app.buttons["insights.previousMonth"].tap()
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date.now)!
        XCTAssertTrue(waitForLabel(monthName(lastMonth), of: month), "The month did not change to \(monthName(lastMonth))")
        assertLabel("insights.totalSpend", contains: usd(800), in: app)
        app.buttons["insights.thisMonth"].tap()
        XCTAssertTrue(waitForLabel(monthName(Date.now), of: month), "This month did not come back")
        assertLabel("insights.totalSpend", contains: usd(1_000), in: app)

        // Tapping a category opens Transactions filtered to it.
        categoryRow("Dining", in: app).tap()
        XCTAssertTrue(
            waitForSelection(of: app.tabBars.buttons["Transactions"]),
            "Tapping a category did not switch to Transactions"
        )
        XCTAssertTrue(transactionRow("Starbucks", in: app).waitForExistence(timeout: 5), "The Dining row is missing")
        XCTAssertFalse(transactionRow("Grab", in: app).exists, "The list is not filtered to Dining")
    }

    // MARK: - Helpers

    private func monthName(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }

    private func categoryRow(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "insights.category.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),"))
            .firstMatch
    }

    private func transactionRow(_ merchant: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "transactions.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", "\(merchant),"))
            .firstMatch
    }

    private func waitForLabel(_ label: String, of element: XCUIElement) -> Bool {
        let matches = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        return XCTWaiter().wait(for: [matches], timeout: 5) == .completed
    }

    private func waitForSelection(of element: XCUIElement) -> Bool {
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: element)
        return XCTWaiter().wait(for: [selected], timeout: 5) == .completed
    }

    /// The fixture settings are USD with Western grouping, the app's defaults.
    private func usd(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        return "$" + (formatter.string(from: NSDecimalNumber(decimal: amount)) ?? amount.description)
    }

    private func assertLabel(
        _ identifier: String,
        contains expected: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 5), "\(identifier) is missing", file: file, line: line)
        let matches = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", expected),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [matches], timeout: 5),
            .completed,
            "\(identifier) reads \(element.label), which does not contain \(expected)",
            file: file,
            line: line
        )
    }
}
