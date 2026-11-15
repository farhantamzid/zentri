import Foundation
import Testing
import UniformTypeIdentifiers
import ZentriCore
@testable import ZentriApp

private enum ExportFailure: Error {
    case storeUnreadable
}

private enum PickerFailure: Error {
    case cancelled
}

/// The Backup screen's model over a fake folder and an export that can be made to fail.
@MainActor
private final class SettingsFixture {
    let folder: FakeBackupFolder
    let settingsStore = SettingsStore(repository: InMemorySettingsRepository())
    var exportError: (any Error)?
    let document = makeBackupDocument(transactionCount: 2)
    lazy var scheduler = BackupScheduler(
        folder: folder,
        makeDocument: { [unowned self] in document },
        didBackUp: { _ in }
    )
    lazy var model = BackupSettingsModel(
        folder: folder,
        settingsStore: settingsStore,
        scheduler: scheduler,
        makeExport: { [unowned self] in
            if let exportError { throw exportError }
            return document
        },
        now: { backupTestDate },
        timeZone: TimeZone(identifier: "Asia/Dhaka") ?? .gmt
    )

    init(folder: FakeBackupFolder = FakeBackupFolder()) throws {
        self.folder = folder
        try settingsStore.save(.defaultValue)
    }
}

@MainActor
@Test func withoutAFolderTheScreenSaysNoneIsChosen() async throws {
    let fixture = try SettingsFixture(folder: FakeBackupFolder(hasFolder: false))

    await fixture.model.refreshFolder()

    #expect(fixture.model.folderState == .none)
}

@MainActor
@Test func aChosenFolderShowsItsName() async throws {
    let fixture = try SettingsFixture()

    await fixture.model.refreshFolder()

    #expect(fixture.model.folderState == .chosen(name: "Zentri Backups"))
}

@MainActor
@Test func aRevokedFolderIsShownAsAnError() async throws {
    let fixture = try SettingsFixture()
    fixture.folder.failResolving(with: .permissionDenied)

    await fixture.model.refreshFolder()

    #expect(fixture.model.folderState == .failed(.permissionDenied))
}

@MainActor
@Test func choosingAnEmptyFolderBacksUpWithoutAsking() async throws {
    let fixture = try SettingsFixture(folder: FakeBackupFolder(hasFolder: false))
    let picked = URL(filePath: "/iCloud/My Backups", directoryHint: .isDirectory)

    await fixture.model.chooseFolder(.success(picked))

    #expect(fixture.folder.chosenFolders == [picked])
    #expect(fixture.model.folderState == .chosen(name: "My Backups"))
    #expect(fixture.model.isAwaitingConfirmation == false)
    #expect(fixture.folder.writeCount == 1)
}

@MainActor
@Test func choosingAFolderWithOtherBackupsAsksBeforeWriting() async throws {
    let folder = FakeBackupFolder(hasFolder: false)
    folder.addSnapshot(of: makeBackupDocument(transactionCount: 40, accountName: "Old phone"))
    let fixture = try SettingsFixture(folder: folder)

    await fixture.model.chooseFolder(.success(URL(filePath: "/iCloud/Zentri Backups")))
    fixture.scheduler.schedule()
    await fixture.scheduler.flush()

    #expect(folder.writeCount == 0)
    #expect(fixture.model.isAwaitingConfirmation)
}

@MainActor
@Test func confirmingBacksThisIPhoneUpToTheFolder() async throws {
    let folder = FakeBackupFolder(hasFolder: false)
    folder.addSnapshot(of: makeBackupDocument(transactionCount: 40, accountName: "Old phone"))
    let fixture = try SettingsFixture(folder: folder)
    await fixture.model.chooseFolder(.success(URL(filePath: "/iCloud/Zentri Backups")))

    await fixture.model.confirmBackingUpHere()

    #expect(folder.holdsWrites == false)
    #expect(folder.writeCount == 1)
    #expect(fixture.model.isAwaitingConfirmation == false)
}

@MainActor
@Test func aHeldFolderStillAsksAfterARelaunch() async throws {
    let folder = FakeBackupFolder(holdsWrites: true)
    folder.addSnapshot(of: makeBackupDocument(transactionCount: 40, accountName: "Old phone"))
    let fixture = try SettingsFixture(folder: folder)

    await fixture.model.refreshFolder()

    #expect(fixture.model.isAwaitingConfirmation)
}

@MainActor
@Test func aFolderThatCannotBeRememberedIsReported() async throws {
    let fixture = try SettingsFixture(folder: FakeBackupFolder(hasFolder: false))
    fixture.folder.failResolving(with: .permissionDenied)

    await fixture.model.chooseFolder(.success(URL(filePath: "/iCloud/My Backups")))

    #expect(fixture.model.failureMessage != nil)
    #expect(fixture.folder.writeCount == 0)
}

@MainActor
@Test func aCancelledFolderPickIsSilent() async throws {
    let fixture = try SettingsFixture(folder: FakeBackupFolder(hasFolder: false))

    await fixture.model.chooseFolder(.failure(PickerFailure.cancelled))

    #expect(fixture.model.failureMessage == nil)
    #expect(fixture.folder.writeCount == 0)
}

@MainActor
@Test func forgettingTheFolderStopsAutomaticBackups() async throws {
    let fixture = try SettingsFixture()
    await fixture.model.refreshFolder()

    await fixture.model.forgetFolder()

    #expect(fixture.folder.hasFolder == false)
    #expect(fixture.model.folderState == .none)
}

@MainActor
@Test func exportingPreparesTheEncodedBackupWithADatedName() async throws {
    let fixture = try SettingsFixture()

    await fixture.model.prepareExport()

    #expect(fixture.model.isExporting)
    #expect(fixture.model.exportFilename == "Zentri-2026-11-18-1706")
    let file = try #require(fixture.model.exportFile)
    #expect(try BackupCodec.decode(file.data) == fixture.document)
}

@MainActor
@Test func anExportThatFailsIsReportedAndOpensNoPicker() async throws {
    let fixture = try SettingsFixture()
    fixture.exportError = ExportFailure.storeUnreadable

    await fixture.model.prepareExport()

    #expect(fixture.model.isExporting == false)
    #expect(fixture.model.exportFile == nil)
    #expect(fixture.model.failureMessage != nil)
}

@MainActor
@Test func theLastBackupComesFromTheSavedSettings() async throws {
    let fixture = try SettingsFixture()
    #expect(fixture.model.lastBackupAt == nil)

    var settings = AppSettings.defaultValue
    settings.lastBackupAt = backupTestDate
    try fixture.settingsStore.save(settings)

    #expect(fixture.model.lastBackupAt == backupTestDate)
}

@MainActor
@Test func theExportedTypeUsesTheZentriBackupExtensionAndIsJSON() {
    #expect(UTType.zentriBackup.identifier == "com.farhantamzid.zentri.backup")
    #expect(UTType.zentriBackup.preferredFilenameExtension == "zentri.json")
    #expect(UTType.zentriBackup.conforms(to: .json))
    // Both a manual export and an automatic snapshot can be picked for import.
    #expect(BackupFileDocument.readableContentTypes.contains(.zentriBackup))
    #expect(BackupFileDocument.readableContentTypes.contains(.json))
}
