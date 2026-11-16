import SwiftUI
import ZentriCore

/// One recent transaction: its category tile, merchant, category and time, and signed amount.
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
        HStack(spacing: Theme.Spacing.md) {
            IconTile(symbolName: transaction.symbolName, colorToken: transaction.colorToken)
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(1)
            }
            Spacer(minLength: Theme.Spacing.sm)
            Text(moneyFormat.signedCurrencyString(from: transaction.signedAmount))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(transaction.direction == .credit ? Theme.income : Theme.ink)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("overview.recent.row")
        .accessibilityLabel(transaction.spokenSummary(moneyFormat: moneyFormat))
    }

    /// "Dining · 8:42 AM", or "Transfer · 8:42 AM" for a transfer.
    private var detail: String {
        let time = transaction.occurredAt.formatted(
            Calendar.current.isDateInToday(transaction.occurredAt)
                ? .dateTime.hour().minute()
                : .dateTime.month(.abbreviated).day()
        )
        let kind = transaction.isTransfer ? String(localized: "Transfer") : transaction.categoryName
        return "\(kind) · \(time)"
    }
}
