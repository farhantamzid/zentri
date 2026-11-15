import SwiftUI

/// Shown when the store holds no transactions at all: says where they will come from.
struct TransactionsEmptyState: View {
    let onAdd: @MainActor () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No transactions yet", systemImage: "message.badge")
        } description: {
            Text("Transactions appear here as the Shortcut passes your bank's SMS messages to Zentri. You can also add one you missed.")
        } actions: {
            Button("Add Transaction", action: onAdd)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(minHeight: Theme.Layout.minimumTapTarget)
        }
    }
}
