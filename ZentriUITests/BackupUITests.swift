import XCTest

/// Settings › Backup against in-memory state: no backup folder is chosen and nothing has been backed
/// up. The system file pickers are never driven; only the screen that opens them is checked.
@MainActor
final class BackupUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testBackupScreenOffersExportImportAndFolderAndWarnsAboutPlainJSON() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-UITestSkipOnboarding", "-UITestSeed"]
        app.launch()
        let settings = app.tab("Settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "The tab bar did not appear")
        settings.tap()
        app.buttons["settings.backup"].tap()

        let export = app.buttons["backup.export"]
        XCTAssertTrue(export.waitForExistence(timeout: 5), "Backup has no Export button")
        XCTAssertTrue(app.scrolledTo(app.buttons["backup.import"]).exists, "Backup has no Import button")

        let chooseFolder = app.scrolledTo(app.buttons["backup.chooseFolder"])
        XCTAssertTrue(chooseFolder.exists, "Backup has no folder button")
        XCTAssertTrue(chooseFolder.label.contains("Choose iCloud Drive folder"), "The folder button reads \(chooseFolder.label)")

        let status = app.scrolledTo(app.descendants(matching: .any)["backup.lastBackup"])
        XCTAssertTrue(status.waitForExistence(timeout: 5), "Backup shows no last-backup status")
        XCTAssertTrue(status.label.contains("Never"), "The last-backup status reads \(status.label)")

        let warning = app.scrolledTo(app.descendants(matching: .any)["backup.plainJSONWarning"])
        XCTAssertTrue(warning.exists, "Backup does not warn that files are plain JSON")
        XCTAssertTrue(warning.label.contains("plain JSON"), "The warning reads \(warning.label)")
        XCTAssertTrue(warning.label.contains("SMS"), "The warning does not mention the SMS text: \(warning.label)")

        // With no folder chosen, the restore browser says so instead of showing an empty list.
        app.scrolledTo(app.buttons["settings.backupRestore"]).tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["backup.restore.noFolder"].waitForExistence(timeout: 5),
            "The restore browser does not say that no folder is chosen"
        )
        XCTAssertTrue(app.buttons["backup.restore.chooseFile"].exists, "The restore browser cannot pick a file")
    }
}
