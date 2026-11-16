import SwiftUI
import ZentriCore

/// One category in the donut's legend: its color, its name, and its share of the month. Tapping it
/// opens the category's transactions.
///
/// The row is one button that reads the name, amount, share, and change since last month as one
/// statement and announces that it can be activated. A category the Transactions list cannot filter
/// by — only uncategorized spend in a catalog with no `Other` — is shown but not tappable.
struct InsightsCategoryRow: View {
    let category: CategoryTotal
    let onSelect: @MainActor (CategoryTotal) -> Void

    @Environment(\.moneyFormat) private var moneyFormat

    var body: some View {
        Button(action: select) {
            HStack(spacing: Theme.Spacing.sm) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Theme.categoryColor(for: category.colorToken))
                    .frame(width: 9, height: 9)
                Text(verbatim: category.categoryName)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: Theme.Spacing.xs)
                Text(category.formattedShare)
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondaryInk)
            }
            .font(.subheadline)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle(scale: 0.97))
        .disabled(category.categoryID == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text("\(category.categoryName), \(moneyFormat.currencyString(from: category.amount)), \(category.formattedShare), \(InsightsChangeText(changePercent: category.changePercent).text)")
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Shows this category's transactions"))
        .accessibilityIdentifier("insights.category.row")
    }

    private func select() {
        onSelect(category)
    }
}
