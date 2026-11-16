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
            TransactionCategoryPicker(categoryID: $model.categoryID, categories: categories)
                .padding(.vertical, Theme.Spacing.xs)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: Theme.Spacing.xs, bottom: 0, trailing: Theme.Spacing.xs))
            if model.offersCategoryRule, let category = model.transaction.category {
                TransactionCategoryRuleRow(
                    merchant: model.transaction.merchantDisplay,
                    categoryName: category.name,
                    hasCreatedRule: model.hasCreatedRule,
                    onCreate: createRule
                )
            }
        } header: {
            GroupHeading("Category")
        }
        .riseIn(delay: 0.24)

        Section {
            LabeledContent("Direction") {
                Text(model.transaction.direction.displayName)
            }
            LabeledContent("Account") {
                Text(model.transaction.account.name)
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
