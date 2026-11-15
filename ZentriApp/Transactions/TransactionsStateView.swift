import SwiftUI

/// Chooses what the tab shows for the model's state: nothing yet, the failure, the empty history,
/// no matches, or the list.
///
/// The blank loading branch is on screen for one frame at most; it has to exist so the view appears
/// and its first read runs.
struct TransactionsStateView: View {
    let model: TransactionsModel
    let filter: TransactionFilter
    let onSelect: @MainActor (TransactionListItem) -> Void
    let onAdd: @MainActor () -> Void
    let onClearFilters: @MainActor () -> Void
    let onRetry: @MainActor () -> Void

    var body: some View {
        switch model.loadState {
        case .loading:
            Color.clear
        case .failed:
            TransactionsFailureState(onRetry: onRetry)
        case .loaded:
            if !model.hasTransactions {
                TransactionsEmptyState(onAdd: onAdd)
            } else if model.sections.isEmpty {
                TransactionsNoMatchesState(
                    searchText: filter.searchText,
                    hasActiveFilters: filter.hasActiveFilters,
                    onClearFilters: onClearFilters
                )
            } else {
                TransactionsList(balance: model.balance, sections: model.sections, onSelect: onSelect)
            }
        }
    }
}
