import SwiftUI

/// Deletes one message from the archive, confirmed first; its transaction is kept.
struct RawMessageDeleteSection: View {
    let onDelete: @MainActor () -> Void

    @State private var isConfirming = false

    var body: some View {
        Section {
            Button(role: .destructive, action: confirm) {
                Label("Delete Message", systemImage: "trash")
                    .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget, alignment: .leading)
                    .contentShape(.rect)
            }
            .accessibilityIdentifier("inbox.detail.delete")
            .confirmationDialog("Delete this message?", isPresented: $isConfirming, titleVisibility: .visible) {
                Button("Delete Message", role: .destructive, action: onDelete)
            } message: {
                Text("The message leaves the archive. Any transaction it became is kept.")
            }
            .sensoryFeedback(.warning, trigger: isConfirming) { _, isShowing in isShowing }
        }
    }

    private func confirm() {
        isConfirming = true
    }
}
