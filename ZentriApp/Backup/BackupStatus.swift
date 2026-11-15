import ZentriCore

/// How the automatic backup last went, for the Backup screen's status.
enum BackupStatus: Equatable, Sendable {
    /// Nothing has run since launch.
    case idle
    /// A snapshot is being written.
    case backingUp
    /// The folder holds a snapshot of the current data.
    case succeeded
    /// The last attempt failed; the previous snapshot is untouched.
    case failed(BackupFolderError)
}
