import Foundation
import Testing
@testable import ZentriCore

// The folder service is exercised against a real temporary directory with a bookmark store held in
// memory, so every test sees real file-system behaviour (atomic replace, permissions, listing)
// without touching the app's defaults.

/// A bookmark store that keeps the bookmark in memory.
private final class InMemoryBookmarkStore: BackupBookmarkStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var bookmark: Data?
    private var held = false

    func loadWritesHeld() -> Bool {
        lock.withLock { held }
    }

    func saveWritesHeld(_ isHeld: Bool) {
        lock.withLock { held = isHeld }
    }

    func loadBookmark() -> Data? {
        lock.withLock { bookmark }
    }

    func saveBookmark(_ data: Data) {
        lock.withLock { bookmark = data }
    }

    func removeBookmark() {
        lock.withLock { bookmark = nil }
    }
}

/// A clock a test moves forward by hand.
private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date) {
        current = start
    }

    var now: Date {
        lock.withLock { current }
    }

    func advance(minutes: Int) {
        lock.withLock { current = current.addingTimeInterval(TimeInterval(minutes * 60)) }
    }
}

/// 2026-11-18 11:06 UTC, a whole minute so snapshot names are predictable.
private let start = Date(timeIntervalSince1970: 1_795_000_000 - 40)

/// A fresh, empty directory that is removed when the test's scope ends.
private struct TemporaryFolder: ~Copyable {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appending(path: "BackupFolderServiceTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        // A test may have made the folder read-only; give write access back so it can be removed.
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        try? FileManager.default.removeItem(at: url)
    }
}

/// A valid backup document with one account and `transactionCount` transactions on it.
private func document(transactionCount: Int, exportedAt: Date) -> BackupDocument {
    let accountID = UUID()
    let stamp = BackupCodec.dateText(exportedAt)
    let transactions = (0..<transactionCount).map { _ in
        BackupTransaction(
            id: UUID(),
            accountID: accountID,
            amount: "12.5",
            direction: .debit,
            occurredAt: stamp,
            recordedAt: stamp,
            merchantRaw: "KFC",
            merchantDisplay: "KFC",
            categoryID: nil,
            categorySource: nil,
            balanceAfter: nil,
            rawMessageID: nil,
            parseEngine: nil,
            matchedRuleID: nil,
            isTransfer: false,
            note: nil,
            createdAt: stamp,
            updatedAt: stamp
        )
    }
    return BackupDocument(
        schemaVersion: BackupCodec.currentSchemaVersion,
        appVersion: "1.0",
        exportedAt: stamp,
        settings: BackupSettings(AppSettings.defaultValue),
        accounts: [
            BackupAccount(
                id: accountID,
                name: "Everyday",
                institutionName: nil,
                sortOrder: 0,
                createdAt: stamp,
                archivedAt: nil
            ),
        ],
        checkpoints: [
            BackupCheckpoint(
                id: UUID(),
                accountID: accountID,
                amount: "100",
                recordedAt: stamp,
                source: .opening,
                sourceTransactionID: nil,
                createdAt: stamp,
                note: nil
            ),
        ],
        transactions: transactions,
        rawMessages: [],
        parsingRules: [],
        categories: [],
        categorizationRules: []
    )
}

/// The encoded bytes of ``document(transactionCount:exportedAt:)``.
private func snapshotData(transactionCount: Int, exportedAt: Date) throws -> Data {
    try BackupCodec.encode(document(transactionCount: transactionCount, exportedAt: exportedAt))
}

/// A service over `folder` that has already been pointed at it.
private func makeService(
    in folder: borrowing TemporaryFolder,
    clock: TestClock,
    bookmarks: InMemoryBookmarkStore = InMemoryBookmarkStore()
) throws -> BackupFolderService {
    let service = BackupFolderService(bookmarkStore: bookmarks, fileManager: .default, now: { clock.now })
    try service.chooseFolder(folder.url)
    return service
}

/// The names of the files in `folder`, sorted.
private func fileNames(in folder: borrowing TemporaryFolder) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: folder.url.path).sorted()
}

// MARK: - Choosing and resolving

@Test func aNewServiceHasNoFolderAndRefusesToWrite() throws {
    let service = BackupFolderService(bookmarkStore: InMemoryBookmarkStore(), fileManager: .default, now: { start })

    #expect(service.hasFolder == false)
    #expect(throws: BackupFolderError.noFolderSelected) { try service.resolveFolder() }
    #expect(throws: BackupFolderError.noFolderSelected) { try service.write(Data("{}".utf8)) }
    #expect(throws: BackupFolderError.noFolderSelected) { try service.listSnapshots() }
}

@Test func choosingAFolderStoresABookmarkThatResolvesToIt() throws {
    let folder = try TemporaryFolder()
    let bookmarks = InMemoryBookmarkStore()
    let service = try makeService(in: folder, clock: TestClock(start), bookmarks: bookmarks)

    #expect(service.hasFolder)
    #expect(bookmarks.loadBookmark() != nil)
    #expect(try service.resolveFolder().standardizedFileURL.resolvingSymlinksInPath()
        == folder.url.standardizedFileURL.resolvingSymlinksInPath())
}

@Test func forgettingTheFolderRemovesTheBookmarkButNoFiles() throws {
    let folder = try TemporaryFolder()
    let bookmarks = InMemoryBookmarkStore()
    let service = try makeService(in: folder, clock: TestClock(start), bookmarks: bookmarks)
    _ = try service.write(snapshotData(transactionCount: 1, exportedAt: start))

    service.forgetFolder()

    #expect(service.hasFolder == false)
    #expect(bookmarks.loadBookmark() == nil)
    #expect(try fileNames(in: folder).count == 1)
}

@Test func anUnresolvableBookmarkIsAPermissionErrorAndLeavesSnapshotsInPlace() throws {
    let folder = try TemporaryFolder()
    let bookmarks = InMemoryBookmarkStore()
    let clock = TestClock(start)
    let service = try makeService(in: folder, clock: clock, bookmarks: bookmarks)
    _ = try service.write(snapshotData(transactionCount: 1, exportedAt: clock.now))
    clock.advance(minutes: 1)
    _ = try service.write(snapshotData(transactionCount: 2, exportedAt: clock.now))
    let before = try fileNames(in: folder)

    // A bookmark the system can no longer resolve: the folder's permission is gone.
    bookmarks.saveBookmark(Data("not a bookmark".utf8))
    clock.advance(minutes: 1)

    #expect(throws: BackupFolderError.permissionDenied) { try service.resolveFolder() }
    #expect(throws: BackupFolderError.permissionDenied) { try service.write(Data("{}".utf8)) }
    #expect(throws: BackupFolderError.permissionDenied) { try service.listSnapshots() }
    #expect(try fileNames(in: folder) == before)
    // The bookmark is kept, so the status can say "choose the folder again" rather than "no folder".
    #expect(service.hasFolder)
}

@Test func aMovedFolderStillResolvesAndItsBookmarkIsRecreated() throws {
    let parent = try TemporaryFolder()
    let original = parent.url.appending(path: "Zentri Backups", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: original, withIntermediateDirectories: false)
    let bookmarks = InMemoryBookmarkStore()
    let service = BackupFolderService(bookmarkStore: bookmarks, fileManager: .default, now: { start })
    try service.chooseFolder(original)
    let firstBookmark = bookmarks.loadBookmark()

    let moved = parent.url.appending(path: "Renamed Backups", directoryHint: .isDirectory)
    try FileManager.default.moveItem(at: original, to: moved)

    let resolved = try service.resolveFolder()
    #expect(resolved.lastPathComponent == "Renamed Backups")
    #expect(bookmarks.loadBookmark() != firstBookmark)
    _ = try service.write(snapshotData(transactionCount: 1, exportedAt: start))
    #expect(try FileManager.default.contentsOfDirectory(atPath: moved.path).count == 1)
}

// MARK: - Holding writes to a newly chosen folder

@Test func choosingAFolderHoldsAutomaticWritesUntilReleased() throws {
    let folder = try TemporaryFolder()
    let bookmarks = InMemoryBookmarkStore()
    let service = try makeService(in: folder, clock: TestClock(start), bookmarks: bookmarks)

    #expect(service.holdsWrites)
    // The hold is stored with the bookmark, so a new service — a relaunch — still sees it.
    let relaunched = BackupFolderService(bookmarkStore: bookmarks, fileManager: .default, now: { start })
    #expect(relaunched.holdsWrites)

    relaunched.releaseWriteHold()
    #expect(service.holdsWrites == false)
}

@Test func forgettingTheFolderClearsTheHold() throws {
    let folder = try TemporaryFolder()
    let service = try makeService(in: folder, clock: TestClock(start))

    service.forgetFolder()

    #expect(service.holdsWrites == false)
}

@Test func reCreatingAStaleBookmarkDoesNotHoldWritesAgain() throws {
    let parent = try TemporaryFolder()
    let original = parent.url.appending(path: "Zentri Backups", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: original, withIntermediateDirectories: false)
    let service = BackupFolderService(bookmarkStore: InMemoryBookmarkStore(), fileManager: .default, now: { start })
    try service.chooseFolder(original)
    service.releaseWriteHold()
    try FileManager.default.moveItem(at: original, to: parent.url.appending(path: "Moved", directoryHint: .isDirectory))

    _ = try service.resolveFolder()

    #expect(service.holdsWrites == false)
}

// MARK: - Writing and rotation

@Test func writesASnapshotNamedForTheMinuteInUTC() throws {
    let folder = try TemporaryFolder()
    let service = try makeService(in: folder, clock: TestClock(start))

    let url = try service.write(snapshotData(transactionCount: 3, exportedAt: start))

    #expect(url.lastPathComponent == "Zentri-2026-11-18-1106.json")
    #expect(try fileNames(in: folder) == ["Zentri-2026-11-18-1106.json"])
    #expect(try BackupCodec.decode(Data(contentsOf: url)).transactions.count == 3)
}

@Test func keepsOnlyTheNewestTenSnapshots() throws {
    let folder = try TemporaryFolder()
    let clock = TestClock(start)
    let service = try makeService(in: folder, clock: clock)

    var written: [String] = []
    for index in 0..<12 {
        let url = try service.write(snapshotData(transactionCount: index, exportedAt: clock.now))
        written.append(url.lastPathComponent)
        clock.advance(minutes: 1)
    }

    #expect(try fileNames(in: folder) == Array(written.suffix(10)).sorted())
}

@Test func rotationNeverDeletesFilesThatAreNotSnapshots() throws {
    let folder = try TemporaryFolder()
    let clock = TestClock(start)
    let service = try makeService(in: folder, clock: clock)
    let manualExport = folder.url.appending(path: "Zentri-2020-01-01-0000.zentri.json")
    let notes = folder.url.appending(path: "notes.txt")
    try snapshotData(transactionCount: 1, exportedAt: start).write(to: manualExport)
    try Data("keep me".utf8).write(to: notes)

    for _ in 0..<11 {
        _ = try service.write(snapshotData(transactionCount: 1, exportedAt: clock.now))
        clock.advance(minutes: 1)
    }

    let names = try fileNames(in: folder)
    #expect(names.contains(manualExport.lastPathComponent))
    #expect(names.contains(notes.lastPathComponent))
    #expect(names.count(where: { $0.hasSuffix(".json") && $0 != manualExport.lastPathComponent }) == 10)
}

@Test func rotationNeverDeletesTheSnapshotItJustWrote() throws {
    let folder = try TemporaryFolder()
    let clock = TestClock(start)
    let service = try makeService(in: folder, clock: clock)
    // Ten snapshots that claim to come from the future, as after a clock change.
    for minute in 0..<10 {
        let name = "Zentri-2030-01-01-000\(minute).json"
        try snapshotData(transactionCount: 1, exportedAt: start).write(to: folder.url.appending(path: name))
    }

    let url = try service.write(snapshotData(transactionCount: 1, exportedAt: start))

    // The new snapshot sorts oldest by name, so rotation keeps it and all ten others for now.
    #expect(FileManager.default.fileExists(atPath: url.path))
    #expect(try fileNames(in: folder).count == 11)
}

@Test func aSecondSnapshotInTheSameMinuteReplacesTheFirst() throws {
    let folder = try TemporaryFolder()
    let service = try makeService(in: folder, clock: TestClock(start))

    _ = try service.write(snapshotData(transactionCount: 1, exportedAt: start))
    let url = try service.write(snapshotData(transactionCount: 4, exportedAt: start))

    #expect(try fileNames(in: folder) == [url.lastPathComponent])
    #expect(try BackupCodec.decode(Data(contentsOf: url)).transactions.count == 4)
}

@Test func writingToAReadOnlyFolderThrowsAndKeepsThePreviousSnapshot() throws {
    let folder = try TemporaryFolder()
    let clock = TestClock(start)
    let service = try makeService(in: folder, clock: clock)
    let previous = try service.write(snapshotData(transactionCount: 2, exportedAt: clock.now))
    let previousBytes = try Data(contentsOf: previous)
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.url.path)

    // Same minute: the write would replace the previous file if it could.
    #expect(throws: BackupFolderError.permissionDenied) {
        try service.write(snapshotData(transactionCount: 9, exportedAt: clock.now))
    }
    clock.advance(minutes: 1)
    #expect(throws: BackupFolderError.permissionDenied) {
        try service.write(snapshotData(transactionCount: 9, exportedAt: clock.now))
    }

    #expect(try fileNames(in: folder) == [previous.lastPathComponent])
    #expect(try Data(contentsOf: previous) == previousBytes)
}

// MARK: - Listing and reading

@Test func listsSnapshotsNewestFirstWithTheirCounts() throws {
    let folder = try TemporaryFolder()
    let clock = TestClock(start)
    let service = try makeService(in: folder, clock: clock)
    var sizes: [Int] = []
    for count in [1, 5, 3] {
        let data = try snapshotData(transactionCount: count, exportedAt: clock.now)
        sizes.append(data.count)
        _ = try service.write(data)
        clock.advance(minutes: 1)
    }

    let snapshots = try service.listSnapshots()

    #expect(snapshots.map(\.transactionCount) == [3, 5, 1])
    #expect(snapshots.map(\.byteCount) == sizes.reversed())
    #expect(snapshots.map(\.createdAt) == [
        start.addingTimeInterval(120),
        start.addingTimeInterval(60),
        start,
    ])
    #expect(snapshots.first?.url.lastPathComponent == "Zentri-2026-11-18-1108.json")
}

@Test func theListSkipsCorruptTruncatedAndForeignFiles() throws {
    let folder = try TemporaryFolder()
    let clock = TestClock(start)
    let service = try makeService(in: folder, clock: clock)
    _ = try service.write(snapshotData(transactionCount: 2, exportedAt: clock.now))
    let whole = try snapshotData(transactionCount: 2, exportedAt: clock.now)
    try whole.prefix(whole.count / 2).write(to: folder.url.appending(path: "Zentri-2026-11-18-1200.json"))
    try Data("{\"hello\": \"world\"}".utf8).write(to: folder.url.appending(path: "other.json"))
    try Data([0xFF, 0x00, 0x13]).write(to: folder.url.appending(path: "Zentri-2026-11-18-1300.json"))

    let snapshots = try service.listSnapshots()

    #expect(snapshots.count == 1)
    #expect(snapshots.first?.transactionCount == 2)
}

@Test func theListIncludesManualExportsInTheFolder() throws {
    let folder = try TemporaryFolder()
    let service = try makeService(in: folder, clock: TestClock(start))
    let export = folder.url.appending(path: "Zentri-2026-11-18-1106.zentri.json")
    try snapshotData(transactionCount: 7, exportedAt: start).write(to: export)

    let snapshots = try service.listSnapshots()

    #expect(snapshots.map(\.transactionCount) == [7])
    #expect(snapshots.first?.url.lastPathComponent == export.lastPathComponent)
}

@Test func anUnreadableFolderIsAnErrorNotAnEmptyList() throws {
    let folder = try TemporaryFolder()
    let service = try makeService(in: folder, clock: TestClock(start))
    _ = try service.write(snapshotData(transactionCount: 1, exportedAt: start))
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: folder.url.path)

    #expect(throws: BackupFolderError.unreadable) { try service.listSnapshots() }
}

@Test func readsASnapshotsBytesBack() throws {
    let folder = try TemporaryFolder()
    let service = try makeService(in: folder, clock: TestClock(start))
    let data = try snapshotData(transactionCount: 2, exportedAt: start)
    let url = try service.write(data)

    #expect(try service.readSnapshot(at: url) == data)
}

@Test func theNewestSnapshotIsTheLatestByName() throws {
    let folder = try TemporaryFolder()
    let clock = TestClock(start)
    let service = try makeService(in: folder, clock: clock)
    #expect(try service.newestSnapshot() == nil)

    _ = try service.write(snapshotData(transactionCount: 1, exportedAt: clock.now))
    clock.advance(minutes: 1)
    _ = try service.write(snapshotData(transactionCount: 6, exportedAt: clock.now))

    #expect(try service.newestSnapshot()?.transactions.count == 6)
}

// MARK: - Names

@Test func snapshotNamesAreRecognisedAndOrderedByTime() {
    #expect(BackupFileName.isSnapshot("Zentri-2026-11-18-1106.json"))
    #expect(BackupFileName.isSnapshot("Zentri-2026-11-18-1106.zentri.json") == false)
    #expect(BackupFileName.isSnapshot("Zentri-2026-11-18.json") == false)
    #expect(BackupFileName.isSnapshot("notes.json") == false)
    #expect(BackupFileName.snapshot(at: start) == "Zentri-2026-11-18-1106.json")
}

@Test func exportNamesUseTheGivenTimeZoneAndCarryNoExtension() throws {
    let dhaka = try #require(TimeZone(identifier: "Asia/Dhaka"))
    #expect(BackupFileName.exportStem(at: start, timeZone: dhaka) == "Zentri-2026-11-18-1706")
}

// MARK: - Comparing content

@Test func documentsThatDifferOnlyInWhenTheyWereWrittenHaveTheSameContent() {
    let first = document(transactionCount: 2, exportedAt: start)
    var second = first
    second.exportedAt = BackupCodec.dateText(start.addingTimeInterval(600))
    second.appVersion = "2.0"
    second.settings.lastBackupAt = BackupCodec.dateText(start)

    #expect(first.hasSameContent(as: second))

    var changed = second
    changed.settings.currencyCode = "BDT"
    #expect(first.hasSameContent(as: changed) == false)
    #expect(first.hasSameContent(as: document(transactionCount: 2, exportedAt: start)) == false)
}

// MARK: - Summaries and outside files

@Test func aDocumentReportsWhenItWasMadeAndTheSpanOfItsTransactions() throws {
    var made = document(transactionCount: 3, exportedAt: start)
    made.transactions[0].occurredAt = BackupCodec.dateText(start.addingTimeInterval(-86_400))
    made.transactions[2].occurredAt = BackupCodec.dateText(start.addingTimeInterval(3_600))

    #expect(made.exportDate == start)
    #expect(made.transactionDateRange == start.addingTimeInterval(-86_400)...start.addingTimeInterval(3_600))
    #expect(document(transactionCount: 0, exportedAt: start).transactionDateRange == nil)
}

@Test func readsAFileOutsideTheBackupFolder() throws {
    let folder = try TemporaryFolder()
    let url = folder.url.appending(path: "Zentri-2026-11-18-1106.zentri.json")
    let data = try snapshotData(transactionCount: 1, exportedAt: start)
    try data.write(to: url)

    #expect(try BackupFileReader.read(at: url) == data)
    #expect(throws: BackupFolderError.unreadable) {
        try BackupFileReader.read(at: folder.url.appending(path: "missing.json"))
    }
}
