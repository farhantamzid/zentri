import Foundation
import ZentriCore

/// What the backup screens and the scheduler need from the backup folder.
///
/// ``BackupFolderService`` is the real folder; `-UITestMode` uses ``InertBackupFolder`` so a UI
/// test never touches a real bookmark or folder, and unit tests use a fake. Every method except
/// ``hasFolder`` and ``forgetFolder()`` does blocking file I/O, so callers run them through
/// ``BackgroundWork``.
protocol BackupFolderAccessing: Sendable {
    /// Whether a folder has been chosen on this device.
    var hasFolder: Bool { get }
    /// Whether automatic backups must not write to the folder yet: it was just chosen and may hold
    /// backups the person still wants. Persisted, so it survives a relaunch.
    var holdsWrites: Bool { get }
    /// Lets automatic backups write to the folder.
    func releaseWriteHold()
    /// Remembers a folder the picker returned.
    func chooseFolder(_ url: URL) throws
    /// Forgets the folder, leaving its files alone.
    func forgetFolder()
    /// The chosen folder.
    func resolveFolder() throws -> URL
    /// Writes a snapshot and rotates old ones.
    func write(_ data: Data) throws -> URL
    /// Every readable backup in the folder, newest first.
    func listSnapshots() throws -> [SnapshotInfo]
    /// One backup file's bytes.
    func readSnapshot(at url: URL) throws -> Data
    /// The newest automatic snapshot, decoded.
    func newestSnapshot() throws -> BackupDocument?
}
