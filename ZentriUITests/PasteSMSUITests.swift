import XCTest

/// Adding a transaction by pasting a bank message, against the dashboard fixture plus
/// ``ParsingFixture``'s rule, which reads "RM<amount> spent at <merchant>." as a debit.
///
/// UI tests run with the model unavailable, so Rules reads the message and Foundation Models
/// explains why it cannot.
@MainActor
final class PasteSMSUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testAPastedMessageIsReadByTheChosenEngineAndOpensForReview() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-UITestSkipOnboarding", "-UITestSeed", "-UITestSeedParsing"]
        app.launch()
        app.tab("Transactions").tap()

        let add = app.buttons["transactions.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "The add menu is missing")
        add.tap()
        app.buttons["transactions.add.paste"].tap()

        let text = app.textViews["pasteSMS.text"].exists ? app.textViews["pasteSMS.text"] : app.textFields["pasteSMS.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5), "The paste sheet did not open")
        text.tap()
        text.typeText("MYBANK: RM18.20 spent at Paste Bakery. Thank you.")

        // The model cannot run in UI tests, so it says so and nothing is added.
        app.segmentedControls["pasteSMS.parser"].buttons["Foundation Models"].tap()
        app.buttons["pasteSMS.add"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["pasteSMS.result"].waitForExistence(timeout: 10),
                      "The sheet did not explain why the model could not read the message")

        // The rules read it, and the new transaction opens for review.
        app.segmentedControls["pasteSMS.parser"].buttons["Rules"].tap()
        app.buttons["pasteSMS.add"].tap()
        let amount = app.descendants(matching: .any)["transactions.detail.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10), "The new transaction did not open")
        XCTAssertTrue(amount.label.contains("18.20"), "The detail reads \(amount.label)")
    }
}
