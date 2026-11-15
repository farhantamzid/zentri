import SwiftUI
import ZentriCore

/// What a backup holds, and the choice of how to restore it.
///
/// Replace asks once more, because it deletes everything stored now; merge only adds what is
/// missing and keeps the current settings.
struct BackupRestoreConfirmation: View {
    let candidate: BackupRestoreCandidate
    let modes: [ImportMode]
    let onRestore: (BackupRestoreCandidate, ImportMode) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingReplace = false

    var body: some View {
        NavigationStack {
            Form {
                BackupCandidateSummarySection(candidate: candidate)

                Section {
                    Button("Replace All Data", systemImage: "arrow.triangle.2.circlepath", role: .destructive, action: confirmReplace)
                        .accessibilityIdentifier("backup.restore.replace")
                        .confirmationDialog(
                            "Replace all data?",
                            isPresented: $isConfirmingReplace,
                            titleVisibility: .visible
                        ) {
                            Button("Replace All Data", role: .destructive, action: replace)
                        } message: {
                            Text("Every account, transaction, saved message, rule, and category on this iPhone is replaced by the backup's, and the backup's currency and display settings are applied. This can't be undone.")
                        }

                    if modes.contains(.merge) {
                        Button("Merge Into Current Data", systemImage: "arrow.merge", action: merge)
                            .accessibilityIdentifier("backup.restore.merge")
                    }
                } footer: {
                    if modes.contains(.merge) {
                        Text("Merge keeps everything you have and your settings, and adds only what is missing.")
                    } else {
                        Text("Restoring replaces Zentri's data and settings with the backup's.")
                    }
                }
            }
            .navigationTitle("Restore Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
            }
            .sensoryFeedback(.warning, trigger: isConfirmingReplace) { _, isConfirming in
                isConfirming
            }
        }
    }

    private func confirmReplace() {
        isConfirmingReplace = true
    }

    private func replace() {
        dismiss()
        onRestore(candidate, .replace)
    }

    private func merge() {
        dismiss()
        onRestore(candidate, .merge)
    }

    private func cancel() {
        dismiss()
    }
}
