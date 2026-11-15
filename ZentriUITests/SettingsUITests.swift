import XCTest

/// The Settings tab against the dashboard fixture: one account opened at 1,000,000, a 250 debit, and
/// a 5,000 credit, with the seeded categories and USD/Western settings.
@MainActor
final class SettingsUITests: XCTestCase {
    private let startingBalance = Decimal(1_000_000 - 250 + 5_000)

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testSettingsListsEverySection() {
        let app = launchedInSettings()

        let rows = [
            ("settings.accounts", "Accounts"),
            ("settings.categories", "Categories"),
            ("settings.appearance", "Appearance"),
            ("settings.backup", "Backup"),
            ("settings.parsing", "Parsing"),
            ("settings.shortcuts", "Shortcuts"),
            ("settings.about", "About"),
        ]
        for (identifier, title) in rows {
            let row = app.buttons[identifier]
            XCTAssertTrue(row.waitForExistence(timeout: 5), "Settings has no \(title) row")
            XCTAssertTrue(row.label.contains(title), "The \(identifier) row reads \(row.label)")
        }

        // Backup opens its own screen (BackupUITests covers what it holds).
        app.buttons["settings.backup"].tap()
        XCTAssertTrue(app.buttons["backup.export"].waitForExistence(timeout: 5), "Backup did not open")
    }

    func testAddingAnAccountAndSettingItsBalanceReachTheOverview() {
        let app = launchedInSettings()
        app.buttons["settings.accounts"].tap()

        // Add an account with an opening balance.
        let add = app.buttons["accounts.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "Accounts has no Add button")
        add.tap()
        let name = app.textFields["accounts.editor.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "The account editor did not open")
        name.tap()
        name.typeText("Savings")
        let opening = app.textFields["accounts.editor.openingBalance"]
        opening.tap()
        opening.typeText("2500")
        app.buttons["accounts.editor.save"].tap()

        let savings = accountRow("Savings", in: app)
        XCTAssertTrue(savings.waitForExistence(timeout: 5), "The new account is not listed")
        XCTAssertTrue(savings.label.contains(usd(2_500)), "The new account's row reads \(savings.label)")

        // The Overview total includes it.
        app.tabBars.buttons["Overview"].tap()
        let hero = element("label BEGINSWITH %@", ["Combined balance"], in: app)
        XCTAssertTrue(hero.waitForExistence(timeout: 10), "The balance hero did not appear")
        XCTAssertTrue(
            hero.label.contains(usd(startingBalance + 2_500)),
            "The hero reads \(hero.label), which does not include the new account"
        )

        // Set balance updates the account's balance and the total.
        app.tabBars.buttons["Settings"].tap()
        accountRow("Savings", in: app).tap()
        let setBalance = app.buttons["accounts.detail.setBalance"]
        XCTAssertTrue(setBalance.waitForExistence(timeout: 5), "The account detail has no Set Balance")
        setBalance.tap()
        let amount = app.textFields["accounts.setBalance.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "The Set Balance sheet did not open")
        amount.tap()
        amount.typeText("3000")
        app.buttons["accounts.setBalance.save"].tap()

        let balance = app.descendants(matching: .any)["accounts.detail.balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 5), "The detail balance is missing")
        XCTAssertTrue(waitForLabel(of: balance, toContain: usd(3_000)), "The detail balance reads \(balance.label)")

        app.tabBars.buttons["Overview"].tap()
        XCTAssertTrue(
            waitForLabel(of: hero, toContain: usd(startingBalance + 3_000)),
            "The hero reads \(hero.label) after setting the balance"
        )
    }

    func testIndianGroupingPreviewsAndCurrencyChangeWarns() {
        let app = launchedInSettings()
        app.buttons["settings.appearance"].tap()

        let preview = app.descendants(matching: .any)["appearance.preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5), "Appearance has no preview")
        XCTAssertTrue(preview.label.contains("1,000,000.00"), "The Western preview reads \(preview.label)")

        let indian = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Indian")).firstMatch
        XCTAssertTrue(indian.waitForExistence(timeout: 5), "Appearance has no Indian grouping option")
        indian.tap()
        XCTAssertTrue(waitForLabel(of: preview, toContain: "10,00,000.00"), "The Indian preview reads \(preview.label)")

        app.buttons["appearance.currency"].tap()
        let inr = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "INR")).firstMatch
        XCTAssertTrue(inr.waitForExistence(timeout: 5), "The currency list has no INR")
        inr.tap()
        XCTAssertTrue(
            app.staticTexts["Amounts are not converted."].waitForExistence(timeout: 5),
            "Changing the currency did not warn that amounts are not converted"
        )

        // Confirming changes only the symbol: the same million, now in rupees, still grouped the Indian way.
        app.buttons["Change to INR"].tap()
        XCTAssertTrue(waitForLabel(of: preview, toContain: "₹10,00,000.00"), "The preview reads \(preview.label)")
    }

    func testAddingACategoryShowsItInTheList() {
        let app = launchedInSettings()
        app.buttons["settings.categories"].tap()

        let add = app.buttons["categories.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "Categories has no Add button")
        add.tap()
        let name = app.textFields["categories.editor.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "The category editor did not open")
        name.tap()
        name.typeText("Pets")
        app.buttons["categories.editor.save"].tap()

        let row = app.descendants(matching: .any)
            .matching(identifier: "categories.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Pets"))
            .firstMatch
        // New categories sort last, below the seeded twelve, so scroll until the row is drawn.
        for _ in 0..<4 where !row.exists {
            app.swipeUp()
        }
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The new category is not listed")
    }

    // MARK: - Helpers

    private func launchedInSettings() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-UITestSkipOnboarding", "-UITestSeed"]
        app.launch()
        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "The tab bar did not appear")
        settings.tap()
        return app
    }

    private func accountRow(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "accounts.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", name))
            .firstMatch
    }

    private func element(_ format: String, _ arguments: [any CVarArg], in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: format, argumentArray: arguments))
            .firstMatch
    }

    private func waitForLabel(of element: XCUIElement, toContain text: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", text),
            object: element
        )
        return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
    }

    /// The fixture settings are USD with Western grouping, which this target cannot import, so the
    /// expected string repeats those rules.
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
}
