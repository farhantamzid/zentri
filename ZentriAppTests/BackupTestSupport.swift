import Foundation
import Synchronization
import ZentriCore
@testable import ZentriApp

/// A backup folder held in memory, which a test can make fail on demand.
///
/// Writes arrive off the main actor, so the state sits behind a lock.
final class FakeBackupFolder: BackupFolderAccessing, Sendable {
    private struct State {
        var hasFolder = true
        var holdsWrites = false
        var folderName = "Zentri Backups"
        var snapshots: [URL: Data] = [:]
        var order: [URL] = []
        var writeError: BackupFolderError?
        var resolveError: BackupFolderError?
        var listError: BackupFolderError?
        var writeCount = 0
        var chosen: [URL] = []
    }

    private let state = Mutex(State())

    init(hasFolder: Bool = true, holdsWrites: Bool = false) {
        state.withLock { state in
            state.hasFolder = hasFolder
            state.holdsWrites = holdsWrites
        }
    }

    // MARK: Test controls

    var writeCount: Int { state.withLock { $0.writeCount } }
    var snapshotData: [Data] { state.withLock { state in state.order.compactMap { state.snapshots[$0] } } }
    var chosenFolders: [URL] { state.withLock { $0.chosen } }

    func failWrites(with error: BackupFolderError?) {
        state.withLock { $0.writeError = error }
    }

    func failResolving(with error: BackupFolderError?) {
        state.withLock { $0.resolveError = error }
    }

    func failListing(with error: BackupFolderError?) {
        state.withLock { $0.listError = error }
    }

    /// Puts an automatic snapshot of `document` in the folder without counting it as a write, as an
    /// earlier install of the app would have left it.
    @discardableResult
    func addSnapshot(of document: BackupDocument) -> URL {
        add((try? BackupCodec.encode(document)) ?? Data(), named: "Zentri-earlier-\(UUID().uuidString).json")
    }

    /// Puts a file in the folder without counting it as a write.
    @discardableResult
    func add(_ data: Data, named name: String) -> URL {
        let url = URL(filePath: "/Backups/\(name)")
        state.withLock { state in
            state.snapshots[url] = data
            state.order.append(url)
        }
        return url
    }

    // MARK: BackupFolderAccessing

    var hasFolder: Bool { state.withLock { $0.hasFolder } }

    var holdsWrites: Bool { state.withLock { $0.holdsWrites } }

    func releaseWriteHold() {
        state.withLock { $0.holdsWrites = false }
    }

    func chooseFolder(_ url: URL) throws {
        try state.withLock { state in
            if let error = state.resolveError { throw error }
            state.hasFolder = true
            state.holdsWrites = true
            state.folderName = url.lastPathComponent
            state.chosen.append(url)
        }
    }

    func forgetFolder() {
        state.withLock { state in
            state.hasFolder = false
            state.holdsWrites = false
        }
    }

    func resolveFolder() throws -> URL {
        try state.withLock { state in
            guard state.hasFolder else { throw BackupFolderError.noFolderSelected }
            if let error = state.resolveError { throw error }
            return URL(filePath: "/\(state.folderName)", directoryHint: .isDirectory)
        }
    }

    func write(_ data: Data) throws -> URL {
        _ = try resolveFolder()
        return try state.withLock { state in
            if let error = state.writeError { throw error }
            state.writeCount += 1
            let url = URL(filePath: "/Backups/Zentri-\(state.writeCount).json")
            state.snapshots[url] = data
            state.order.append(url)
            return url
        }
    }

    func listSnapshots() throws -> [SnapshotInfo] {
        _ = try resolveFolder()
        return try state.withLock { state in
            if let error = state.listError { throw error }
            return state.order.reversed().compactMap { url in
                guard
                    let data = state.snapshots[url],
                    let document = try? BackupCodec.decode(data),
                    let date = document.exportDate
                else { return nil }
                return SnapshotInfo(url: url, createdAt: date, byteCount: data.count, transactionCount: document.transactions.count)
            }
        }
    }

    func readSnapshot(at url: URL) throws -> Data {
        _ = try resolveFolder()
        return try state.withLock { state in
            guard let data = state.snapshots[url] else { throw BackupFolderError.unreadable }
            return data
        }
    }

    func newestSnapshot() throws -> BackupDocument? {
        _ = try resolveFolder()
        // Like the real folder, only automatic snapshots count, not files a test adds by name.
        let newest = state.withLock { state in
            state.order.last(where: { $0.lastPathComponent.hasPrefix("Zentri-") }).flatMap { state.snapshots[$0] }
        }
        return try newest.map(BackupCodec.decode)
    }
}

/// A sleep that only returns when the test says so, so a debounce can be driven step by step.
///
/// It ignores cancellation, as the scheduler must cope with a sleep that returns after it was
/// cancelled.
final class ManualSleeper: Sendable {
    private let waiters = Mutex<[CheckedContinuation<Void, Never>]>([])
    private let requested = Mutex<[Duration]>([])

    var waitingCount: Int { waiters.withLock { $0.count } }
    var requestedDurations: [Duration] { requested.withLock { $0 } }

    func sleep(for duration: Duration) async throws {
        requested.withLock { $0.append(duration) }
        await withCheckedContinuation { continuation in
            waiters.withLock { $0.append(continuation) }
        }
    }

    /// Wakes every sleeper.
    func wakeAll() {
        let woken = waiters.withLock { waiters in
            defer { waiters.removeAll() }
            return waiters
        }
        for continuation in woken {
            continuation.resume()
        }
    }
}

/// Yields until `condition` holds, failing after a generous number of turns.
@MainActor
func waitUntil(_ condition: @MainActor () -> Bool) async -> Bool {
    for _ in 0..<2_000 {
        if condition() { return true }
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(1))
    }
    return condition()
}

/// 2026-11-18 11:06 UTC.
let backupTestDate = Date(timeIntervalSince1970: 1_795_000_000 - 40)

/// A valid backup: one account named `accountName` with an opening balance and `transactionCount`
/// transactions, carrying `currencyCode`.
func makeBackupDocument(
    transactionCount: Int = 1,
    accountName: String = "Restored",
    currencyCode: String = "BDT",
    exportedAt: Date = backupTestDate
) -> BackupDocument {
    let accountID = UUID()
    let stamp = exportedAt.ISO8601Format()
    return BackupDocument(
        schemaVersion: BackupCodec.currentSchemaVersion,
        appVersion: "1.0",
        exportedAt: stamp,
        settings: BackupSettings(AppSettings(currencyCode: currencyCode, numberGrouping: .indian)),
        accounts: [
            BackupAccount(id: accountID, name: accountName, institutionName: nil, sortOrder: 0, createdAt: stamp, archivedAt: nil),
        ],
        checkpoints: [
            BackupCheckpoint(
                id: UUID(),
                accountID: accountID,
                amount: "500",
                recordedAt: stamp,
                source: .opening,
                sourceTransactionID: nil,
                createdAt: stamp,
                note: nil
            ),
        ],
        transactions: (0..<transactionCount).map { _ in
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
        },
        rawMessages: [],
        parsingRules: [],
        categories: [],
        categorizationRules: []
    )
}
