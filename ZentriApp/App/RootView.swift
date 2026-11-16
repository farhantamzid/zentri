import SwiftUI
import ZentriCore

/// The app's root: onboarding, settings recovery, or the tab shell, depending on stored settings,
/// under the Face ID lock's privacy cover, drawn in the appearance mode the settings choose.
///
/// With the lock on, the cover hides the app while it is locked and whenever the scene is not
/// active, so the app-switcher snapshot is taken of the cover. The cover is drawn twice: an opaque
/// layer in this hierarchy, which is present from the first frame of a cold launch, and the lock
/// screen in a window of its own, which also hides sheets and pickers that sit above this view.
/// The content beneath is hidden from VoiceOver while covered.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppLockController.self) private var appLock
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let isCovered = appLock.isCovering(sceneIsActive: scenePhase == .active)
        let colorScheme = appState.settingsStore.settings?.appearanceMode.colorScheme
        Group {
            if appState.settingsStore.loadFailure != nil {
                SettingsRecoveryView()
            } else if appState.settingsStore.settings == nil {
                OnboardingFlow(biometric: appLock.biometric)
            } else {
                RootTabView()
            }
        }
        .accessibilityHidden(isCovered)
        .overlay {
            if isCovered {
                Theme.canvas
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }
        }
        .background {
            PrivacyCoverWindowHost(isPresented: isCovered) {
                // The cover lives in a window of its own, which the root's scheme does not reach.
                PrivacyCoverView(lock: appLock, onTurnOff: turnOffLock)
                    .preferredColorScheme(colorScheme)
            }
        }
        // Applied at the root so the window, and every sheet and alert presented in it, follows the
        // chosen mode; nil follows the device. Onboarding and recovery have no settings yet, so they
        // follow the device.
        .preferredColorScheme(colorScheme)
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
        }
        .task(id: appState.settingsStore.settings != nil) {
            // Runs at launch, and again once settings become readable after recovery, so a message a
            // capture archived while the settings were unreadable is read without another relaunch.
            await appState.retryPendingIngestion()
        }
        .task {
            await cancelBackupOnTermination()
        }
        .onOpenURL(perform: openURL)
        .onChange(of: appState.dataRevision) {
            appState.backupScheduler.schedule()
        }
        .onChange(of: appState.settingsStore.settings?.faceIDEnabled ?? false) { _, enabled in
            appLock.faceIDEnabled = enabled
        }
        .onChange(of: appLock.isLocked) { _, isLocked in
            if !isLocked {
                openHeldURL()
            }
        }
        .onChange(of: scenePhase, initial: true) { oldPhase, phase in
            // The first call reports the launch phase: it only lets a locked app ask for Face ID.
            // The foreground refresh and the backup flush follow real transitions.
            if phase == .active {
                requestUnlock()
            }
            guard oldPhase != phase else { return }
            switch phase {
            case .active:
                sceneBecameActive()
            case .background:
                appLock.lockIfNeeded()
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

    /// Opens the tab a widget's `zentri://` link names, or holds the link until the app unlocks.
    private func openURL(_ url: URL) {
        if !appLock.holdIfLocked(url) {
            appState.open(url)
        }
    }

    /// Opens a link that arrived while the app was locked.
    private func openHeldURL() {
        if let url = appLock.takePendingURL() {
            appState.open(url)
        }
    }

    /// Asks for Face ID once after the app locked.
    private func requestUnlock() {
        Task {
            await appLock.sceneDidBecomeActive()
        }
    }

    /// Shows anything a Shortcuts capture wrote while the app was in the background, and retries
    /// messages a cancelled capture left pending.
    private func sceneBecameActive() {
        Task {
            await appState.sceneDidBecomeActive()
        }
    }

    /// Saves the lock off from the lock screen of a device that cannot check its owner.
    private func turnOffLock() {
        Task {
            await appLock.turnOff(saving: saveLockOff)
        }
    }

    private func saveLockOff() async throws {
        guard var settings = appState.settingsStore.settings else { return }
        settings.faceIDEnabled = false
        try await appState.updateSettings(settings)
    }
}
