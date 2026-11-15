import Foundation
import SwiftData
import SwiftUI
import ZentriCore

/// The app's entry point: it builds the shared state and the Face ID lock and hands them to the root
/// view.
@main
struct ZentriApp: App {
    @State private var appState: AppState?
    @State private var appLock: AppLockController

    init() {
        let appState = Self.makeAppState()
        _appState = State(initialValue: appState)
        _appLock = State(initialValue: AppComposition.makeAppLock(settings: appState?.settingsStore.settings))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let appState {
                    RootView()
                        .environment(appState)
                        .environment(appLock)
                } else {
                    ContainerUnavailableView(retry: reload)
                }
            }
            .tint(Theme.accent)
        }
    }

    /// Rebuilds the shared state after the container could not be opened, and the lock with it, so
    /// a lock the settings turn on starts locked.
    private func reload() {
        appState = Self.makeAppState()
        appLock = AppComposition.makeAppLock(settings: appState?.settingsStore.settings)
    }

    /// Builds the container, settings, parser, snapshot store, and shared state.
    ///
    /// ``AppComposition`` builds each piece and shares the container and settings with the Shortcuts
    /// capture, which finds this state through ``AppComposition/liveAppState``. In
    /// `-UITestMode` every piece is in memory or inert, and the launch switches seed the fixtures. A
    /// failure to open the container returns nil, which the window shows as a recoverable error
    /// instead of a launch crash.
    private static func makeAppState() -> AppState? {
        do {
            let container = try AppComposition.sharedContainer()
            let settingsStore = AppComposition.sharedSettingsStore()
            if UITestSupport.isUITestMode {
                try UITestSupport.prepare(container: container, settingsStore: settingsStore)
            }
            let modelClient = AppComposition.makeModelClient()
            let appState = AppState(
                container: container,
                settingsStore: settingsStore,
                parserBuilder: ParserFactory(modelClient: modelClient),
                modelClient: modelClient,
                snapshotStore: AppComposition.makeSnapshotStore(),
                timelineReloader: AppComposition.makeTimelineReloader(),
                backupFolder: AppComposition.makeBackupFolder(),
                backgroundTasks: AppComposition.makeBackgroundTasks()
            )
            AppComposition.liveAppState = appState
            return appState
        } catch {
            return nil
        }
    }
}
