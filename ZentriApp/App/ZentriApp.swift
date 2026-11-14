import Foundation
import SwiftData
import SwiftUI
import ZentriCore

/// The app's entry point: it builds the shared state and hands it to the root view.
@main
struct ZentriApp: App {
    @State private var appState: AppState?

    init() {
        _appState = State(initialValue: Self.makeAppState())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let appState {
                    RootView()
                        .environment(appState)
                } else {
                    ContainerUnavailableView(retry: reload)
                }
            }
            .tint(Theme.accent)
        }
    }

    /// Rebuilds the shared state after the container could not be opened.
    private func reload() {
        appState = Self.makeAppState()
    }

    /// Builds the container, settings, parser, snapshot store, and shared state.
    ///
    /// `-UITestMode` swaps the App Group store and the settings file for in-memory equivalents, so
    /// a UI test can never read or write real shared state. A failure to open the container
    /// returns nil, which the window shows as a recoverable error instead of a launch crash.
    private static func makeAppState() -> AppState? {
        do {
            let container = try ZentriContainer.make(inMemory: UITestSupport.isUITestMode)
            let settingsStore = makeSettingsStore()
            try? settingsStore.load()
            if UITestSupport.isUITestMode {
                try UITestSupport.prepare(container: container, settingsStore: settingsStore)
            }
            let snapshotStore = FileWidgetSnapshotStore(
                fileURL: UITestSupport.isUITestMode ? nil : SharedContainer.widgetSnapshotURL
            )
            return AppState(
                container: container,
                settingsStore: settingsStore,
                parserBuilder: ParserFactory(modelClient: FoundationModelsClient()),
                snapshotStore: snapshotStore
            )
        } catch {
            return nil
        }
    }

    /// The settings store for this launch: in memory for a UI test, the shared file otherwise.
    private static func makeSettingsStore() -> SettingsStore {
        if UITestSupport.isUITestMode {
            let repository = InMemorySettingsRepository()
            return SettingsStore(
                repository: repository,
                deleteStoredSettings: { repository.clear() }
            )
        }
        // The App Group is the settings home. A build that cannot reach it (a missing
        // entitlement) falls back to app-local storage so the app still launches.
        let url = SharedContainer.settingsURL
            ?? URL.applicationSupportDirectory.appending(path: AppGroup.settingsFileName)
        return SettingsStore(
            repository: FileSettingsStore(fileURL: url),
            deleteStoredSettings: {
                let path = url.path(percentEncoded: false)
                guard FileManager.default.fileExists(atPath: path) else { return }
                try FileManager.default.removeItem(at: url)
            }
        )
    }
}
