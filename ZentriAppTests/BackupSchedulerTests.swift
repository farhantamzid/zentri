import Foundation
import Testing
import ZentriCore
@testable import ZentriApp

/// A scheduler over a fake folder and a hand-driven sleep, recording what it backs up.
@MainActor
private final class SchedulerFixture {
    let folder: FakeBackupFolder
    let sleeper = ManualSleeper()
    var document: BackupDocument? = makeBackupDocument()
    var exportError: (any Error)?
    private(set) var exportCount = 0
    private(set) var backedUpAt: [Date] = []
    var now = backupTestDate
    lazy var scheduler = BackupScheduler(
        folder: folder,
        makeDocument: { [unowned self] in
            exportCount += 1
            if let exportError { throw exportError }
            return document
        },
        didBackUp: { [unowned self] date in backedUpAt.append(date) },
        now: { [unowned self] in now },
        sleep: { [sleeper] duration in try await sleeper.sleep(for: duration) }
    )

    init(folder: FakeBackupFolder = FakeBackupFolder()) {
        self.folder = folder
    }
}

private enum ExportFailure: Error {
    case storeUnreadable
}

@MainActor
@Test func burstsOfChangesBecomeOneBackupAfterTwoSeconds() async throws {
    let fixture = SchedulerFixture()

    fixture.scheduler.schedule()
    fixture.scheduler.schedule()
    fixture.scheduler.schedule()
    #expect(await waitUntil { fixture.sleeper.waitingCount == 3 })
    #expect(fixture.sleeper.requestedDurations == [.seconds(2), .seconds(2), .seconds(2)])
    #expect(fixture.folder.writeCount == 0)

    fixture.sleeper.wakeAll()

    #expect(await waitUntil { fixture.folder.writeCount == 1 && fixture.scheduler.status == .succeeded })
    // The earlier, cancelled debounces must not write once they wake.
    try await Task.sleep(for: .milliseconds(50))
    #expect(fixture.folder.writeCount == 1)
    #expect(fixture.exportCount == 1)
    #expect(fixture.backedUpAt == [backupTestDate])
    let written = try #require(fixture.folder.snapshotData.last)
    #expect(try BackupCodec.decode(written) == fixture.document)
}

@MainActor
@Test func flushWritesAPendingChangeAtOnce() async throws {
    let fixture = SchedulerFixture()
    fixture.scheduler.schedule()

    await fixture.scheduler.flush()

    #expect(fixture.folder.writeCount == 1)
    // The debounce that was waiting is cancelled and writes nothing more when it wakes.
    #expect(await waitUntil { fixture.sleeper.waitingCount == 1 })
    fixture.sleeper.wakeAll()
    try await Task.sleep(for: .milliseconds(50))
    #expect(fixture.folder.writeCount == 1)
}

@MainActor
@Test func flushWithNothingPendingDoesNothing() async {
    let fixture = SchedulerFixture()

    await fixture.scheduler.flush()

    #expect(fixture.exportCount == 0)
    #expect(fixture.folder.writeCount == 0)
    #expect(fixture.scheduler.status == .idle)
}

@MainActor
@Test func cancelDropsAPendingBackup() async throws {
    let fixture = SchedulerFixture()
    fixture.scheduler.schedule()
    #expect(await waitUntil { fixture.sleeper.waitingCount == 1 })

    fixture.scheduler.cancel()
    fixture.sleeper.wakeAll()
    try await Task.sleep(for: .milliseconds(50))
    await fixture.scheduler.flush()

    #expect(fixture.exportCount == 0)
    #expect(fixture.folder.writeCount == 0)
}

@MainActor
@Test func withoutAFolderNothingIsExportedOrWritten() async {
    let fixture = SchedulerFixture(folder: FakeBackupFolder(hasFolder: false))
    fixture.scheduler.schedule()

    await fixture.scheduler.flush()

    #expect(fixture.exportCount == 0)
    #expect(fixture.folder.writeCount == 0)
    #expect(fixture.scheduler.status == .idle)
}

@MainActor
@Test func withoutSettingsNothingIsWritten() async {
    let fixture = SchedulerFixture()
    fixture.document = nil
    fixture.scheduler.schedule()

    await fixture.scheduler.flush()

    #expect(fixture.folder.writeCount == 0)
    #expect(fixture.backedUpAt.isEmpty)
}

@MainActor
@Test func unchangedDataIsNotWrittenAgain() async throws {
    let fixture = SchedulerFixture()
    fixture.scheduler.schedule()
    await fixture.scheduler.flush()
    #expect(fixture.folder.writeCount == 1)

    // A later export of the same data differs only in when it was made and the last-backup time.
    var again = try #require(fixture.document)
    again.exportedAt = backupTestDate.addingTimeInterval(600).ISO8601Format()
    again.settings.lastBackupAt = backupTestDate.ISO8601Format()
    fixture.document = again
    fixture.scheduler.schedule()
    await fixture.scheduler.flush()

    #expect(fixture.folder.writeCount == 1)
    #expect(fixture.scheduler.status == .succeeded)
    #expect(fixture.backedUpAt.count == 1)
}

@MainActor
@Test func changedDataIsWrittenEvenAfterARestart() async {
    // A capture the Shortcut made while the app was not running: the folder's newest snapshot
    // predates it, and the new scheduler has no memory of earlier writes.
    let folder = FakeBackupFolder()
    folder.add((try? BackupCodec.encode(makeBackupDocument(transactionCount: 1))) ?? Data(), named: "old.json")
    let fixture = SchedulerFixture(folder: folder)
    fixture.document = makeBackupDocument(transactionCount: 2)
    fixture.scheduler.schedule()

    await fixture.scheduler.flush()

    #expect(folder.writeCount == 1)
}

@MainActor
@Test func aFailedWriteKeepsThePreviousSnapshotReportsItAndRetriesLater() async throws {
    let fixture = SchedulerFixture()
    fixture.scheduler.schedule()
    await fixture.scheduler.flush()
    let previous = fixture.folder.snapshotData

    fixture.document = makeBackupDocument(transactionCount: 5)
    fixture.folder.failWrites(with: .insufficientSpace)
    fixture.scheduler.schedule()
    await fixture.scheduler.flush()

    #expect(fixture.scheduler.status == .failed(.insufficientSpace))
    #expect(fixture.folder.snapshotData == previous)
    #expect(fixture.backedUpAt.count == 1)

    // The change is still pending, so the next flush — such as going to the background — retries.
    fixture.folder.failWrites(with: nil)
    await fixture.scheduler.flush()

    #expect(fixture.scheduler.status == .succeeded)
    #expect(fixture.folder.writeCount == 2)
}

@MainActor
@Test func aRevokedFolderIsReportedAsPermissionDenied() async {
    let fixture = SchedulerFixture()
    fixture.folder.failResolving(with: .permissionDenied)
    fixture.scheduler.schedule()

    await fixture.scheduler.flush()

    #expect(fixture.scheduler.status == .failed(.permissionDenied))
    #expect(fixture.folder.writeCount == 0)
}

@MainActor
@Test func anExportThatThrowsIsReportedAndWritesNothing() async {
    let fixture = SchedulerFixture()
    fixture.exportError = ExportFailure.storeUnreadable
    fixture.scheduler.schedule()

    await fixture.scheduler.flush()

    #expect(fixture.scheduler.status == .failed(.writeFailed))
    #expect(fixture.folder.writeCount == 0)
}

@MainActor
@Test func overlappingFlushesWriteOneAtATime() async {
    let fixture = SchedulerFixture()
    fixture.scheduler.schedule()

    async let first: Void = fixture.scheduler.flush()
    async let second: Void = fixture.scheduler.flush()
    _ = await (first, second)

    #expect(fixture.folder.writeCount == 1)
}
