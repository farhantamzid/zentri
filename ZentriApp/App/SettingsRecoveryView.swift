import SwiftUI

/// The screen shown when saved settings exist but cannot be read.
///
/// Using defaults replaces the damaged settings with the defaults and opens the app; accounts and
/// transactions live in the SwiftData store, not in settings, so they are untouched. Only a store
/// with no account returns to setup, so setup never adds a second account. "Restore Backup"
/// opens the restore browser — the backup folder's snapshots or any backup file — and a replace
/// restore saves the backup's settings, which clears the failure and opens the app.
///
/// Everything scrolls: with the largest accessibility text the explanation and both buttons need
/// more room than one screen, and nothing may be clipped away from the person who needs it most.
struct SettingsRecoveryView: View {
    @Environment(AppState.self) private var appState

    @State private var resetFailed = false
    @State private var isRestoring = false

    var body: some View {
        ScrollView {
            ContentUnavailableView {
                Label("Settings need a reset", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Zentri could not read its saved settings. Using defaults resets preferences such as the currency and keeps your accounts and transactions.")
            } actions: {
                VStack(spacing: Theme.Spacing.sm) {
                    Button("Use Defaults", action: startUsingDefaults)
                        .prominentButtonStyle()
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

    /// Starts replacing the damaged settings with the defaults.
    private func startUsingDefaults() {
        Task { await useDefaults() }
    }

    /// Saves default settings — or, with no account stored, returns to setup.
    private func useDefaults() async {
        do {
            try await appState.useDefaultSettings()
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
