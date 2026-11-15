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
    /// ``AppComposition`` builds each piece, the same way the Shortcuts capture does; in
    /// `-UITestMode` every piece is in memory or inert, and the launch switches seed the fixtures. A
    /// failure to open the container returns nil, which the window shows as a recoverable error
    /// instead of a launch crash.
    private static func makeAppState() -> AppState? {
        do {
            let container = try AppComposition.makeContainer()
            let settingsStore = AppComposition.makeSettingsStore()
            if UITestSupport.isUITestMode {
                try UITestSupport.prepare(container: container, settingsStore: settingsStore)
            }
            let modelClient = AppComposition.makeModelClient()
            return AppState(
                container: container,
                settingsStore: settingsStore,
                parserBuilder: ParserFactory(modelClient: modelClient),
                modelClient: modelClient,
                snapshotStore: AppComposition.makeSnapshotStore()
            )
        } catch {
            return nil
        }
    }
}
