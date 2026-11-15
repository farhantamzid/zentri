import XCTest

/// The first-run flow, walked end to end the way a person would: currency, grouping, the first
/// account, the parser engine, rules, Shortcuts, Face ID, and the completion screen.
@MainActor
final class OnboardingUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testOnboardingFinishesWithBDTIndianAndOpensOverview() {
        let app = XCUIApplication()
        // No skip-onboarding switch: the reset leaves no settings, so the flow is what launches.
        app.launchArguments = ["-UITestMode", "-UITestReset"]
        app.launch()

        let continueButton = app.buttons["onboarding.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5), "Onboarding did not start")

        // Welcome and privacy.
        continueButton.tap()

        // Currency and number grouping.
        let bdt = app.buttons["onboarding.currency.BDT"]
        tapClearOfFooter(bdt, in: app)
        XCTAssertTrue(bdt.isSelected, "BDT should be the selected currency")

        let indian = app.buttons["onboarding.grouping.indian"]
        tapClearOfFooter(indian, in: app)
        XCTAssertTrue(indian.isSelected, "Indian should be the selected grouping")
        continueButton.tap()

        // The first account.
        let name = app.textFields["onboarding.account.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Everyday")

        let balance = app.textFields["onboarding.account.balance"]
        XCTAssertTrue(balance.exists)
        balance.tap()
        balance.typeText("1000000")

        let keyboardDone = app.buttons["onboarding.keyboard.done"]
        XCTAssertTrue(keyboardDone.waitForExistence(timeout: 5), "The decimal keyboard's Done button is missing")
        keyboardDone.tap()
        continueButton.tap()

        // The parser engine: Rules, then the screen that says where rules live.
        let rules = app.buttons["onboarding.parser.rules"]
        tapClearOfFooter(rules, in: app)
        XCTAssertTrue(rules.isSelected, "Rules should be the selected engine")
        continueButton.tap()

        let rulesContinue = app.buttons["onboarding.rules.continue"]
        tapClearOfFooter(rulesContinue, in: app)

        // Shortcuts: offered, then skipped, since the automation is built in the Shortcuts app.
        let openShortcuts = app.buttons["onboarding.shortcuts.open"]
        XCTAssertTrue(openShortcuts.waitForExistence(timeout: 5))
        continueButton.tap()

        // Face ID is off by default, so continuing leaves it off.
        let faceIDToggle = app.switches["onboarding.faceID.toggle"]
        XCTAssertTrue(faceIDToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(faceIDToggle.value as? String, "0", "Face ID should start off")
        continueButton.tap()

        // The completion screen shows the balance with the chosen currency and grouping.
        let completedBalance = app.staticTexts["setupComplete.balance"]
        XCTAssertTrue(completedBalance.waitForExistence(timeout: 5), "The completion screen did not appear")
        XCTAssertEqual(completedBalance.label, "৳10,00,000.00")

        let goToOverview = app.buttons["setupComplete.continue"]
        XCTAssertTrue(goToOverview.exists)
        goToOverview.tap()

        XCTAssertTrue(app.tab("Overview").waitForExistence(timeout: 5), "The app did not enter the tabs")
    }

    /// Taps an element, scrolling it clear of the pinned footer first.
    ///
    /// Long steps (eleven currencies, three grouping examples) put controls under the footer, and
    /// an element behind it still reports itself as hittable, so the tap would land on Continue.
    /// Scrolling until the element's bottom edge is above the footer keeps the tap on the control
    /// the test names.
    private func tapClearOfFooter(
        _ element: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(element)", file: file, line: line)
        // Clear of the pinned footer, measured rather than assumed, so a short display works too.
        let clearMaxY = app.onboardingFooterTop - 8
        var attempts = 0
        while element.frame.maxY > clearMaxY && attempts < 5 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertLessThanOrEqual(
            element.frame.maxY,
            clearMaxY,
            "\(element) never scrolled clear of the footer",
            file: file,
            line: line
        )
        element.tap()
    }
}
