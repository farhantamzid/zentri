import XCTest

/// Settings › Parsing against the dashboard fixture plus the parsing fixture: one account, a rule
/// named "Fixture card debit" that reads "RM42.75 spent at Fixture Cafe.", and that message archived
/// as failed. The app runs with a model client that is always unavailable.
@MainActor
final class ParsingUITests: XCTestCase {
    private let ruleName = "Fixture card debit"
    private let sample = "MYBANK: RM42.75 spent at Fixture Cafe. Thank you."

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testRuleListShowsTheRuleAndSaveNeedsAnAmountGroup() {
        let app = launchedInParsing()
        app.buttons["parsing.rules"].tap()

        let rule = row("parsingRules.row", containing: ruleName, in: app)
        XCTAssertTrue(rule.waitForExistence(timeout: 5), "The seeded rule is not listed")

        app.buttons["parsingRules.add"].tap()
        let name = app.textFields["ruleEditor.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "The rule editor did not open")
        name.tap()
        name.typeText("No amount")
        let pattern = app.descendants(matching: .any)["ruleEditor.pattern"]
        pattern.tap()
        pattern.typeText("spent at (?<merchant>.+)")

        let save = app.buttons["ruleEditor.save"]
        XCTAssertTrue(save.exists, "The editor has no Save button")
        XCTAssertFalse(save.isEnabled, "A pattern without an amount group can be saved")
        XCTAssertTrue(
            app.descendants(matching: .any)["ruleEditor.patternError"].waitForExistence(timeout: 5),
            "The editor does not explain why the pattern can't be saved"
        )

        pattern.typeText(" RM(?<amount>[0-9.]+)")
        XCTAssertTrue(waitUntilEnabled(save), "A pattern with an amount group still can't be saved")
    }

    func testTesterReadsTheSampleAndReportsTheModelUnavailable() {
        let app = launchedInParsing()
        app.buttons["parsing.tester"].tap()

        let text = app.descendants(matching: .any)["tester.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5), "The tester has no message field")
        text.tap()
        text.typeText(sample)
        app.buttons["tester.run"].tap()

        let amount = app.descendants(matching: .any)["tester.rules.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10), "The tester shows no amount")
        XCTAssertTrue(amount.label.contains("42.75"), "The amount reads \(amount.label)")
        let merchant = app.scrolledTo(app.descendants(matching: .any)["tester.rules.merchant"])
        XCTAssertTrue(merchant.label.contains("Fixture Cafe"), "The merchant reads \(merchant.label)")
        let matched = app.scrolledTo(app.descendants(matching: .any)["tester.rules.matchedRule"])
        XCTAssertTrue(matched.label.contains(ruleName), "The matched rule reads \(matched.label)")
        XCTAssertFalse(app.descendants(matching: .any)["tester.model.status"].exists, "The model ran without being asked")

        // The switch sits above the results the test just read.
        let compare = app.scrolledBackTo(app.switches["tester.compare"])
        XCTAssertTrue(compare.exists, "The tester has no Compare with AI switch")
        compare.switches.firstMatch.tap()
        XCTAssertTrue(waitForValue(of: compare, toBe: "1"), "Compare with AI did not switch on")

        let status = app.descendants(matching: .any)["tester.model.status"]
        XCTAssertTrue(scrollUntilExists(status, in: app), "Comparing with AI shows no model status")
        XCTAssertTrue(status.label.contains("AI unavailable"), "The model status reads \(status.label)")
    }

    func testInboxReprocessesTheFailedMessageAndAsksBeforeClearing() {
        let app = launchedInParsing()
        tapScrollingIfNeeded(app.buttons["parsing.inbox"], in: app)

        let message = row("inbox.row", containing: "Fixture Cafe", in: app)
        XCTAssertTrue(message.waitForExistence(timeout: 5), "The failed message is not in the inbox")
        message.tap()

        let reprocess = app.buttons["inbox.detail.reprocess"]
        XCTAssertTrue(reprocess.waitForExistence(timeout: 5), "The message detail has no Reprocess")
        reprocess.tap()
        let status = app.descendants(matching: .any)["inbox.detail.status"]
        XCTAssertTrue(waitForLabel(of: status, toContain: "Parsed"), "The message did not become parsed: \(status.label)")
        XCTAssertTrue(app.scrolledTo(app.buttons["inbox.detail.transaction"]).exists, "The parsed message links no transaction")

        app.goBack()
        XCTAssertTrue(
            app.descendants(matching: .any)["inbox.empty"].waitForExistence(timeout: 5)
                || !row("inbox.row", containing: "Fixture Cafe", in: app).exists,
            "The message is still listed under Failed"
        )
        app.segmentedControls.buttons["Parsed"].tap()
        XCTAssertTrue(
            row("inbox.row", containing: "Fixture Cafe", in: app).waitForExistence(timeout: 5),
            "The message is not listed under Parsed"
        )

        // The transaction it became is in the history.
        app.tab("Transactions").tap()
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", "Fixture Cafe"))
                .firstMatch
                .waitForExistence(timeout: 5),
            "The reprocessed transaction is not in Transactions"
        )
        app.tab("Settings").tap()

        let clear = app.buttons["inbox.clearArchive"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5), "The inbox has no Clear Archive")
        clear.tap()
        let confirm = app.staticTexts["Clear the message archive?"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Clear Archive did not ask first")
        // The dialog is a popover with no Cancel button; tapping outside it cancels.
        app.otherElements["PopoverDismissRegion"].tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5), "The confirmation did not close")
        XCTAssertTrue(
            row("inbox.row", containing: "Fixture Cafe", in: app).waitForExistence(timeout: 5),
            "Cancelling Clear Archive still removed the message"
        )
    }

    func testAccountAndOverviewLinkToTheParsingScreens() {
        let app = launchedInParsing()
        app.goBack()
        app.buttons["settings.accounts"].tap()
        row("accounts.row", containing: "Everyday", in: app).tap()
        let rules = app.buttons["accounts.detail.rules"]
        XCTAssertTrue(rules.waitForExistence(timeout: 5), "The account has no Parsing Rules link")
        rules.tap()
        XCTAssertTrue(
            row("parsingRules.row", containing: ruleName, in: app).waitForExistence(timeout: 5),
            "The account's rules are not listed"
        )

        app.tab("Overview").tap()
        tapScrollingIfNeeded(app.buttons["overview.health.inbox"], in: app)
        XCTAssertTrue(
            row("inbox.row", containing: "Fixture Cafe", in: app).waitForExistence(timeout: 5),
            "The health card did not open the inbox"
        )
    }

    // MARK: - Helpers

    private func launchedInParsing() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-UITestSkipOnboarding", "-UITestSeed", "-UITestSeedParsing"]
        app.launch()
        let settings = app.tab("Settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "The tab bar did not appear")
        settings.tap()
        let parsing = app.scrolledTo(app.buttons["settings.parsing"])
        XCTAssertTrue(parsing.waitForExistence(timeout: 5), "Settings has no Parsing row")
        parsing.tap()
        XCTAssertTrue(app.scrolledTo(app.buttons["parsing.rules"]).waitForExistence(timeout: 5), "Parsing did not open")
        return app
    }

    private func row(_ identifier: String, containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    private func waitForLabel(of element: XCUIElement, toContain text: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", text),
            object: element
        )
        return XCTWaiter().wait(for: [expectation], timeout: 10) == .completed
    }

    private func waitForValue(of element: XCUIElement, toBe value: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
    }

    /// Waits for `element`, scrolling down when the list has not created it yet.
    private func scrollUntilExists(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        if element.waitForExistence(timeout: 2) { return true }
        return app.scrolledTo(element).waitForExistence(timeout: 2)
    }

    /// Scrolls until `element` can be tapped, then taps it.
    private func tapScrollingIfNeeded(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "\(element) never became tappable")
        element.tap()
    }

    private func waitUntilEnabled(_ element: XCUIElement) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
    }
}
