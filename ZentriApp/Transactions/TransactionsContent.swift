import SwiftData
import SwiftUI
import ZentriCore

/// The searchable, filterable history, with the detail, the manual editor, and the filters.
///
/// The filter lives in `AppState` so another tab can hand one over; the list re-filters when it
/// changes and reads the store again whenever a mutation anywhere bumps `dataRevision`. Every change
/// made here goes through ``TransactionMutationService`` and then `AppState.mutate()`.
struct TransactionsContent: View {
    @Environment(AppState.self) private var appState
    @State private var model: TransactionsModel
    @State private var selection: TransactionSelection?
    @State private var isAddingTransaction = false
    @State private var isShowingFilters = false
    @State private var addedCount = 0

    init(context: ModelContext) {
        _model = State(initialValue: TransactionsModel(context: context))
    }

    var body: some View {
        @Bindable var appState = appState
        TransactionsStateView(
            model: model,
            filter: appState.transactionFilter,
            onSelect: select,
            onAdd: startAdding,
            onClearFilters: clearFilters,
            onRetry: refresh
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .searchable(
            text: $appState.transactionFilter.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("Merchant, note, or message")
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Filters", systemImage: filterSymbol, action: showFilters)
                    .accessibilityIdentifier("transactions.filters")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Add Transaction", systemImage: "plus", action: startAdding)
                    .accessibilityIdentifier("transactions.add")
            }
        }
        .onAppear(perform: refresh)
        .onChange(of: appState.dataRevision) {
            refresh()
        }
        .onChange(of: appState.transactionFilter) {
            model.apply(appState.transactionFilter)
        }
        .sheet(item: $selection) { selection in
            TransactionDetailView(
                selection: selection,
                service: appState.makeTransactionMutationService(),
                accounts: model.accounts,
                categories: model.categories,
                onMutation: appState.mutate,
                onReprocess: appState.reprocess
            )
        }
        .sheet(isPresented: $isAddingTransaction) {
            TransactionEditorView(
                title: "New Transaction",
                initial: nil,
                accounts: model.accounts,
                categories: model.categories,
                onSave: add
            )
        }
        .sheet(isPresented: $isShowingFilters) {
            TransactionFilterSheet(
                filter: appState.transactionFilter,
                accounts: model.accounts,
                categories: model.categories,
                onApply: applyFilters
            )
        }
        .sensoryFeedback(.success, trigger: addedCount)
    }

    private var filterSymbol: String {
        appState.transactionFilter.hasActiveFilters
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle"
    }

    private func refresh() {
        model.refresh(filter: appState.transactionFilter)
    }

    private func select(_ item: TransactionListItem) {
        guard let transaction = model.transaction(id: item.id) else { return }
        selection = TransactionSelection(
            id: item.id,
            transaction: transaction,
            matchedRuleName: model.ruleName(id: transaction.matchedRuleID)
        )
    }

    private func startAdding() {
        isAddingTransaction = true
    }

    private func showFilters() {
        isShowingFilters = true
    }

    private func clearFilters() {
        appState.transactionFilter = appState.transactionFilter.clearingFilters
    }

    private func applyFilters(_ filter: TransactionFilter) {
        appState.transactionFilter = filter
    }

    /// Saves a manual transaction, then tells every screen the store changed.
    private func add(_ edit: TransactionEdit) async throws {
        try await appState.makeTransactionMutationService().save(edit, existing: nil)
        addedCount += 1
        appState.mutate()
    }
}
