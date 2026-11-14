import SwiftUI

/// The screen shown when saved settings exist but cannot be read.
///
/// Resetting deletes the damaged settings file and returns to onboarding; accounts and
/// transactions live in the SwiftData store, not in settings, so they are untouched. Restoring from
/// a backup is offered here but only becomes possible once the backup folder is set up (Task 18).
struct SettingsRecoveryView: View {
    private let store: SettingsStore

    @State private var resetFailed = false
    @State private var showsRestoreExplanation = false

    init(store: SettingsStore) {
        self.store = store
    }

    var body: some View {
        ContentUnavailableView {
            Label("Settings need a reset", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Zentri could not read its saved settings. Resetting returns to setup and keeps your accounts and transactions.")
        } actions: {
            VStack(spacing: Theme.Spacing.sm) {
                Button("Reset Settings", action: resetSettings)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(minHeight: Theme.Layout.minimumTapTarget)
                Button("Restore Backup") {
                    showsRestoreExplanation = true
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(minHeight: Theme.Layout.minimumTapTarget)
                if showsRestoreExplanation {
                    Text("Restoring a backup becomes available after you set up backup in Settings.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                        .multilineTextAlignment(.center)
                }
                if resetFailed {
                    Text("Zentri couldn't reset its settings file. Try again.")
                        .font(.footnote)
                        .foregroundStyle(Theme.spending)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Theme.canvas.ignoresSafeArea() }
    }

    /// Deletes the damaged settings file so the app returns to onboarding.
    private func resetSettings() {
        do {
            try store.reset()
            resetFailed = false
        } catch {
            resetFailed = true
        }
    }
}
