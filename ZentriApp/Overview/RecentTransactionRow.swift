import SwiftUI
import ZentriCore

/// One recent transaction: merchant, category, and signed amount.
///
/// The row is one accessibility element that says whether the money arrived or left, because the
/// minus sign the amount carries is not what a listener would call it, and the row's direction color
/// is not available to them at all. A transfer says so, as its tag does on screen.
struct RecentTransactionRow: View {
    private let transaction: OverviewTransaction

    @Environment(\.moneyFormat) private var moneyFormat

    init(transaction: OverviewTransaction) {
        self.transaction = transaction
    }

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
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("overview.recent.row")
        .accessibilityLabel(transaction.spokenSummary(moneyFormat: moneyFormat))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(transaction.merchant)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            HStack(spacing: Theme.Spacing.xs) {
                CategoryBadge(
                    name: transaction.categoryName,
                    symbolName: transaction.symbolName,
                    colorToken: transaction.colorToken
                )
                if transaction.isTransfer {
                    Text("Transfer")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
        }
    }

    private var amount: some View {
        MoneyText(transaction.signedAmount)
            .font(.subheadline)
            .foregroundStyle(transaction.direction == .credit ? Theme.income : Theme.ink)
    }
}
