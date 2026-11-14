import SwiftUI

/// The screen shown when saved settings exist but cannot be read.
///
/// Using defaults deletes the damaged settings file and returns to onboarding; accounts and
/// transactions live in the SwiftData store, not in settings, so they are untouched. Restoring from
/// a backup is offered here but only becomes possible once the backup folder is set up (Task 18).
///
/// Everything scrolls: with the largest accessibility text the explanation and both buttons need
/// more room than one screen, and nothing may be clipped away from the person who needs it most.
struct SettingsRecoveryView: View {
    private let store: SettingsStore

    @State private var resetFailed = false
    @State private var showsRestoreExplanation = false

    init(store: SettingsStore) {
        self.store = store
    }

    var body: some View {
        ScrollView {
            ContentUnavailableView {
                Label("Settings need a reset", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Zentri could not read its saved settings. Using defaults returns to setup and keeps your accounts and transactions.")
            } actions: {
                VStack(spacing: Theme.Spacing.sm) {
                    Button("Use Defaults", action: useDefaults)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(minHeight: Theme.Layout.minimumTapTarget)

                    Button("Restore Backup", action: explainRestore)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .frame(minHeight: Theme.Layout.minimumTapTarget)

                    if showsRestoreExplanation {
                        Text("Restoring a backup becomes available after you set up backup in Settings.")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryInk)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if resetFailed {
                        Text("Zentri couldn't reset its settings file. Try again.")
                            .font(.footnote)
                            .foregroundStyle(Theme.spending)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
            .padding(.vertical, Theme.Spacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Theme.canvas.ignoresSafeArea() }
    }

    /// Deletes the damaged settings file so the app returns to onboarding.
    private func useDefaults() {
        do {
            try store.reset()
            resetFailed = false
        } catch {
            resetFailed = true
        }
    }

    /// Explains why a restore is not possible yet.
    private func explainRestore() {
        showsRestoreExplanation = true
    }
}
