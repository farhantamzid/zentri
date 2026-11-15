import Foundation
import Observation
import ZentriCore

/// Finding a backup and restoring it: the folder's snapshots, a file picked anywhere, and the
/// confirmed restore.
///
/// Opening a backup reads and decodes it off the main actor and validates the whole document; only a
/// valid one becomes a ``candidate``, which the screen summarises before asking how to restore.
/// Nothing in the store changes until ``restore(_:mode:)``, which the app wires to
/// `AppState.restoreBackup(_:mode:)`.
@MainActor
@Observable
final class BackupRestoreModel {
    /// The folder's backups.
    private(set) var snapshotsState = BackupSnapshotsState.loading
    /// The backup waiting for confirmation.
    var candidate: BackupRestoreCandidate?
    /// Why the last action failed, for the screen's alert.
    var failureMessage: LocalizedStringResource?
    /// The last finished restore, which the success message and haptic watch.
    var completedSummary: ImportSummary?
    /// Whether a backup is being opened or restored.
    private(set) var isWorking = false

    @ObservationIgnored private let folder: any BackupFolderAccessing
    @ObservationIgnored private let canMerge: @MainActor () -> Bool
    @ObservationIgnored private let restoreDocument: @MainActor (BackupDocument, ImportMode) async throws -> ImportSummary
    @ObservationIgnored private let onFolderChosen: @MainActor () -> Void

    /// - Parameters:
    ///   - folder: The backup folder.
    ///   - canMerge: Whether merging is possible: it keeps the current settings, so it needs some.
    ///   - restore: Applies a document; the app passes `AppState.restoreBackup(_:mode:)`.
    ///   - onFolderChosen: Told after a folder is chosen, so an automatic backup can start.
    init(
        folder: any BackupFolderAccessing,
        canMerge: @escaping @MainActor () -> Bool,
        restore: @escaping @MainActor (BackupDocument, ImportMode) async throws -> ImportSummary,
        onFolderChosen: @escaping @MainActor () -> Void
    ) {
        self.folder = folder
        self.canMerge = canMerge
        self.restoreDocument = restore
        self.onFolderChosen = onFolderChosen
    }

    /// The restore modes on offer. Without settings (the recovery screen) only replace makes sense.
    var availableModes: [ImportMode] {
        canMerge() ? [.replace, .merge] : [.replace]
    }

    /// Reads the folder's backups again.
    func loadSnapshots() async {
        guard folder.hasFolder else {
            snapshotsState = .noFolder
            return
        }
        if case .loaded = snapshotsState {} else {
            snapshotsState = .loading
        }
        let folder = folder
        do {
            snapshotsState = .loaded(try await BackgroundWork.run { try folder.listSnapshots() })
        } catch BackupFolderError.noFolderSelected {
            snapshotsState = .noFolder
        } catch let error as BackupFolderError {
            snapshotsState = .failed(error)
        } catch {
            snapshotsState = .failed(.unreadable)
        }
    }

    /// Remembers the folder the picker returned, then lists it. A cancelled pick does nothing.
    func chooseFolder(_ result: Result<URL, any Error>) async {
        guard case .success(let url) = result else { return }
        let folder = folder
        do {
            try await BackgroundWork.run { try folder.chooseFolder(url) }
        } catch {
            failureMessage = BackupRestoreMessage.message(for: error)
            return
        }
        onFolderChosen()
        await loadSnapshots()
    }

    /// Opens one of the folder's backups for confirmation.
    func open(_ snapshot: SnapshotInfo) async {
        let folder = folder
        let url = snapshot.url
        await openDocument { try BackupCodec.decode(folder.readSnapshot(at: url)) }
    }

    /// Opens a file the person picked. A cancelled pick is silent.
    func openFile(_ result: Result<URL, any Error>) async {
        guard case .success(let url) = result else { return }
        await openDocument { try BackupCodec.decode(BackupFileReader.read(at: url)) }
    }

    /// Restores the confirmed backup.
    func restore(_ candidate: BackupRestoreCandidate, mode: ImportMode) async {
        self.candidate = nil
        isWorking = true
        defer { isWorking = false }
        do {
            completedSummary = try await restoreDocument(candidate.document, mode)
        } catch {
            failureMessage = BackupRestoreMessage.message(for: error)
        }
    }

    /// Reads and validates a document off the main actor, then offers it for confirmation.
    private func openDocument(_ read: @escaping @Sendable () throws -> BackupDocument) async {
        isWorking = true
        defer { isWorking = false }
        do {
            // `BackupCodec.decode` validates the whole document, so only a restorable one gets here.
            let document = try await BackgroundWork.run(read)
            candidate = BackupRestoreCandidate(document: document)
        } catch {
            failureMessage = BackupRestoreMessage.message(for: error)
        }
    }
}
