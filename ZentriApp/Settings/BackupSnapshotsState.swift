import ZentriCore

/// How far the restore browser's read of the backup folder got.
///
/// A folder that could not be read is its own case, never an empty list, so the person is not told
/// their backups are gone.
enum BackupSnapshotsState: Equatable, Sendable {
    /// The folder is being read.
    case loading
    /// No folder is chosen on this device.
    case noFolder
    /// The folder was read; empty means it really holds no readable backups.
    case loaded([SnapshotInfo])
    /// The folder could not be resolved or read.
    case failed(BackupFolderError)
}
