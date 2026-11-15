import XCTest

/// The Shortcuts setup guide: the five steps, the button that opens Shortcuts, the test console,
/// the ingestion health summary, and the troubleshooting notes — from Settings and from onboarding.
@MainActor
final class ShortcutsSetupUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testSettingsGuideShowsEveryStepTheTestConsoleAndTroubleshooting() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-UITestSkipOnboarding", "-UITestSeed"]
        app.launch()
        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "The tab bar did not appear")
        settings.tap()

        let row = app.buttons["settings.shortcuts"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Settings has no Shortcuts row")
        row.tap()

        assertGuide(in: app)

        // The health summary is the Overview card's: the dashboard fixture has one failed message.
        let failures = scrolledTo(app.descendants(matching: .any)["overview.health.failureCount"], in: app)
        XCTAssertTrue(failures.label.contains("1"), "The health summary reads \(failures.label)")

        // The test console is the live rule tester.
        scrolledTo(app.buttons["shortcuts.tester"], in: app).tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["tester.text"].waitForExistence(timeout: 5),
            "The test-console link did not open the rule tester"
        )
    }

    func testOnboardingShortcutsStepOpensTheFullGuide() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-UITestReset"]
        app.launch()

        let continueButton = app.buttons["onboarding.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5), "Onboarding did not start")
        continueButton.tap() // Welcome.
        XCTAssertTrue(app.buttons["onboarding.currency.BDT"].waitForExistence(timeout: 5), "The currency step is missing")
        continueButton.tap() // Currency, left at the default.

        let name = app.textFields["onboarding.account.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Everyday")
        let balance = app.textFields["onboarding.account.balance"]
        balance.tap()
        balance.typeText("100")
        app.buttons["onboarding.keyboard.done"].tap()
        continueButton.tap()

        XCTAssertTrue(app.buttons["onboarding.parser.rules"].waitForExistence(timeout: 5), "The parser step is missing")
        continueButton.tap() // Parser, left at Hybrid, which skips the rules step.

        tapClearOfFooter(app.buttons["onboarding.shortcuts.guide"], in: app)
        assertGuide(in: app)

        app.buttons["shortcuts.guide.done"].tap()
        XCTAssertTrue(
            app.buttons["onboarding.shortcuts.open"].waitForExistence(timeout: 5),
            "Closing the guide did not return to the Shortcuts step"
        )
    }

    // MARK: - Helpers

    /// The guide's five steps, its Open Shortcuts button, its test-console link, and troubleshooting.
    private func assertGuide(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let expectedSteps = [
            "Automation",
            "sender",
            "Run Immediately",
            "Capture Bank SMS",
            "SMS Text",
        ]
        for (index, phrase) in expectedSteps.enumerated() {
            let step = app.descendants(matching: .any)["shortcuts.step.\(index + 1)"]
            XCTAssertTrue(step.waitForExistence(timeout: 5), "Step \(index + 1) is missing", file: file, line: line)
            XCTAssertTrue(
                step.label.hasPrefix("\(index + 1)"),
                "Step \(index + 1) is not numbered: \(step.label)",
                file: file,
                line: line
            )
            XCTAssertTrue(
                step.label.contains(phrase),
                "Step \(index + 1) reads \(step.label)",
                file: file,
                line: line
            )
        }

        let open = app.buttons["shortcuts.open"]
        XCTAssertTrue(open.exists, "The guide has no Open Shortcuts button", file: file, line: line)
        XCTAssertTrue(open.label.contains("Open Shortcuts"), "The button reads \(open.label)", file: file, line: line)

        let tester = scrolledTo(app.buttons["shortcuts.tester"], in: app)
        XCTAssertTrue(tester.exists, "The guide has no test-console link", file: file, line: line)

        let runImmediately = scrolledTo(
            app.descendants(matching: .any)["shortcuts.troubleshooting.runImmediately"],
            in: app
        )
        XCTAssertTrue(
            runImmediately.label.contains("Run Immediately"),
            "The Run Immediately note reads \(runImmediately.label)",
            file: file,
            line: line
        )
        let sender = scrolledTo(app.descendants(matching: .any)["shortcuts.troubleshooting.sender"], in: app)
        XCTAssertTrue(
            sender.label.contains("sender"),
            "The sender note reads \(sender.label)",
            file: file,
            line: line
        )
    }

    /// Scrolls the onboarding step until the element sits above the footer, then taps it.
    private func tapClearOfFooter(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(element)")
        // The footer is a 44-point row plus padding above the home indicator, with room to spare.
        let clearMaxY = app.frame.maxY - 180
        var attempts = 0
        while element.frame.maxY > clearMaxY && attempts < 5 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertLessThanOrEqual(element.frame.maxY, clearMaxY, "\(element) never scrolled clear of the footer")
        element.tap()
    }

    /// Scrolls until the element is on screen, so a tall guide works at every text size.
    @discardableResult
    private func scrolledTo(_ element: XCUIElement, in app: XCUIApplication) -> XCUIElement {
        var attempts = 0
        while !(element.exists && element.isHittable) && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(element.exists, "Missing \(element)")
        return element
    }
}
