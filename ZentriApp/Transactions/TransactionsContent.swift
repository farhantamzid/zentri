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
    @State private var isPastingSMS = false
    /// The transaction a pasted message just became, opened once the paste sheet has closed.
    @State private var pastedTransactionID: UUID?
    @State private var isShowingFilters = false
    @State private var addedCount = 0
    @State private var deletedCount = 0
    @State private var isShowingDeleteError = false
    @Namespace private var rowTransition

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
            onRetry: refresh,
            onDelete: delete,
            onFilterChange: applyFilters,
            transition: rowTransition
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
                Menu("Add Transaction", systemImage: "plus") {
                    Button("Paste Bank SMS", systemImage: "doc.on.clipboard", action: startPasting)
                        .accessibilityIdentifier("transactions.add.paste")
                    Button("Enter Manually", systemImage: "square.and.pencil", action: startAdding)
                        .accessibilityIdentifier("transactions.add.manual")
                }
                .accessibilityIdentifier("transactions.add")
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
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
            .navigationTransition(.zoom(sourceID: selection.id, in: rowTransition))
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
        .sheet(isPresented: $isPastingSMS, onDismiss: openPastedTransaction) {
            PasteSMSView(
                accounts: model.accounts,
                parserMode: appState.parserMode,
                onAdded: { id in
                    pastedTransactionID = id
                    addedCount += 1
                }
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
        .sensoryFeedback(.warning, trigger: deletedCount)
        .alert("Couldn't delete the transaction", isPresented: $isShowingDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Zentri couldn't save the change. Try again.")
        }
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

    private func startPasting() {
        isPastingSMS = true
    }

    /// Opens the transaction a pasted message became, so the person can check what was read.
    private func openPastedTransaction() {
        guard let id = pastedTransactionID else { return }
        pastedTransactionID = nil
        if model.transaction(id: id) == nil {
            refresh()
        }
        guard let transaction = model.transaction(id: id) else { return }
        selection = TransactionSelection(
            id: id,
            transaction: transaction,
            matchedRuleName: model.ruleName(id: transaction.matchedRuleID)
        )
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

    /// Deletes a row the person swiped away, then tells every screen the store changed. Any bank
    /// message the transaction came from stays in the archive, as it does from the detail.
    private func delete(_ item: TransactionListItem) {
        guard let transaction = model.transaction(id: item.id) else { return }
        Task {
            do {
                try await appState.makeTransactionMutationService().delete(transaction)
                deletedCount += 1
                appState.mutate()
            } catch {
                isShowingDeleteError = true
            }
        }
    }

    /// Saves a manual transaction, then tells every screen the store changed.
    private func add(_ edit: TransactionEdit) async throws {
        try await appState.makeTransactionMutationService().save(edit, existing: nil)
        addedCount += 1
        appState.mutate()
    }
}
