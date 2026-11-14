import SwiftUI

/// The app's root: onboarding, settings recovery, or the tab shell, depending on stored settings.
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.settingsStore.loadFailure != nil {
                SettingsRecoveryView(store: appState.settingsStore)
            } else if appState.settingsStore.settings == nil {
                OnboardingPlaceholderView()
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
    }
}
