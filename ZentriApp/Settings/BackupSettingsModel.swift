import Foundation
import Observation
import ZentriCore

/// Settings › Backup: the backup folder, the last backup's status, and manual export.
///
/// The folder is resolved off the main actor, and a folder that was chosen but no longer resolves is
/// shown as an error rather than as "no folder". The last backup's time comes from the saved
/// settings, which the scheduler updates after each snapshot; the scheduler's status adds why the
/// most recent attempt failed, if it did.
@MainActor
@Observable
final class BackupSettingsModel {
    /// The backup folder as the screen shows it.
    private(set) var folderState = BackupFolderState.loading
    /// Why the last action failed, for the screen's alert.
    var failureMessage: LocalizedStringResource?
    /// The encoded export the file exporter writes.
    private(set) var exportFile: BackupFileDocument?
    /// Whether the file exporter is showing.
    var isExporting = false
    /// The export's file name, without its extension; the exporter adds `.zentri.json`.
    private(set) var exportFilename = ""
    /// Counts finished exports, which the save haptic watches.
    private(set) var exportCount = 0

    @ObservationIgnored private let folder: any BackupFolderAccessing
    @ObservationIgnored private let settingsStore: SettingsStore
    @ObservationIgnored private let scheduler: BackupScheduler
    @ObservationIgnored private let makeExport: @MainActor () throws -> BackupDocument
    @ObservationIgnored private let onFolderChosen: @MainActor () -> Void
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let timeZone: TimeZone

    /// - Parameters:
    ///   - folder: The backup folder.
    ///   - settingsStore: The live settings, which carry the last backup's time.
    ///   - scheduler: The automatic backup, for its status and to stop it when the folder is forgotten.
    ///   - makeExport: Exports the store with the current settings.
    ///   - onFolderChosen: Told after a folder is chosen, so an automatic backup can start.
    ///   - now: The clock the export's name comes from.
    ///   - timeZone: The time zone the export's name is written in.
    init(
        folder: any BackupFolderAccessing,
        settingsStore: SettingsStore,
        scheduler: BackupScheduler,
        makeExport: @escaping @MainActor () throws -> BackupDocument,
        onFolderChosen: @escaping @MainActor () -> Void,
        now: @escaping () -> Date = { .now },
        timeZone: TimeZone = .current
    ) {
        self.folder = folder
        self.settingsStore = settingsStore
        self.scheduler = scheduler
        self.makeExport = makeExport
        self.onFolderChosen = onFolderChosen
        self.now = now
        self.timeZone = timeZone
    }

    /// When the last automatic backup was written, or `nil` if none has been.
    var lastBackupAt: Date? {
        settingsStore.settings?.lastBackupAt
    }

    /// How the most recent automatic backup went.
    var status: BackupStatus {
        scheduler.status
    }

    /// Resolves the folder again.
    func refreshFolder() async {
        guard folder.hasFolder else {
            folderState = .none
            return
        }
        let folder = folder
        do {
            let url = try await BackgroundWork.run { try folder.resolveFolder() }
            folderState = .chosen(name: url.lastPathComponent)
        } catch BackupFolderError.noFolderSelected {
            folderState = .none
        } catch let error as BackupFolderError {
            folderState = .failed(error)
        } catch {
            folderState = .failed(.permissionDenied)
        }
    }

    /// Remembers the folder the picker returned and starts a backup into it. A cancelled pick does
    /// nothing.
    func chooseFolder(_ result: Result<URL, any Error>) async {
        guard case .success(let url) = result else { return }
        let folder = folder
        do {
            try await BackgroundWork.run { try folder.chooseFolder(url) }
        } catch {
            failureMessage = BackupRestoreMessage.message(for: error)
            return
        }
        await refreshFolder()
        onFolderChosen()
    }

    /// Stops automatic backups to the folder. The backups already there are kept.
    func forgetFolder() async {
        scheduler.cancel()
        folder.forgetFolder()
        await refreshFolder()
    }

    /// Exports and encodes the store, then opens the file exporter.
    func prepareExport() async {
        do {
            let document = try makeExport()
            let data = try await BackgroundWork.run { try BackupCodec.encode(document) }
            exportFile = BackupFileDocument(data: data)
            exportFilename = BackupFileName.exportStem(at: now(), timeZone: timeZone)
            isExporting = true
        } catch {
            exportFile = nil
            failureMessage = "Zentri couldn't prepare the backup. Try again."
        }
    }

    /// Handles the exporter's result. Cancelling is not a failure.
    func finishExport(_ result: Result<URL, any Error>) {
        exportFile = nil
        switch result {
        case .success:
            exportCount += 1
        case .failure(let error):
            if (error as? CocoaError)?.code != .userCancelled {
                failureMessage = "Zentri couldn't save the backup file. Try again."
            }
        }
    }
}
