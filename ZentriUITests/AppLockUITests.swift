import XCTest

/// The Face ID lock against a scripted check (`-UITestMockBiometrics`), since the simulator has no
/// enrolled face. Turning the lock on runs the check; leaving the app locks it; returning asks again.
@MainActor
final class AppLockUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testTurningTheLockOnLocksTheAppWhenItLeavesAndAPassingCheckUnlocksIt() {
        let app = launched(biometrics: "success")
        turnOnFaceID(in: app)

        leaveAndReturn(app)

        // The lock is up and the tabs beneath it cannot be reached.
        let cover = app.descendants(matching: .any)["lock.cover"]
        XCTAssertTrue(cover.waitForExistence(timeout: 5), "Returning to the app did not show the lock")
        XCTAssertFalse(app.tabBars.buttons["Overview"].isHittable, "The tabs are reachable behind the lock")

        // It asks on its own, and the scripted check passes.
        XCTAssertTrue(waitForDisappearance(of: cover), "A passing check did not lift the lock")
        XCTAssertTrue(app.tabBars.buttons["Overview"].isHittable, "The tabs are not reachable after unlocking")
    }

    func testTheLockCoversAnOpenSheet() {
        let app = launched(biometrics: "success")
        turnOnFaceID(in: app)

        // A transaction's detail sheet sits above the tab view, out of reach of an overlay there.
        app.tabBars.buttons["Transactions"].tap()
        let row = app.descendants(matching: .any).matching(identifier: "transactions.row").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Transactions has no rows")
        row.tap()
        let amount = app.descendants(matching: .any)["transactions.detail.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "The detail sheet did not open")

        leaveAndReturn(app)

        let cover = app.descendants(matching: .any)["lock.cover"]
        XCTAssertTrue(cover.waitForExistence(timeout: 5), "Returning to the app did not show the lock")
        XCTAssertFalse(amount.isHittable, "The detail sheet is reachable above the lock")

        XCTAssertTrue(waitForDisappearance(of: cover), "A passing check did not lift the lock")
        XCTAssertTrue(amount.isHittable, "The detail sheet did not come back after unlocking")
    }

    func testALinkOpenedWhileLockedOpensItsTabAfterUnlocking() throws {
        let app = launched(biometrics: "success")
        turnOnFaceID(in: app)

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10), "Zentri did not go to the background")
        app.open(try XCTUnwrap(URL(string: "zentri://insights")))

        // Relaunching for the link can take longer than the scripted check, so the lock may already
        // have lifted by the time the test can look; the unit tests cover holding the link while
        // locked. What matters here is that the link is not lost on the way through the lock.
        let cover = app.descendants(matching: .any)["lock.cover"]
        XCTAssertTrue(waitForDisappearance(of: cover), "A passing check did not lift the lock")

        let insights = app.tabBars.buttons["Insights"]
        XCTAssertTrue(
            insights.waitForExistence(timeout: 5) && waitForSelection(of: insights),
            "The link held while locked did not open Insights after unlocking"
        )
    }

    func testAFailedCheckLeavesTheLockOffAndSaysWhy() {
        let app = launched(biometrics: "failure")
        let toggle = openFaceIDToggle(in: app)

        // The row's own switch: tapping the label beside it does nothing in a Form.
        toggle.switches.firstMatch.tap()

        let message = app.descendants(matching: .any)["appearance.faceID.message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5), "A failed check gave no reason")
        XCTAssertEqual(toggle.value as? String, "0", "A failed check turned the lock on")

        // Leaving and returning does not lock an app whose lock never turned on.
        leaveAndReturn(app)
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["lock.cover"].exists, "The app locked without the lock on")
    }

    private func launched(biometrics: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UITestMode", "-UITestSkipOnboarding", "-UITestSeed", "-UITestMockBiometrics", biometrics,
        ]
        app.launch()
        return app
    }

    /// Opens Settings › Appearance and returns the Face ID toggle, scrolled into view.
    private func openFaceIDToggle(in app: XCUIApplication) -> XCUIElement {
        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "The Settings tab is missing")
        settings.tap()
        let appearance = app.buttons["settings.appearance"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 5), "Settings has no Appearance row")
        appearance.tap()

        let toggle = app.switches["appearance.faceID"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Appearance has no Face ID toggle")
        var swipes = 0
        while !toggle.isHittable && swipes < 5 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertEqual(toggle.value as? String, "0", "The lock should start off")
        return toggle
    }

    /// Turns the lock on through the toggle, whose check the script passes.
    private func turnOnFaceID(in app: XCUIApplication) {
        let toggle = openFaceIDToggle(in: app)
        toggle.switches.firstMatch.tap()
        let on = NSPredicate(format: "value == '1'")
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: on, object: toggle)], timeout: 10)
        XCTAssertEqual(result, .completed, "A passing check did not turn the lock on")
    }

    private func leaveAndReturn(_ app: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10), "Zentri did not go to the background")
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10), "Zentri did not come back")
    }

    private func waitForDisappearance(of element: XCUIElement) -> Bool {
        let gone = NSPredicate(format: "exists == false")
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: gone, object: element)], timeout: 10) == .completed
    }

    private func waitForSelection(of element: XCUIElement) -> Bool {
        let selected = NSPredicate(format: "isSelected == true")
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: selected, object: element)], timeout: 5) == .completed
    }
}
