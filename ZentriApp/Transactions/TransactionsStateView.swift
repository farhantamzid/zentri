import SwiftUI

/// Chooses what the tab shows for the model's state: nothing yet, the failure, the empty history,
/// or the list, which shows its own no-matches state under the filter chips.
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
    let onDelete: @MainActor (TransactionListItem) -> Void
    let onFilterChange: @MainActor (TransactionFilter) -> Void
    let transition: Namespace.ID

    var body: some View {
        switch model.loadState {
        case .loading:
            Color.clear
        case .failed:
            TransactionsFailureState(onRetry: onRetry)
        case .loaded:
            if !model.hasTransactions {
                TransactionsEmptyState(onAdd: onAdd)
            } else {
                TransactionsList(
                    balance: model.balance,
                    sections: model.sections,
                    filter: filter,
                    chipCategories: model.chipCategories,
                    onSelect: onSelect,
                    onDelete: onDelete,
                    onFilterChange: onFilterChange,
                    onClearFilters: onClearFilters,
                    transition: transition
                )
            }
        }
    }
}
