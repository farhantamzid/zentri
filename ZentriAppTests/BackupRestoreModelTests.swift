import Foundation
import Testing
import ZentriCore
@testable import ZentriApp

private enum PickerFailure: Error {
    case cancelled
}

private enum StoreFailure: Error {
    case unwritable
}

/// A restore model over a fake folder, recording every restore it asks for.
@MainActor
private final class RestoreFixture {
    let folder: FakeBackupFolder
    var canMerge = true
    var restoreError: (any Error)?
    private(set) var restored: [(BackupDocument, ImportMode)] = []
    lazy var model = BackupRestoreModel(
        folder: folder,
        canMerge: { [unowned self] in canMerge },
        restore: { [unowned self] document, mode in
            if let restoreError { throw restoreError }
            restored.append((document, mode))
            return ImportSummary(mode: mode, created: .init(accounts: 1), skipped: .init())
        }
    )

    init(folder: FakeBackupFolder = FakeBackupFolder()) {
        self.folder = folder
    }
}

private func encoded(_ document: BackupDocument) -> Data {
    (try? BackupCodec.encode(document)) ?? Data()
}

// MARK: - The snapshot list

@MainActor
@Test func withoutAFolderTheListSaysSo() async {
    let fixture = RestoreFixture(folder: FakeBackupFolder(hasFolder: false))

    await fixture.model.loadSnapshots()

    #expect(fixture.model.snapshotsState == .noFolder)
}

@MainActor
@Test func aFolderThatCannotBeReadIsAnErrorNotAnEmptyList() async {
    let fixture = RestoreFixture()
    fixture.folder.failListing(with: .unreadable)

    await fixture.model.loadSnapshots()

    #expect(fixture.model.snapshotsState == .failed(.unreadable))
}

@MainActor
@Test func aRevokedFolderIsAPermissionError() async {
    let fixture = RestoreFixture()
    fixture.folder.failResolving(with: .permissionDenied)

    await fixture.model.loadSnapshots()

    #expect(fixture.model.snapshotsState == .failed(.permissionDenied))
}

@MainActor
@Test func listsTheFoldersBackupsNewestFirstAndSkipsBrokenOnes() async {
    let fixture = RestoreFixture()
    fixture.folder.add(encoded(makeBackupDocument(transactionCount: 1)), named: "a.json")
    fixture.folder.add(Data("{".utf8), named: "broken.json")
    fixture.folder.add(
        encoded(makeBackupDocument(transactionCount: 4, exportedAt: backupTestDate.addingTimeInterval(60))),
        named: "b.json"
    )

    await fixture.model.loadSnapshots()

    guard case .loaded(let snapshots) = fixture.model.snapshotsState else {
        Issue.record("The list did not load: \(fixture.model.snapshotsState)")
        return
    }
    #expect(snapshots.map(\.transactionCount) == [4, 1])
}

@MainActor
@Test func choosingAFolderRemembersItAndReloadsTheList() async {
    let fixture = RestoreFixture(folder: FakeBackupFolder(hasFolder: false))
    let picked = URL(filePath: "/iCloud/Zentri Backups", directoryHint: .isDirectory)

    await fixture.model.chooseFolder(.success(picked))

    #expect(fixture.folder.chosenFolders == [picked])
    #expect(fixture.model.snapshotsState == .loaded([]))
}

@MainActor
@Test func choosingAFolderToBrowseNeverWritesToIt() async throws {
    // After a reinstall: the folder holds the old phone's backups, this iPhone has fresh data.
    let folder = FakeBackupFolder(hasFolder: false)
    folder.addSnapshot(of: makeBackupDocument(transactionCount: 40, accountName: "Old phone"))
    let fixture = RestoreFixture(folder: folder)
    let scheduler = BackupScheduler(
        folder: folder,
        makeDocument: { makeBackupDocument(transactionCount: 1, accountName: "New phone") },
        didBackUp: { _ in }
    )

    await fixture.model.chooseFolder(.success(URL(filePath: "/iCloud/Zentri Backups")))
    // Then the data changes and the app goes to the background.
    scheduler.schedule()
    await scheduler.flush()

    #expect(folder.writeCount == 0)
    #expect(folder.holdsWrites)
    guard case .loaded(let snapshots) = fixture.model.snapshotsState else {
        Issue.record("The list did not load")
        return
    }
    #expect(snapshots.map(\.transactionCount) == [40])
}

@MainActor
@Test func restoringFromTheFolderLiftsItsHold() async throws {
    let folder = FakeBackupFolder(holdsWrites: true)
    let document = makeBackupDocument(transactionCount: 3)
    let url = folder.addSnapshot(of: document)
    let fixture = RestoreFixture(folder: folder)
    await fixture.model.open(SnapshotInfo(url: url, createdAt: backupTestDate, byteCount: 1, transactionCount: 3))
    let candidate = try #require(fixture.model.candidate)
    #expect(candidate.source == .folder)

    await fixture.model.restore(candidate, mode: .replace)

    #expect(folder.holdsWrites == false)
}

@MainActor
@Test func restoringAFilePickedElsewhereKeepsTheFoldersHold() async throws {
    let folder = FakeBackupFolder(holdsWrites: true)
    folder.addSnapshot(of: makeBackupDocument(transactionCount: 40))
    let fixture = RestoreFixture(folder: folder)

    await fixture.model.restore(BackupRestoreCandidate(document: makeBackupDocument(), source: .file), mode: .merge)

    #expect(fixture.restored.count == 1)
    #expect(folder.holdsWrites)
}

@MainActor
@Test func aFailedRestoreFromTheFolderKeepsItsHold() async {
    let folder = FakeBackupFolder(holdsWrites: true)
    let fixture = RestoreFixture(folder: folder)
    fixture.restoreError = StoreFailure.unwritable

    await fixture.model.restore(BackupRestoreCandidate(document: makeBackupDocument(), source: .folder), mode: .replace)

    #expect(folder.holdsWrites)
}

@MainActor
@Test func aCancelledFolderPickChangesNothing() async {
    let fixture = RestoreFixture(folder: FakeBackupFolder(hasFolder: false))

    await fixture.model.chooseFolder(.failure(PickerFailure.cancelled))

    #expect(fixture.folder.chosenFolders.isEmpty)
}

// MARK: - Opening a backup

@MainActor
@Test func openingASnapshotSummarisesItBeforeAnythingChanges() async {
    let fixture = RestoreFixture()
    let document = makeBackupDocument(transactionCount: 3)
    let url = fixture.folder.add(encoded(document), named: "a.json")
    await fixture.model.loadSnapshots()

    await fixture.model.open(SnapshotInfo(url: url, createdAt: backupTestDate, byteCount: 1, transactionCount: 3))

    let candidate = fixture.model.candidate
    #expect(candidate?.document == document)
    #expect(candidate?.accountCount == 1)
    #expect(candidate?.transactionCount == 3)
    #expect(candidate?.ruleCount == 0)
    #expect(candidate?.schemaVersion == BackupCodec.currentSchemaVersion)
    #expect(candidate?.exportDate == backupTestDate)
    #expect(fixture.restored.isEmpty)
}

@MainActor
@Test func aSnapshotThatNoLongerDecodesExplainsWhyAndRestoresNothing() async {
    let fixture = RestoreFixture()
    var unsupported = makeBackupDocument()
    unsupported.schemaVersion = 99
    let url = fixture.folder.add(encoded(unsupported), named: "future.json")

    await fixture.model.open(SnapshotInfo(url: url, createdAt: backupTestDate, byteCount: 1, transactionCount: 1))

    #expect(fixture.model.candidate == nil)
    #expect(fixture.model.failureMessage != nil)
    #expect(fixture.restored.isEmpty)
}

@MainActor
@Test func aPickedFileIsReadAndSummarised() async throws {
    let fixture = RestoreFixture(folder: FakeBackupFolder(hasFolder: false))
    let document = makeBackupDocument(transactionCount: 2)
    let url = FileManager.default.temporaryDirectory.appending(path: "Zentri-\(UUID().uuidString).zentri.json")
    try encoded(document).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    await fixture.model.openFile(.success(url))

    #expect(fixture.model.candidate?.document == document)
}

@MainActor
@Test func aTruncatedPickedFileIsRejected() async throws {
    let fixture = RestoreFixture(folder: FakeBackupFolder(hasFolder: false))
    let whole = encoded(makeBackupDocument())
    let url = FileManager.default.temporaryDirectory.appending(path: "Zentri-\(UUID().uuidString).json")
    try whole.prefix(whole.count / 2).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    await fixture.model.openFile(.success(url))

    #expect(fixture.model.candidate == nil)
    #expect(fixture.model.failureMessage != nil)
}

@MainActor
@Test func aCancelledFilePickIsSilent() async {
    let fixture = RestoreFixture()

    await fixture.model.openFile(.failure(PickerFailure.cancelled))

    #expect(fixture.model.candidate == nil)
    #expect(fixture.model.failureMessage == nil)
}

// MARK: - Restoring

@MainActor
@Test func restoringRunsTheChosenModeAndReportsTheSummary() async {
    let fixture = RestoreFixture()
    let document = makeBackupDocument()
    let candidate = BackupRestoreCandidate(document: document, source: .file)

    await fixture.model.restore(candidate, mode: .merge)

    #expect(fixture.restored.count == 1)
    #expect(fixture.restored.first?.0 == document)
    #expect(fixture.restored.first?.1 == .merge)
    #expect(fixture.model.completedSummary?.mode == .merge)
    #expect(fixture.model.candidate == nil)
}

@MainActor
@Test func aFailedRestoreReportsTheFailure() async {
    let fixture = RestoreFixture()
    fixture.restoreError = StoreFailure.unwritable

    await fixture.model.restore(BackupRestoreCandidate(document: makeBackupDocument(), source: .file), mode: .replace)

    #expect(fixture.model.failureMessage != nil)
    #expect(fixture.model.completedSummary == nil)
}

@MainActor
@Test func mergeIsOfferedOnlyWhenSettingsExist() {
    let fixture = RestoreFixture()
    #expect(fixture.model.availableModes == [.replace, .merge])

    fixture.canMerge = false
    #expect(fixture.model.availableModes == [.replace])
}
