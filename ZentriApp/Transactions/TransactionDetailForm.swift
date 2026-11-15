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
                TransactionDetailHeader(transaction: model.transaction)
                TransactionDetailFieldsSection(model: model, categories: categories)
                Section {
                    Toggle("Transfer", isOn: $model.isTransfer)
                        .accessibilityIdentifier("transactions.detail.transfer")
                } footer: {
                    Text("Transfers move money between your own accounts, so spending and income totals leave them out.")
                }
                TransactionDetailSourceSection(transaction: model.transaction, matchedRuleName: matchedRuleName)
                if model.canReprocess {
                    TransactionReprocessSection(isReprocessing: model.isReprocessing, onReprocess: reprocess)
                }
                TransactionDeleteSection(onDelete: onDelete)
            }
        }
    }

    private func reprocess() {
        Task { await model.reprocess() }
    }
}
