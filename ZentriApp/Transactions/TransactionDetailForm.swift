import SwiftUI
import ZentriCore

/// The detail's sections, or nothing once the transaction is being deleted.
struct TransactionDetailForm: View {
    @Bindable var model: TransactionDetailModel
    let matchedRuleName: String?
    let categories: [TransactionCategoryOption]
    let onDelete: @MainActor () -> Void

    var body: some View {
        if model.isDeleted {
            Color.clear
        } else {
            Form {
                Group {
                    TransactionDetailHeader(model: model)
                    TransactionDetailFieldsSection(model: model, categories: categories)
                    Section {
                        Toggle("Transfer", isOn: $model.isTransfer)
                            .tint(Theme.accent)
                            .accessibilityIdentifier("transactions.detail.transfer")
                    } footer: {
                        Text("Transfers move money between your own accounts, so spending and income totals leave them out.")
                    }
                    TransactionDetailSourceSection(model: model, matchedRuleName: matchedRuleName)
                    TransactionDetailActions(
                        canReprocess: model.canReprocess,
                        isReprocessing: model.isReprocessing,
                        onReprocess: reprocess,
                        onDelete: onDelete
                    )
                }
                .listRowBackground(Theme.glass)
            }
            .scrollContentBackground(.hidden)
            .listSectionSpacing(Theme.Spacing.lg)
        }
    }

    private func reprocess() {
        Task { await model.reprocess() }
    }
}
