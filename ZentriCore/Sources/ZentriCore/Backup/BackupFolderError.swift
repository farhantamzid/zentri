import Foundation

/// Why the backup folder could not be used.
///
/// Every case leaves the folder's existing snapshots as they were: a snapshot is only ever replaced
/// atomically, and older ones are deleted only after a new one has been written.
public enum BackupFolderError: Error, Equatable, Sendable {
    /// No folder has been chosen on this device.
    case noFolderSelected
    /// The folder's permission is gone — the bookmark no longer resolves, the folder was removed, or
    /// it cannot be written — so the person needs to choose it again.
    case permissionDenied
    /// The device or iCloud Drive is out of space.
    case insufficientSpace
    /// The folder could not be listed or a snapshot could not be read, for instance while iCloud
    /// Drive is unavailable.
    case unreadable
    /// The snapshot could not be written for another reason, for instance while iCloud Drive is
    /// unavailable.
    case writeFailed
}
