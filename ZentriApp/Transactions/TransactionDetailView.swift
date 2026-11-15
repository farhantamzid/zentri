import SwiftUI
import ZentriCore

/// One transaction in full: what moved, where it came from, and the actions on it.
///
/// Category and transfer changes apply at once through the service; Edit opens the editor and
/// Delete asks first. Once a delete starts the stored transaction is gone, so the sheet stops
/// drawing it and closes.
struct TransactionDetailView: View {
    private let matchedRuleName: String?
    private let accounts: [TransactionAccountOption]
    private let categories: [TransactionCategoryOption]

    @State private var model: TransactionDetailModel
    @State private var isEditing = false

    @Environment(\.dismiss) private var dismiss

    init(
        selection: TransactionSelection,
        service: TransactionMutationService,
        accounts: [TransactionAccountOption],
        categories: [TransactionCategoryOption],
        onMutation: @escaping @MainActor () -> Void,
        onReprocess: (@MainActor (RawMessage, UUID?) async -> IngestionOutcome)? = nil
    ) {
        self.matchedRuleName = selection.matchedRuleName
        self.accounts = accounts
        self.categories = categories
        _model = State(
            initialValue: TransactionDetailModel(
                transaction: selection.transaction,
                service: service,
                onMutation: onMutation,
                onReprocess: onReprocess
            )
        )
    }

    var body: some View {
        NavigationStack {
            TransactionDetailForm(
                model: model,
                matchedRuleName: matchedRuleName,
                categories: categories,
                onDelete: delete
            )
            .navigationTitle("Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: close)
                        .accessibilityIdentifier("transactions.detail.done")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit", action: edit)
                        .disabled(model.isDeleted)
                        .accessibilityIdentifier("transactions.detail.edit")
                }
            }
            .sheet(isPresented: $isEditing) {
                TransactionEditorView(
                    title: "Edit Transaction",
                    initial: model.currentEdit,
                    accounts: accounts,
                    categories: categories,
                    onSave: model.save
                )
            }
            .alert("Couldn't save the change", isPresented: $model.isShowingFailure) {
            } message: {
                Text("Zentri couldn't save your changes. Try again.")
            }
            .alert("Reprocessed", item: $model.reprocessMessage) { _ in
            } message: { message in
                Text(message)
            }
            .sensoryFeedback(.success, trigger: model.changeCount)
        }
    }

    private func close() {
        dismiss()
    }

    private func edit() {
        isEditing = true
    }

    private func delete() {
        Task {
            if await model.delete() {
                dismiss()
            }
        }
    }
}
