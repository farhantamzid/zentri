import Foundation
import SwiftData
import ZentriCore

/// Builds the store, settings, model client, and widget snapshot plumbing the app and its intents
/// share, so a Shortcut capture writes to exactly what the app reads.
///
/// The container and the settings store are built once per process. A Shortcuts capture runs inside
/// the app's process, often while Zentri is suspended in memory, so it must write through the same
/// container — and the same main context — the app's screens read; a second container on the same
/// store would leave those screens showing stale rows. ``liveAppState`` is how a capture finds the
/// running app to tell it the store changed.
///
/// `-UITestMode` swaps the App Group store, the settings file, the snapshot file, the widget
/// reloads, and the backup folder for in-memory or inert equivalents, so a UI test can never read or write real shared
/// state.
@MainActor
enum AppComposition {
    /// The app's shared state once a window has built it, or `nil` when the process was launched
    /// only to run an intent. Held weakly: the app owns it.
    static weak var liveAppState: AppState?

    private static var container: ModelContainer?
    private static var settingsStore: SettingsStore?

    /// The process-wide SwiftData container: the App Group store, or an in-memory one for a UI test.
    ///
    /// Built on first use and kept; a failure is not cached, so a later call can try again.
    static func sharedContainer() throws -> ModelContainer {
        if let container {
            return container
        }
        let made = try ZentriContainer.make(inMemory: UITestSupport.isUITestMode)
        container = made
        return made
    }

    /// The process-wide settings store, loaded on first use: in memory for a UI test, the shared file
    /// otherwise.
    ///
    /// A document that cannot be read leaves `settings` nil and `loadFailure` set, which the app shows
    /// as recovery and a capture reports as unfinished setup.
    static func sharedSettingsStore() -> SettingsStore {
        if let settingsStore {
            return settingsStore
        }
        let store: SettingsStore
        if UITestSupport.isUITestMode {
            store = SettingsStore(
                repository: UITestSupport.startsWithUnreadableSettings
                    ? UnreadableSettingsRepository()
                    : InMemorySettingsRepository()
            )
        } else {
            // The App Group is the settings home. A build that cannot reach it (a missing
            // entitlement) falls back to app-local storage so the app still launches.
            let url = SharedContainer.settingsURL
                ?? URL.applicationSupportDirectory.appending(path: AppGroup.settingsFileName)
            store = SettingsStore(repository: FileSettingsStore(fileURL: url))
        }
        try? store.load()
        settingsStore = store
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

    /// What tells WidgetKit the snapshot changed: `WidgetCenter`, or nothing for a UI test.
    static func makeTimelineReloader(
        isUITestMode: Bool = UITestSupport.isUITestMode
    ) -> any WidgetTimelineReloading {
        isUITestMode ? InertTimelineReloader() : WidgetCenterTimelineReloader()
    }

    /// The refresher that rewrites the widget snapshot from the container's main context, reading the
    /// live settings on every refresh so a currency change reaches the widgets, and then reloads the
    /// widgets.
    static func makeSnapshotRefresher(
        container: ModelContainer,
        settingsStore: SettingsStore,
        snapshotStore: any WidgetSnapshotStore,
        timelineReloader: any WidgetTimelineReloading
    ) -> WidgetSnapshotPublisher {
        WidgetSnapshotPublisher(
            refresher: LiveWidgetSnapshotRefresher(
                context: container.mainContext,
                store: snapshotStore,
                settings: { [weak settingsStore] in settingsStore?.settings ?? .defaultValue },
                now: { .now },
                calendar: .current
            ),
            store: snapshotStore,
            timelineReloader: timelineReloader
        )
    }

    /// The backup folder: the person's chosen folder, remembered in the app's own defaults, or an
    /// inert folder for a UI test, which must never read a real bookmark or write a real folder.
    static func makeBackupFolder(isUITestMode: Bool = UITestSupport.isUITestMode) -> any BackupFolderAccessing {
        isUITestMode ? InertBackupFolder() : BackupFolderService(bookmarkStore: BackupBookmarkStore())
    }

    /// Background time for the backup written as the app leaves the screen; none for a UI test.
    static func makeBackgroundTasks(isUITestMode: Bool = UITestSupport.isUITestMode) -> any BackgroundTaskRunning {
        isUITestMode ? ImmediateBackgroundTasks() : ApplicationBackgroundTasks()
    }

    /// The device check behind the Face ID lock: LocalAuthentication, or the answer a UI test
    /// scripted with `-UITestMockBiometrics`.
    static func makeBiometricAuthenticator() -> any BiometricAuthenticating {
        if UITestSupport.isUITestMode, let succeeds = UITestSupport.mockBiometricsSucceeds {
            return UITestBiometrics(succeeds: succeeds)
        }
        return LocalAuthenticationService()
    }

    /// The app lock, locked from the start when the saved settings turn it on, so no data is drawn
    /// before the first check.
    static func makeAppLock(settings: AppSettings?) -> AppLockController {
        AppLockController(
            biometric: makeBiometricAuthenticator(),
            faceIDEnabled: settings?.faceIDEnabled ?? false
        )
    }

    /// A capture handler over the shared container and settings, for an intent that runs before any
    /// window has built the app's state.
    static func makeStandaloneCaptureHandler() throws -> CaptureSMSHandler {
        let container = try sharedContainer()
        let settingsStore = sharedSettingsStore()
        return CaptureSMSHandler(
            container: container,
            settingsStore: settingsStore,
            parserBuilder: ParserFactory(modelClient: makeModelClient()),
            snapshotRefresher: makeSnapshotRefresher(
                container: container,
                settingsStore: settingsStore,
                snapshotStore: makeSnapshotStore(),
                timelineReloader: makeTimelineReloader()
            )
        )
    }
}
