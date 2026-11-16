import SwiftData
import SwiftUI
import ZentriCore

/// The Overview tab: the combined balance, this month's totals, and the last week's activity.
///
/// This view only supplies what the dashboard cannot read for itself — the store's context, the
/// revision that asks for a reload, and the action the empty state offers. Everything else lives in
/// ``OverviewContent``, which is the same dashboard without the app's shared state.
struct OverviewView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        OverviewContent(
            context: appState.container.mainContext,
            dataRevision: appState.dataRevision,
            onFinishSetup: finishSetup,
            onSelectCategory: showTransactions(for:),
            onSeeAllTransactions: showAllTransactions
        )
        .ambientBackground()
        .navigationTitle("Overview")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ParsingRoute.self) { route in
            ParsingRouteDestination(route: route)
                .scrollContentBackground(.hidden)
                .ambientBackground()
        }
    }

    /// Opens Transactions filtered to one of this month's top categories.
    private func showTransactions(for category: CategoryTotal) {
        guard let id = category.categoryID else { return }
        appState.transactionFilter = TransactionFilter(categoryID: id)
        appState.selectedTab = .transactions
    }

    /// Opens Transactions with no filter.
    private func showAllTransactions() {
        appState.transactionFilter = TransactionFilter()
        appState.selectedTab = .transactions
    }

    /// Points a person whose store holds no account at the screen that adds one.
    private func finishSetup() {
        appState.selectedTab = .settings
    }
}

#Preview {
    let container = try! ZentriContainer.make(inMemory: true)
    return NavigationStack {
        OverviewContent(
            context: container.mainContext,
            dataRevision: 0,
            onFinishSetup: {}
        )
        .navigationTitle("Overview")
    }
    .background { Theme.canvas.ignoresSafeArea() }
}
