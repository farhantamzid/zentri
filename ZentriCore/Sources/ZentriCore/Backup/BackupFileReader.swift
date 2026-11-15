import Foundation

/// Reads a backup file, coordinated with its file provider so an iCloud Drive file is downloaded
/// before it is read.
///
/// Used for the backup folder's snapshots and for a file the person picked anywhere else. This is
/// blocking I/O, so the app calls it off the main actor.
public enum BackupFileReader {
    /// Reads the file at `url`, opening its security scope while it does.
    ///
    /// - Throws: ``BackupFolderError/unreadable`` when the file cannot be read.
    public static func read(at url: URL) throws -> Data {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing { url.stopAccessingSecurityScopedResource() }
        }
        var coordinationError: NSError?
        var result: Result<Data, any Error> = .failure(BackupFolderError.unreadable)
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in
            result = Result { try Data(contentsOf: url) }
        }
        guard coordinationError == nil, let data = try? result.get() else {
            throw BackupFolderError.unreadable
        }
        return data
    }
}
