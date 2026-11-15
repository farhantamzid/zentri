import SwiftUI

/// Shown while automatic backups wait because the chosen folder already holds other backups.
///
/// Backing up there is a deliberate choice with a confirmation, because every new snapshot
/// eventually rotates one of the older ones out.
struct BackupHeldFolderNotice: View {
    let onConfirm: () -> Void

    @State private var isConfirming = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label {
                Text("This folder already holds Zentri backups that differ from this iPhone's data. Automatic backups are paused so they aren't replaced. Restore from the folder, or back up this iPhone there.")
                    .foregroundStyle(Theme.ink)
            } icon: {
                Image(systemName: "pause.circle")
                    .foregroundStyle(Theme.accent)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("backup.held")

            Button("Back Up This iPhone Here", systemImage: "arrow.up.doc", action: confirm)
                .frame(minHeight: Theme.Layout.minimumTapTarget)
                .accessibilityIdentifier("backup.confirmFolder")
                .confirmationDialog(
                    "Back up this iPhone to this folder?",
                    isPresented: $isConfirming,
                    titleVisibility: .visible
                ) {
                    Button("Back Up Here", action: onConfirm)
                } message: {
                    Text("Zentri keeps the latest 10 snapshots, so the backups already in this folder are deleted one by one as new ones are saved. Restore from the folder first if you need them.")
                }
        }
    }

    private func confirm() {
        isConfirming = true
    }
}
