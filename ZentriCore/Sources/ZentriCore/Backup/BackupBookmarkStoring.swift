import Foundation

/// Where the backup folder's bookmark is kept between launches.
///
/// The bookmark is device-specific — it names a folder the person picked on this device — so it is
/// never part of a backup document or the shared settings file.
public protocol BackupBookmarkStoring: Sendable {
    /// The stored bookmark, or `nil` when no folder has been chosen.
    func loadBookmark() -> Data?
    /// Replaces the stored bookmark.
    func saveBookmark(_ data: Data)
    /// Forgets the folder.
    func removeBookmark()
    /// Whether automatic writes to the folder are held until the person confirms (see
    /// ``BackupFolderService/holdsWrites``).
    func loadWritesHeld() -> Bool
    /// Holds or releases automatic writes to the folder.
    func saveWritesHeld(_ isHeld: Bool)
}
