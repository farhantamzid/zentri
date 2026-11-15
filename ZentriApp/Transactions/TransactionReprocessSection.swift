import SwiftUI

/// Reads the transaction's bank message again with the current rules, confirmed first.
struct TransactionReprocessSection: View {
    let isReprocessing: Bool
    let onReprocess: @MainActor () -> Void

    @State private var isConfirming = false

    var body: some View {
        Section {
            Button(action: confirm) {
                Label("Reprocess Message", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget, alignment: .leading)
                    .contentShape(.rect)
            }
            .disabled(isReprocessing)
            .accessibilityIdentifier("transactions.detail.reprocess")
            .confirmationDialog("Reprocess this message?", isPresented: $isConfirming, titleVisibility: .visible) {
                Button("Reprocess", action: onReprocess)
            } message: {
                Text("This transaction is replaced only if the message parses. Your note, transfer setting, and chosen category are kept.")
            }
        } footer: {
            Text("Use this after fixing the rule that read this message.")
        }
    }

    private func confirm() {
        isConfirming = true
    }
}
