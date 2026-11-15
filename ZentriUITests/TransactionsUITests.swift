import XCTest

/// The Transactions tab against the dashboard fixture plus the Transactions history.
///
/// The store holds Starbucks (−250) and Salary (+5,000) today, and a Grab ride (−120) yesterday
/// with the bank message it came from. The ride predates the opening checkpoint of 1,000,000, so the
/// balance the list shows is 1,000,000 − 250 + 5,000.
@MainActor
final class TransactionsUITests: XCTestCase {
    private let startingBalance = Decimal(1_000_000 - 250 + 5_000)

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testTheListSearchesOpensDetailEditsAndAddsManualTransactions() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-UITestSkipOnboarding", "-UITestSeed", "-UITestSeedHistory"]
        app.launch()
        app.tabBars.buttons["Transactions"].tap()

        // Day headers and merchant rows.
        XCTAssertTrue(row("Starbucks", in: app).waitForExistence(timeout: 10), "The Starbucks row is missing")
        XCTAssertTrue(row("Grab", in: app).exists, "The Grab row is missing")
        XCTAssertGreaterThanOrEqual(
            app.descendants(matching: .any).matching(identifier: "transactions.dayHeader").count,
            2,
            "The list is not grouped into today and yesterday"
        )
        assertLabel("transactions.balance", contains: usd(startingBalance), in: app)

        // Searching narrows the list to the ride.
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), "The list is not searchable")
        search.tap()
        search.typeText("Grab")
        XCTAssertTrue(waitForDisappearance(of: row("Starbucks", in: app)), "Search did not filter out Starbucks")
        XCTAssertTrue(row("Grab", in: app).exists, "Search hid the matching row")

        // The detail shows the amount, merchant, and raw SMS.
        row("Grab", in: app).tap()
        assertLabel("transactions.detail.amount", contains: usd(120), in: app)
        assertLabel("transactions.detail.merchant", contains: "Grab", in: app)
        XCTAssertTrue(
            app.staticTexts["Card payment of USD 120.00 at GRAB*TRIP on your Everyday account."]
                .waitForExistence(timeout: 5),
            "The detail does not show the raw SMS"
        )

        // Marking it a transfer updates the detail and the list badge.
        let transfer = app.switches["transactions.detail.transfer"]
        XCTAssertTrue(transfer.waitForExistence(timeout: 5), "The transfer toggle is missing")
        XCTAssertEqual(transfer.value as? String, "0")
        transfer.switches.firstMatch.tap()
        XCTAssertTrue(waitForValue("1", of: transfer), "The transfer toggle did not turn on")

        // Editing the merchant updates the row.
        app.buttons["transactions.detail.edit"].tap()
        let merchant = app.textFields["transactions.editor.merchant"]
        XCTAssertTrue(merchant.waitForExistence(timeout: 5), "The editor did not open")
        merchant.tap()
        merchant.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 10) + "Grab Taxi")
        app.buttons["transactions.editor.save"].tap()
        assertLabel("transactions.detail.merchant", contains: "Grab Taxi", in: app)
        app.buttons["transactions.detail.done"].tap()

        let edited = row("Grab Taxi", in: app)
        XCTAssertTrue(edited.waitForExistence(timeout: 5), "The edited merchant did not reach the list")
        XCTAssertTrue(edited.label.contains("Transfer"), "The row reads \(edited.label), without its transfer badge")

        // A manual add appears with its badge and moves the balance.
        search.tap()
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4))
        XCTAssertTrue(row("Starbucks", in: app).waitForExistence(timeout: 5), "Clearing the search did not restore the list")
        // Leaving search gives the navigation bar back its actions.
        app.navigationBars.buttons["Close"].tap()
        app.buttons["transactions.add"].tap()
        let amount = app.textFields["transactions.editor.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "The manual editor did not open")
        amount.tap()
        amount.typeText("25")
        let newMerchant = app.textFields["transactions.editor.merchant"]
        newMerchant.tap()
        newMerchant.typeText("Missed payment")
        app.buttons["transactions.editor.save"].tap()

        let manual = row("Missed payment", in: app)
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "The manual transaction is not in the list")
        XCTAssertTrue(manual.label.contains("Manual"), "The row reads \(manual.label), without its manual badge")
        assertLabel("transactions.balance", contains: usd(startingBalance - 25), in: app)
    }

    func testAnEmptyStoreExplainsThatMessagesFillTheList() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-UITestSkipOnboarding"]
        app.launch()
        app.tabBars.buttons["Transactions"].tap()

        XCTAssertTrue(
            app.staticTexts["No transactions yet"].waitForExistence(timeout: 10),
            "The empty state did not appear"
        )
    }

    // MARK: - Helpers

    /// The list row whose spoken summary starts with the merchant.
    private func row(_ merchant: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "transactions.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", "\(merchant),"))
            .firstMatch
    }

    private func waitForDisappearance(of element: XCUIElement) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: 5) == .completed
    }

    private func waitForValue(_ value: String, of element: XCUIElement) -> Bool {
        let matches = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        return XCTWaiter().wait(for: [matches], timeout: 5) == .completed
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
