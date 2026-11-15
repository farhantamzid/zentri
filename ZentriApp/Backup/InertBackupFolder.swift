import Foundation
import ZentriCore

/// A backup folder that is never chosen, for `-UITestMode`.
///
/// It reads no bookmark and touches no file: choosing a folder is refused, and everything else
/// reports that no folder is selected.
struct InertBackupFolder: BackupFolderAccessing {
    var hasFolder: Bool { false }

    func chooseFolder(_ url: URL) throws {
        throw BackupFolderError.permissionDenied
    }

    func forgetFolder() {}

    func resolveFolder() throws -> URL {
        throw BackupFolderError.noFolderSelected
    }

    func write(_ data: Data) throws -> URL {
        throw BackupFolderError.noFolderSelected
    }

    func listSnapshots() throws -> [SnapshotInfo] {
        throw BackupFolderError.noFolderSelected
    }

    func readSnapshot(at url: URL) throws -> Data {
        throw BackupFolderError.noFolderSelected
    }

    func newestSnapshot() throws -> BackupDocument? {
        throw BackupFolderError.noFolderSelected
    }
}
