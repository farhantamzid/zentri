import SwiftUI

/// The detail's two actions side by side, as soft capsules: read the message again with the
/// current rules, and delete. Each asks first.
struct TransactionDetailActions: View {
    let canReprocess: Bool
    let isReprocessing: Bool
    let onReprocess: @MainActor () -> Void
    let onDelete: @MainActor () -> Void

    @State private var isConfirmingReprocess = false
    @State private var isConfirmingDelete = false

    var body: some View {
        Section {
            HStack(spacing: 10) {
                if canReprocess {
                    Button {
                        isConfirmingReprocess = true
                    } label: {
                        Label("Reprocess", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(SoftCapsuleButtonStyle())
                    .disabled(isReprocessing)
                    .accessibilityIdentifier("transactions.detail.reprocess")
                    .confirmationDialog("Reprocess this message?", isPresented: $isConfirmingReprocess, titleVisibility: .visible) {
                        Button("Reprocess", action: onReprocess)
                    } message: {
                        Text("This transaction is replaced only if the message parses. Your note, transfer setting, and chosen category are kept.")
                    }
                }
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(SoftCapsuleButtonStyle(destructive: true))
                .accessibilityLabel(Text("Delete Transaction"))
                .accessibilityIdentifier("transactions.detail.delete")
                .confirmationDialog("Delete this transaction?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                    Button("Delete Transaction", role: .destructive, action: onDelete)
                } message: {
                    Text("The balance updates without it. Any bank message it came from stays in the archive.")
                }
                .sensoryFeedback(.warning, trigger: isConfirmingDelete) { _, isShowing in isShowing }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        } footer: {
            if canReprocess {
                Text("Reprocess after fixing the rule that read this message.")
            }
        }
        .riseIn(delay: 0.32)
    }
}
