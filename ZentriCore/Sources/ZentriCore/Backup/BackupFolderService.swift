import Foundation

/// Reads and writes backup snapshots in the folder the person chose, such as `iCloud Drive/Zentri
/// Backups`.
///
/// The folder is remembered as a bookmark in ``BackupBookmarkStoring`` and resolved on every use.
/// On iOS a bookmark made from a URL the document picker handed over carries its security scope with
/// it (the `withSecurityScope` options exist only on macOS), so each operation resolves the
/// bookmark, calls `startAccessingSecurityScopedResource()`, and stops again when it returns. A
/// stale bookmark is re-created from the resolved URL; one that no longer resolves is
/// ``BackupFolderError/permissionDenied``, and the person is asked to choose the folder again.
///
/// Snapshots are written through `NSFileCoordinator` with an atomic replace, so the file provider
/// never sees a half-written file and a failed write leaves the previous file as it was. Only after a
/// write succeeds are the oldest automatic snapshots beyond ``snapshotLimit`` deleted; files that are
/// not automatic snapshots — a manual export the person dropped in, anything else — are never
/// deleted. The service never creates a directory: snapshots go straight into the chosen folder.
///
/// Every method does blocking file I/O, so the app calls them off the main actor.
public struct BackupFolderService: Sendable {
    /// How many automatic snapshots the folder keeps.
    public static let snapshotLimit = 10

    private let bookmarkStore: any BackupBookmarkStoring
    /// `FileManager` is not marked `Sendable`, but its methods are documented as safe to call from
    /// any thread when, as here, no delegate is set.
    nonisolated(unsafe) private let fileManager: FileManager
    private let now: @Sendable () -> Date

    /// - Parameters:
    ///   - bookmarkStore: Where the folder's bookmark is kept.
    ///   - fileManager: The file manager to use.
    ///   - now: The clock that names new snapshots.
    public init(
        bookmarkStore: any BackupBookmarkStoring,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.bookmarkStore = bookmarkStore
        self.fileManager = fileManager
        self.now = now
    }

    /// Whether a folder has been chosen on this device. It may still fail to resolve.
    public var hasFolder: Bool {
        bookmarkStore.loadBookmark() != nil
    }

    /// Remembers `url`, a folder the document picker returned, as the backup folder.
    ///
    /// - Throws: ``BackupFolderError/permissionDenied`` when no bookmark can be made for it.
    public func chooseFolder(_ url: URL) throws {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            bookmarkStore.saveBookmark(bookmark)
        } catch {
            throw BackupFolderError.permissionDenied
        }
    }

    /// Forgets the folder. Its files are left where they are.
    public func forgetFolder() {
        bookmarkStore.removeBookmark()
    }

    /// The chosen folder, re-creating its bookmark when the system reports it stale.
    ///
    /// - Throws: ``BackupFolderError/noFolderSelected`` before a folder is chosen, or
    ///   ``BackupFolderError/permissionDenied`` when the bookmark no longer resolves.
    public func resolveFolder() throws -> URL {
        guard let bookmark = bookmarkStore.loadBookmark() else {
            throw BackupFolderError.noFolderSelected
        }
        var isStale = false
        let url: URL
        do {
            url = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
        } catch {
            throw BackupFolderError.permissionDenied
        }
        if isStale {
            try chooseFolder(url)
        }
        return url
    }

    /// Writes a snapshot named for the current minute, then deletes the oldest automatic snapshots
    /// beyond ``snapshotLimit``.
    ///
    /// A second snapshot in the same minute atomically replaces the first.
    ///
    /// - Parameter data: The encoded backup document.
    /// - Returns: Where the snapshot was written.
    /// - Throws: A ``BackupFolderError``; the folder's existing files are then unchanged.
    public func write(_ data: Data) throws -> URL {
        try withFolderAccess { folder in
            let target = folder.appending(path: BackupFileName.snapshot(at: now()), directoryHint: .notDirectory)
            try coordinatedWrite(data, to: target)
            rotate(in: folder, keeping: target)
            return target
        }
    }

    /// Every backup in the folder that decodes, newest first.
    ///
    /// Automatic snapshots and manual exports (`.zentri.json`) are both listed. A file that is
    /// truncated, corrupt, from an unsupported version, or not a backup at all is skipped.
    ///
    /// - Throws: ``BackupFolderError/unreadable`` when the folder itself cannot be listed, which is
    ///   never reported as an empty folder.
    public func listSnapshots() throws -> [SnapshotInfo] {
        try withFolderAccess { folder in
            let snapshots = try jsonFiles(in: folder).compactMap { url -> SnapshotInfo? in
                guard
                    let data = try? coordinatedRead(url),
                    let document = try? BackupCodec.decode(data),
                    let createdAt = try? BackupCodec.date(from: document.exportedAt, field: "exportedAt")
                else { return nil }
                return SnapshotInfo(
                    url: url,
                    createdAt: createdAt,
                    byteCount: data.count,
                    transactionCount: document.transactions.count
                )
            }
            return snapshots.sorted { first, second in
                if first.createdAt != second.createdAt {
                    return first.createdAt > second.createdAt
                }
                return first.url.lastPathComponent > second.url.lastPathComponent
            }
        }
    }

    /// The bytes of a backup file in the folder.
    ///
    /// - Throws: ``BackupFolderError/unreadable`` when the file cannot be read, or a resolution error.
    public func readSnapshot(at url: URL) throws -> Data {
        try withFolderAccess { _ in
            do {
                return try coordinatedRead(url)
            } catch {
                throw BackupFolderError.unreadable
            }
        }
    }

    /// The newest automatic snapshot, decoded, or `nil` when the folder has none.
    ///
    /// - Throws: A ``BackupFolderError`` when the folder cannot be read, or a ``BackupError`` when the
    ///   newest snapshot does not decode.
    public func newestSnapshot() throws -> BackupDocument? {
        try withFolderAccess { folder in
            guard let newest = try jsonFiles(in: folder)
                .filter({ BackupFileName.isSnapshot($0.lastPathComponent) })
                .max(by: { $0.lastPathComponent < $1.lastPathComponent })
            else { return nil }
            let data: Data
            do {
                data = try coordinatedRead(newest)
            } catch {
                throw BackupFolderError.unreadable
            }
            return try BackupCodec.decode(data)
        }
    }

    // MARK: - Access

    /// Resolves the folder, opens its security scope for `body`, and closes it afterwards.
    private func withFolderAccess<Result>(_ body: (URL) throws -> Result) throws -> Result {
        let folder = try resolveFolder()
        let isAccessing = folder.startAccessingSecurityScopedResource()
        defer {
            if isAccessing { folder.stopAccessingSecurityScopedResource() }
        }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw BackupFolderError.permissionDenied
        }
        return try body(folder)
    }

    /// The `.json` files directly inside `folder`.
    private func jsonFiles(in folder: URL) throws -> [URL] {
        do {
            return try fileManager
                .contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                .filter { $0.pathExtension.lowercased() == "json" }
        } catch {
            throw BackupFolderError.unreadable
        }
    }

    // MARK: - Coordinated I/O

    /// Writes `data` to `target` as one atomic replace, coordinated with the file provider.
    private func coordinatedWrite(_ data: Data, to target: URL) throws {
        var coordinationError: NSError?
        var writeError: (any Error)?
        NSFileCoordinator(filePresenter: nil).coordinate(
            writingItemAt: target,
            options: .forReplacing,
            error: &coordinationError
        ) { url in
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if let error = writeError ?? coordinationError {
            throw Self.folderError(forWriteError: error)
        }
    }

    /// Reads `url`, coordinated with the file provider so an iCloud file is downloaded first.
    private func coordinatedRead(_ url: URL) throws -> Data {
        var coordinationError: NSError?
        var result: Result<Data, any Error> = .failure(BackupFolderError.unreadable)
        NSFileCoordinator(filePresenter: nil).coordinate(
            readingItemAt: url,
            options: [],
            error: &coordinationError
        ) { url in
            result = Result { try Data(contentsOf: url) }
        }
        if let coordinationError {
            throw coordinationError
        }
        return try result.get()
    }

    /// Deletes the oldest automatic snapshots beyond the limit, never `kept`.
    ///
    /// A deletion that fails is left for the next rotation: the new snapshot is already safe.
    private func rotate(in folder: URL, keeping kept: URL) {
        guard let files = try? jsonFiles(in: folder) else { return }
        let snapshots = files
            .filter { BackupFileName.isSnapshot($0.lastPathComponent) }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for url in snapshots.dropFirst(Self.snapshotLimit) where url.lastPathComponent != kept.lastPathComponent {
            NSFileCoordinator(filePresenter: nil).coordinate(
                writingItemAt: url,
                options: .forDeleting,
                error: nil
            ) { url in
                try? fileManager.removeItem(at: url)
            }
        }
    }

    /// The folder error a failed write stands for.
    private static func folderError(forWriteError error: any Error) -> BackupFolderError {
        let nsError = error as NSError
        let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        for candidate in [nsError, underlying].compactMap({ $0 }) {
            switch (candidate.domain, candidate.code) {
            case (NSCocoaErrorDomain, NSFileWriteOutOfSpaceError),
                 (NSPOSIXErrorDomain, Int(ENOSPC)),
                 (NSPOSIXErrorDomain, Int(EDQUOT)):
                return .insufficientSpace
            case (NSCocoaErrorDomain, NSFileWriteNoPermissionError),
                 (NSCocoaErrorDomain, NSFileWriteVolumeReadOnlyError),
                 (NSCocoaErrorDomain, NSFileNoSuchFileError),
                 (NSPOSIXErrorDomain, Int(EACCES)),
                 (NSPOSIXErrorDomain, Int(EPERM)),
                 (NSPOSIXErrorDomain, Int(EROFS)):
                return .permissionDenied
            default:
                continue
            }
        }
        return .writeFailed
    }
}
