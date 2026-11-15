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
            await appState.retryPendingIngestion()
        }
        .onOpenURL(perform: openURL)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                sceneBecameActive()
            }
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
