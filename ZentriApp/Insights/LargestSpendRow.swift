import SwiftUI
import ZentriCore

/// One large spend: the merchant, its category and day, and the amount.
///
/// The row is one accessibility element, read in the order it appears.
struct LargestSpendRow: View {
    let spend: TransactionSnapshot

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.sm) {
                details
                Spacer(minLength: Theme.Spacing.sm)
                amount
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                details
                amount
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("insights.largestSpend.row")
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(spend.merchant)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
            HStack(spacing: Theme.Spacing.sm) {
                CategoryBadge(name: spend.categoryName, symbolName: spend.symbolName, colorToken: spend.colorToken)
                Text(spend.occurredAt, format: .dateTime.month(.abbreviated).day())
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
    }

    private var amount: some View {
        MoneyText(spend.amount)
            .font(.subheadline)
            .foregroundStyle(Theme.ink)
    }
}
