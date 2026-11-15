import SwiftUI

/// Shown when the store could not be read, which is not the same as having no transactions.
struct TransactionsFailureState: View {
    let onRetry: @MainActor () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Can't show your transactions", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Zentri couldn't read your data just now. Try again.")
        } actions: {
            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(minHeight: Theme.Layout.minimumTapTarget)
                .accessibilityIdentifier("transactions.retry")
        }
    }
}
