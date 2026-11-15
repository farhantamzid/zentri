import Foundation
import Observation
import ZentriCore

/// Writes automatic snapshots to the backup folder: two seconds after the data stops changing, and
/// at once when the app goes to the background.
///
/// ``schedule()`` marks the data as changed and restarts the debounce; ``flush()`` writes a pending
/// change now. The document is exported on the main actor (SwiftData's main context lives there);
/// comparing it with the folder's newest snapshot, encoding it, and the coordinated write all run off
/// the main actor through ``BackgroundWork``. A snapshot whose content matches the newest one in the
/// folder is not written again, so returning to the foreground — which always reloads every screen —
/// never rotates the history away with copies.
///
/// A capture the Shortcut made while the app was not running is caught up the same way: the next
/// launch or foreground reloads every screen through `AppState.mutate()`, which schedules a backup,
/// and the export then differs from the folder's newest snapshot.
///
/// Flushes run one at a time. A failure keeps the change pending, so the next flush retries, and the
/// folder service guarantees the previous snapshot is untouched.
///
/// A newly chosen folder holds writes (``BackupFolderAccessing/holdsWrites``). Every write path —
/// the debounce, the launch catch-up, the foreground reload, the background flush — goes through
/// ``flush()``, which releases the hold only when writing cannot replace anything the person may
/// want: the folder has no automatic snapshots, or its newest one already matches the current data.
/// Otherwise the status is ``BackupStatus/held`` and nothing is written until the person restores
/// from the folder or confirms with ``confirmBackingUpHere()``. The hold is stored with the
/// bookmark, so it survives a relaunch.
@MainActor
@Observable
final class BackupScheduler {
    /// How the last attempt went.
    private(set) var status = BackupStatus.idle

    @ObservationIgnored private let folder: any BackupFolderAccessing
    @ObservationIgnored private let makeDocument: @MainActor () throws -> BackupDocument?
    @ObservationIgnored private let didBackUp: @MainActor (Date) -> Void
    @ObservationIgnored private let now: @MainActor () -> Date
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void

    /// The debounce waiting to flush.
    @ObservationIgnored private var pending: Task<Void, Never>?
    /// The flush that is writing now; a later flush waits for it.
    @ObservationIgnored private var inFlight: Task<Void, Never>?
    /// Whether the data changed since the last successful backup.
    @ObservationIgnored private var hasPendingChange = false

    /// - Parameters:
    ///   - folder: Where snapshots go.
    ///   - makeDocument: Exports the store with the current settings, or returns `nil` while there
    ///     are no settings (onboarding or settings recovery), when there is nothing to back up.
    ///   - didBackUp: Told when a snapshot was written, to record the time.
    ///   - now: The clock that time comes from.
    ///   - debounce: How long the data must stay unchanged before a backup.
    ///   - sleep: How the debounce waits; a test drives it by hand.
    init(
        folder: any BackupFolderAccessing,
        makeDocument: @escaping @MainActor () throws -> BackupDocument?,
        didBackUp: @escaping @MainActor (Date) -> Void,
        now: @escaping @MainActor () -> Date = { .now },
        debounce: Duration = .seconds(2),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.folder = folder
        self.makeDocument = makeDocument
        self.didBackUp = didBackUp
        self.now = now
        self.debounce = debounce
        self.sleep = sleep
    }

    /// Notes that the data changed and backs it up once it has been still for the debounce.
    func schedule() {
        hasPendingChange = true
        pending?.cancel()
        pending = Task { [weak self, debounce, sleep] in
            try? await sleep(debounce)
            guard !Task.isCancelled else { return }
            await self?.flush()
        }
    }

    /// Backs up a pending change now, after any backup already running.
    func flush() async {
        pending?.cancel()
        pending = nil
        while let running = inFlight {
            await running.value
        }
        guard hasPendingChange else { return }
        hasPendingChange = false
        let task = Task { [weak self] in
            await self?.backUp()
            self?.inFlight = nil
        }
        inFlight = task
        await task.value
    }

    /// Backs up now, whether or not anything changed since the last backup, still honouring the
    /// folder's hold. Used right after a folder is chosen.
    func backUpNow() async {
        hasPendingChange = true
        await flush()
    }

    /// The person confirmed backing this iPhone up to a folder that already held other backups:
    /// lifts the hold and backs up. Older snapshots then rotate out as new ones are written.
    func confirmBackingUpHere() async {
        folder.releaseWriteHold()
        await backUpNow()
    }

    /// Drops a pending debounce without writing, as when the app terminates or the folder is
    /// forgotten.
    func cancel() {
        pending?.cancel()
        pending = nil
        hasPendingChange = false
    }

    // MARK: - Writing

    /// What one write attempt did.
    private enum Outcome: Sendable {
        case written
        case unchanged
        case held
        case failed(BackupFolderError)
    }

    private func backUp() async {
        guard folder.hasFolder else {
            status = .idle
            return
        }
        let document: BackupDocument
        do {
            guard let made = try makeDocument() else { return }
            document = made
        } catch {
            hasPendingChange = true
            status = .failed(.writeFailed)
            return
        }

        status = .backingUp
        let folder = folder
        let outcome = (try? await BackgroundWork.run { Self.write(document, to: folder) }) ?? .failed(.writeFailed)
        switch outcome {
        case .written:
            status = .succeeded
            didBackUp(now())
        case .unchanged:
            status = .succeeded
        case .held:
            // Still pending, so the folder is checked again on the next flush, such as after a
            // restore from it.
            hasPendingChange = true
            status = .held
        case .failed(let error):
            hasPendingChange = true
            status = .failed(error)
        }
    }

    /// Writes `document` unless the folder's newest snapshot already holds the same data, or the
    /// folder's hold forbids it.
    ///
    /// Without a hold, a newest snapshot that cannot be read is treated as different, so the backup
    /// is written. With a hold, writing needs proof that nothing would be replaced, so an unreadable
    /// folder is reported and an undecodable newest snapshot keeps the hold.
    private nonisolated static func write(_ document: BackupDocument, to folder: any BackupFolderAccessing) -> Outcome {
        if folder.holdsWrites {
            switch Result(catching: { try folder.newestSnapshot() }) {
            case .success(nil):
                folder.releaseWriteHold()
            case .success(let newest?) where newest.hasSameContent(as: document):
                folder.releaseWriteHold()
                return .unchanged
            case .success:
                return .held
            case .failure(let error as BackupFolderError):
                return .failed(error)
            case .failure:
                return .held
            }
        } else if let newest = try? folder.newestSnapshot(), newest.hasSameContent(as: document) {
            return .unchanged
        }
        do {
            _ = try folder.write(BackupCodec.encode(document))
            return .written
        } catch let error as BackupFolderError {
            return .failed(error)
        } catch {
            return .failed(.writeFailed)
        }
    }
}
