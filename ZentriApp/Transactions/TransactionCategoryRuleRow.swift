import SwiftUI

/// Offers to turn a one-off category choice into a rule for the merchant, then confirms it.
struct TransactionCategoryRuleRow: View {
    let merchant: String
    let categoryName: String
    let hasCreatedRule: Bool
    let onCreate: @MainActor () -> Void

    var body: some View {
        if hasCreatedRule {
            Label("Future \(merchant) transactions will be categorized as \(categoryName).", systemImage: "checkmark.circle")
                .foregroundStyle(Theme.secondaryInk)
        } else {
            Button(action: onCreate) {
                Label("Always categorize \(merchant) as \(categoryName)", systemImage: "wand.and.stars")
            }
            .frame(minHeight: Theme.Layout.minimumTapTarget)
            .accessibilityIdentifier("transactions.detail.alwaysCategorize")
        }
    }
}
