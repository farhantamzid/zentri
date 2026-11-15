import SwiftData
import SwiftUI
import ZentriCore

/// The Insights tab: one month's spending, its charts, and what stands out.
///
/// This view only supplies what the screen cannot read for itself — the store's context, the
/// revision that asks for a reload, and the hand-off to Transactions. Everything else lives in
/// ``InsightsContent``.
struct InsightsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        InsightsContent(
            context: appState.container.mainContext,
            dataRevision: appState.dataRevision,
            onShowTransactions: showTransactions
        )
        .background { Theme.canvas.ignoresSafeArea() }
        .navigationTitle("Insights")
    }

    /// Opens Transactions with the filter that lists what the tapped total is made of. Transactions
    /// shows the filter as active, and its own "clear filters" control resets it.
    private func showTransactions(_ filter: TransactionFilter) {
        appState.transactionFilter = filter
        appState.selectedTab = .transactions
    }
}

#Preview {
    let container = try! ZentriContainer.make(inMemory: true)
    return NavigationStack {
        InsightsContent(context: container.mainContext, dataRevision: 0, onShowTransactions: { _ in })
            .navigationTitle("Insights")
    }
    .background { Theme.canvas.ignoresSafeArea() }
}
