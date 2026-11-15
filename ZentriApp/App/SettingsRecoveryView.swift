import SwiftUI

/// The screen shown when saved settings exist but cannot be read.
///
/// Using defaults deletes the damaged settings file and returns to onboarding; accounts and
/// transactions live in the SwiftData store, not in settings, so they are untouched. "Restore Backup"
/// opens the restore browser — the backup folder's snapshots or any backup file — and a replace
/// restore saves the backup's settings, which clears the failure and opens the app.
///
/// Everything scrolls: with the largest accessibility text the explanation and both buttons need
/// more room than one screen, and nothing may be clipped away from the person who needs it most.
struct SettingsRecoveryView: View {
    private let store: SettingsStore

    @State private var resetFailed = false
    @State private var isRestoring = false

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

                    Button("Restore Backup", action: startRestore)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .frame(minHeight: Theme.Layout.minimumTapTarget)
                        .accessibilityIdentifier("recovery.restoreBackup")

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
        .sheet(isPresented: $isRestoring) {
            NavigationStack {
                BackupRestoreView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel", action: cancelRestore)
                        }
                    }
            }
        }
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

    /// Opens the restore browser.
    private func startRestore() {
        isRestoring = true
    }

    private func cancelRestore() {
        isRestoring = false
    }
}
