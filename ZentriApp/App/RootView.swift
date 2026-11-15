import SwiftUI

/// The app's root: onboarding, settings recovery, or the tab shell, depending on stored settings.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if appState.settingsStore.loadFailure != nil {
                SettingsRecoveryView(store: appState.settingsStore)
            } else if appState.settingsStore.settings == nil {
                OnboardingFlow()
            } else {
                RootTabView()
            }
        }
        .sensoryFeedback(.success, trigger: appState.settingsStore.loadFailure) { oldValue, newValue in
            // A successful reset clears the failure; confirming it is the one meaningful haptic
            // this shell has, so it stays silent when onboarding starts or a load fails.
            oldValue != nil && newValue == nil
        }
        .task {
            // A launch may follow captures the Shortcut made while Zentri was not running; the
            // scheduler compares the data with the folder's newest snapshot and writes only if it
            // differs.
            appState.backupScheduler.schedule()
            await appState.retryPendingIngestion()
        }
        .task {
            await cancelBackupOnTermination()
        }
        .onOpenURL(perform: openURL)
        .onChange(of: appState.dataRevision) {
            appState.backupScheduler.schedule()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                sceneBecameActive()
            case .background:
                appState.sceneDidEnterBackground()
            default:
                break
            }
        }
    }

    /// Drops a debounced backup that has not started when the app is about to terminate; the
    /// background flush has already written anything pending.
    private func cancelBackupOnTermination() async {
        for await _ in NotificationCenter.default.notifications(named: UIApplication.willTerminateNotification).map({ _ in () }) {
            appState.backupScheduler.cancel()
        }
    }

    /// Opens the tab a widget's `zentri://` link names.
    private func openURL(_ url: URL) {
        appState.open(url)
    }

    /// Shows anything a Shortcuts capture wrote while the app was in the background, and retries
    /// messages a cancelled capture left pending.
    private func sceneBecameActive() {
        Task {
            await appState.sceneDidBecomeActive()
        }
    }
}
