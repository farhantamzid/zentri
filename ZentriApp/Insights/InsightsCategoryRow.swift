import SwiftUI
import ZentriCore

/// One category in the ranked list: its amount, its share of the month, and how it moved since last
/// month. Tapping it opens the category's transactions.
///
/// The row is one button, so VoiceOver reads the name, amount, share, and change as one statement
/// and announces that it can be activated. A category the Transactions list cannot filter by — only
/// uncategorized spend in a catalog with no `Other` — is shown but not tappable.
struct InsightsCategoryRow: View {
    let category: CategoryTotal
    let onSelect: @MainActor (CategoryTotal) -> Void

    var body: some View {
        Button(action: select) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Spacing.sm) {
                    badge
                    Spacer(minLength: Theme.Spacing.sm)
                    figures(alignment: .trailing)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    badge
                    figures(alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(category.categoryID == nil)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Shows this category's transactions"))
        .accessibilityIdentifier("insights.category.row")
    }

    private var badge: some View {
        CategoryBadge(name: category.categoryName, symbolName: category.symbolName, colorToken: category.colorToken)
    }

    private func figures(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                MoneyText(category.amount)
                    .foregroundStyle(Theme.ink)
                Text(category.formattedShare)
                    .foregroundStyle(Theme.secondaryInk)
            }
            .font(.subheadline)
            InsightsChangeText(changePercent: category.changePercent)
        }
    }

    private func select() {
        onSelect(category)
    }
}
