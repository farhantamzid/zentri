import SwiftUI
import ZentriCore

/// One backup in the folder: when it was made, how many transactions it holds, and its size.
struct BackupSnapshotRow: View {
    let snapshot: SnapshotInfo
    let onOpen: (SnapshotInfo) -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(snapshot.createdAt, format: .dateTime.day().month().year().hour().minute())
                    .foregroundStyle(Theme.ink)
                Text("^[\(snapshot.transactionCount) transaction](inflect: true) · \(Int64(snapshot.byteCount).formatted(.byteCount(style: .file)))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget, alignment: .leading)
            .contentShape(.rect)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Shows what this backup holds before restoring it."))
        .accessibilityIdentifier("backup.restore.snapshot")
    }

    private func open() {
        onOpen(snapshot)
    }
}
