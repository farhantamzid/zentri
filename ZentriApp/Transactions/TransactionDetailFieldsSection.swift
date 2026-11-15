import SwiftUI
import ZentriCore

/// The detail's facts: direction, account, category (changeable here), and the note.
///
/// When the person picks a category, the section offers to file every future transaction from the
/// same merchant there too.
struct TransactionDetailFieldsSection: View {
    @Bindable var model: TransactionDetailModel
    let categories: [TransactionCategoryOption]

    var body: some View {
        Section {
            LabeledContent("Direction") {
                Text(model.transaction.direction.displayName)
            }
            LabeledContent("Account") {
                Text(model.transaction.account.name)
            }
            TransactionCategoryPicker(categoryID: $model.categoryID, categories: categories)
            if model.offersCategoryRule, let category = model.transaction.category {
                TransactionCategoryRuleRow(
                    merchant: model.transaction.merchantDisplay,
                    categoryName: category.name,
                    hasCreatedRule: model.hasCreatedRule,
                    onCreate: createRule
                )
            }
            LabeledContent("Note") {
                Text(model.transaction.note ?? String(localized: "None"))
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func createRule() {
        Task {
            await model.alwaysCategorizeMerchant()
        }
    }
}
