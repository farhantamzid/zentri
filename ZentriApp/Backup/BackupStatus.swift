import ZentriCore

/// How the automatic backup last went, for the Backup screen's status.
enum BackupStatus: Equatable, Sendable {
    /// Nothing has run since launch.
    case idle
    /// A snapshot is being written.
    case backingUp
    /// The folder holds a snapshot of the current data.
    case succeeded
    /// The folder already holds different backups, so nothing is written until the person restores
    /// from it or confirms backing this iPhone up there.
    case held
    /// The last attempt failed; the previous snapshot is untouched.
    case failed(BackupFolderError)
}
