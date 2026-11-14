import Foundation
import SwiftData

/// Creates the SwiftData container shared by the app and its extensions.
public enum ZentriContainer {
    /// Creates the App Group-backed store the app uses, or an in-memory store for tests and previews.
    ///
    /// The in-memory configuration intentionally omits the group container so tests never touch
    /// shared or on-disk state.
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: ZentriSchemaV1.self)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(
                "ZentriTests",
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(
                "Zentri",
                schema: schema,
                groupContainer: .identifier(AppGroup.identifier),
                cloudKitDatabase: .none
            )
        }
        let container = try ModelContainer(
            for: schema,
            migrationPlan: ZentriMigrationPlan.self,
            configurations: configuration
        )
        if !inMemory {
            protectStoreFiles(at: configuration.url)
        }
        return container
    }

    /// Applies background-safe protection to a container's store and its SQLite sidecar files.
    ///
    /// The SQLite sidecars (`-wal`, `-shm`, `-journal`) do not exist until the first save, so a
    /// caller that writes to the store re-applies protection once those files appear.
    ///
    /// - Parameter container: The container whose store should be protected.
    public static func protectStoreFiles(for container: ModelContainer) {
        guard let storeURL = container.configurations.first?.url else { return }
        protectStoreFiles(at: storeURL)
    }

    /// Applies background-safe protection to the store and its SQLite sidecar files.
    ///
    /// Ingestion runs from a Shortcuts intent that can fire while the device is locked, so the store
    /// must stay readable after the first unlock. Protection is a hardening step: a filesystem that
    /// does not support it must not prevent the app from launching.
    static func protectStoreFiles(at storeURL: URL) {
        #if os(iOS)
        let attributes: [FileAttributeKey: Any] = [
            .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
        ]
        let storePath = storeURL.path(percentEncoded: false)
        let sidecarPaths = ["-shm", "-wal", "-journal"].map { storePath + $0 }
        for path in [storePath] + sidecarPaths where FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.setAttributes(attributes, ofItemAtPath: path)
        }
        #endif
    }
}
