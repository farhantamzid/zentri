import ZentriCore

/// The backup folder as the Backup screen shows it.
enum BackupFolderState: Equatable, Sendable {
    /// The bookmark is being resolved.
    case loading
    /// No folder is chosen on this device.
    case none
    /// The folder resolves; `name` is its last path component.
    case chosen(name: String)
    /// A folder was chosen but cannot be used now.
    case failed(BackupFolderError)
}
