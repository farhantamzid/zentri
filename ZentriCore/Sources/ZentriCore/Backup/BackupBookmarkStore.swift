import Foundation

/// Keeps the backup folder's bookmark in the app's own `UserDefaults`.
///
/// The app's standard defaults are app-local: the widgets never see the bookmark, and deleting the
/// app removes it, which is why the folder must be chosen again after a reinstall.
public struct BackupBookmarkStore: BackupBookmarkStoring {
    /// The defaults key the bookmark is stored under.
    public static let defaultsKey = "backupFolderBookmark"
    /// The defaults key the write hold is stored under: the bookmark key with a suffix.
    private var holdKey: String { key + ".writesHeld" }

    /// The defaults suite, or `nil` for the app's standard defaults. A name rather than a
    /// `UserDefaults` instance is stored because `UserDefaults` is not `Sendable`.
    private let suiteName: String?
    private let key: String

    /// - Parameters:
    ///   - suiteName: The defaults suite to use; the app passes `nil` for its standard defaults.
    ///   - key: The key the bookmark is stored under.
    public init(suiteName: String? = nil, key: String = Self.defaultsKey) {
        self.suiteName = suiteName
        self.key = key
    }

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    public func loadBookmark() -> Data? {
        defaults.data(forKey: key)
    }

    public func saveBookmark(_ data: Data) {
        defaults.set(data, forKey: key)
    }

    public func removeBookmark() {
        defaults.removeObject(forKey: key)
    }

    public func loadWritesHeld() -> Bool {
        defaults.bool(forKey: holdKey)
    }

    public func saveWritesHeld(_ isHeld: Bool) {
        defaults.set(isHeld, forKey: holdKey)
    }
}
