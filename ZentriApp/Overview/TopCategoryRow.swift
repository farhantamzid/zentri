import SwiftUI
import ZentriCore

/// One category's amount and share of the month's spend.
///
/// The row is one accessibility element, so VoiceOver reads the name, the amount, and the share in
/// the order they appear instead of treating the figure as an unlabelled label.
struct TopCategoryRow: View {
    private let category: CategoryTotal

    init(category: CategoryTotal) {
        self.category = category
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.sm) {
                badge
                Spacer(minLength: Theme.Spacing.sm)
                amounts
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                badge
                amounts
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("overview.category.row")
    }

    private var badge: some View {
        CategoryBadge(
            name: category.categoryName,
            symbolName: category.symbolName,
            colorToken: category.colorToken
        )
    }

    private var amounts: some View {
        VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
            MoneyText(category.amount)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
            Text(shareText)
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
        }
    }

    /// The category's share of the month's spend, e.g. `100%` or `33.3%`.
    ///
    /// The summary reports the share already scaled to 100, so it is divided back down for the
    /// percent format style, which expects a fraction.
    private var shareText: String {
        (category.share / 100).formatted(.percent.precision(.fractionLength(0...1)))
    }
}
