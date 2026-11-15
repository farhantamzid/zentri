/// Where a backup waiting to be restored came from.
enum BackupRestoreSource: Equatable, Sendable {
    /// One of the backup folder's files. Restoring it lifts the folder's write hold.
    case folder
    /// A file picked anywhere else.
    case file
}
