import Foundation
import SwiftData
import ZentriCore

/// Builds the store, settings, model client, and widget snapshot plumbing the app and its intents
/// share, so a Shortcut capture writes to exactly what the app reads.
///
/// `-UITestMode` swaps the App Group store, the settings file, and the snapshot file for in-memory
/// or inert equivalents, so a UI test can never read or write real shared state.
enum AppComposition {
    /// The SwiftData container: the App Group store, or an in-memory one for a UI test.
    static func makeContainer() throws -> ModelContainer {
        try ZentriContainer.make(inMemory: UITestSupport.isUITestMode)
    }

    /// The settings store, already loaded: in memory for a UI test, the shared file otherwise.
    ///
    /// A document that cannot be read leaves `settings` nil and `loadFailure` set, which the app shows
    /// as recovery and a capture reports as unfinished setup.
    @MainActor
    static func makeSettingsStore() -> SettingsStore {
        let store: SettingsStore
        if UITestSupport.isUITestMode {
            store = SettingsStore(repository: InMemorySettingsRepository())
        } else {
            // The App Group is the settings home. A build that cannot reach it (a missing
            // entitlement) falls back to app-local storage so the app still launches.
            let url = SharedContainer.settingsURL
                ?? URL.applicationSupportDirectory.appending(path: AppGroup.settingsFileName)
            store = SettingsStore(repository: FileSettingsStore(fileURL: url))
        }
        try? store.load()
        return store
    }

    /// Where the widget snapshot is written; inert for a UI test.
    static func makeSnapshotStore() -> FileWidgetSnapshotStore {
        FileWidgetSnapshotStore(fileURL: UITestSupport.isUITestMode ? nil : SharedContainer.widgetSnapshotURL)
    }

    /// The on-device model.
    ///
    /// A UI test gets a model that is always unavailable, so what the tester shows does not depend on
    /// the simulator's Apple Intelligence state. A platform without Foundation Models gets the same.
    static func makeModelClient() -> any TransactionModelClient {
        #if canImport(FoundationModels)
        if !UITestSupport.isUITestMode {
            return FoundationModelsClient()
        }
        #endif
        return UnavailableModelClient()
    }

    /// The refresher that rewrites the widget snapshot from the container's main context, reading the
    /// live settings on every refresh so a currency change reaches the widgets.
    @MainActor
    static func makeSnapshotRefresher(
        container: ModelContainer,
        settingsStore: SettingsStore,
        snapshotStore: any WidgetSnapshotStore
    ) -> LiveWidgetSnapshotRefresher {
        LiveWidgetSnapshotRefresher(
            context: container.mainContext,
            store: snapshotStore,
            settings: { [weak settingsStore] in settingsStore?.settings ?? .defaultValue },
            now: { .now },
            calendar: .current
        )
    }
}
