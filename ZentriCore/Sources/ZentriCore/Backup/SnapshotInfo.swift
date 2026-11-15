import Foundation

/// One backup file in the backup folder, as the restore browser lists it.
public struct SnapshotInfo: Identifiable, Equatable, Sendable {
    /// The file's location inside the backup folder.
    public let url: URL
    /// When the backup was made, read from the document rather than the file's dates, which a sync
    /// can change.
    public let createdAt: Date
    /// The file's size in bytes.
    public let byteCount: Int
    /// How many transactions the backup holds.
    public let transactionCount: Int

    public var id: URL { url }

    public init(url: URL, createdAt: Date, byteCount: Int, transactionCount: Int) {
        self.url = url
        self.createdAt = createdAt
        self.byteCount = byteCount
        self.transactionCount = transactionCount
    }
}
