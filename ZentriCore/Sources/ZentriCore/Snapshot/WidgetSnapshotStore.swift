import Foundation

/// Reads and writes the widget snapshot document that the app and its extension share.
///
/// The protocol exists so ingestion can be given a store in tests and so a second implementation
/// (a preview store, for instance) never has to touch the App Group.
public protocol WidgetSnapshotStore: Sendable {
    /// Returns the stored snapshot, or `nil` when there is none this app can read.
    func read() -> WidgetSnapshot?
    /// Replaces the stored snapshot.
    func write(_ snapshot: WidgetSnapshot) throws
}

/// A ``WidgetSnapshotStore`` backed by one JSON file, normally the App Group's.
///
/// The file is written atomically: the document is encoded to a temporary file next to its
/// destination, protected, and only then renamed into place, so a widget reading during a write
/// never sees a half-written document. ``read()`` treats a missing, corrupt, or unsupported-version
/// file as "no snapshot", which is what makes the widgets fall back to their placeholder instead of
/// a partially decoded one.
public struct FileWidgetSnapshotStore: WidgetSnapshotStore {
    /// The snapshot file, or `nil` when the App Group is unavailable.
    private let fileURL: URL?

    /// Creates the store.
    ///
    /// - Parameter fileURL: The file to read and write, normally
    ///   ``SharedContainer/widgetSnapshotURL``. A `nil` URL makes the store inert: reads return
    ///   `nil` and writes do nothing, so a missing App Group degrades to a placeholder rather than a
    ///   crash.
    public init(fileURL: URL?) {
        self.fileURL = fileURL
    }

    public func read() -> WidgetSnapshot? {
        guard let fileURL else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return nil
        }
        guard snapshot.schemaVersion == WidgetSnapshot.currentSchemaVersion else { return nil }
        return snapshot
    }

    public func write(_ snapshot: WidgetSnapshot) throws {
        guard let fileURL else { return }
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try JSONEncoder().encode(snapshot)
        // The temporary file lives in the destination's directory so the final rename stays on one
        // volume, which is what makes it atomic.
        let temporaryURL = directory.appending(
            path: ".\(fileURL.lastPathComponent).\(UUID().uuidString).tmp"
        )
        try data.write(to: temporaryURL, options: [])
        Self.applyProtection(to: temporaryURL)
        do {
            if FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) {
                _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
    }

    /// Makes the snapshot readable while the device is locked after its first unlock.
    ///
    /// Ingestion can run from a Shortcut while the screen is locked, and the widget extension reads
    /// this file in the background. Protection is a hardening step, so a filesystem that does not
    /// support it must not fail the write.
    private static func applyProtection(to url: URL) {
        #if os(iOS)
        let attributes: [FileAttributeKey: Any] = [
            .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
        ]
        try? FileManager.default.setAttributes(attributes, ofItemAtPath: url.path(percentEncoded: false))
        #endif
    }
}
