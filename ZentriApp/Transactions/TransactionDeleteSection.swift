import SwiftUI

/// The delete action, confirmed first; the bank message stays in the archive.
struct TransactionDeleteSection: View {
    let onDelete: @MainActor () -> Void

    @State private var isConfirming = false

    var body: some View {
        Section {
            Button("Delete Transaction", role: .destructive, action: confirm)
                .frame(minHeight: Theme.Layout.minimumTapTarget)
                .accessibilityIdentifier("transactions.detail.delete")
                .confirmationDialog("Delete this transaction?", isPresented: $isConfirming, titleVisibility: .visible) {
                    Button("Delete Transaction", role: .destructive, action: onDelete)
                } message: {
                    Text("The balance updates without it. Any bank message it came from stays in the archive.")
                }
                .sensoryFeedback(.warning, trigger: isConfirming) { _, isShowing in isShowing }
        }
    }

    private func confirm() {
        isConfirming = true
    }
}
