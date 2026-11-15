import SwiftUI
import ZentriCore

/// The folder's snapshots, or what stands in for them: loading, no folder, an empty folder, or a
/// folder that could not be read — never shown as an empty list.
struct BackupSnapshotsStateView: View {
    let state: BackupSnapshotsState
    let onOpen: (SnapshotInfo) -> Void
    let onChooseFolder: () -> Void
    let onRetry: () -> Void

    var body: some View {
        switch state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
        case .noFolder:
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("No backup folder is chosen on this iPhone.")
                    .foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("backup.restore.noFolder")
                Button("Choose iCloud Drive folder", systemImage: "folder.badge.plus", action: onChooseFolder)
                    .frame(minHeight: Theme.Layout.minimumTapTarget)
            }
        case .loaded(let snapshots) where snapshots.isEmpty:
            Text("This folder holds no Zentri backups yet.")
                .foregroundStyle(Theme.secondaryInk)
                .accessibilityIdentifier("backup.restore.empty")
        case .loaded(let snapshots):
            ForEach(snapshots) { snapshot in
                BackupSnapshotRow(snapshot: snapshot, onOpen: onOpen)
            }
        case .failed(let error):
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(error.message)
                    .foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("backup.restore.failure")
                if error == .permissionDenied {
                    Button("Choose iCloud Drive folder", systemImage: "folder.badge.plus", action: onChooseFolder)
                        .frame(minHeight: Theme.Layout.minimumTapTarget)
                } else {
                    Button("Try Again", systemImage: "arrow.clockwise", action: onRetry)
                        .frame(minHeight: Theme.Layout.minimumTapTarget)
                }
            }
        }
    }
}
