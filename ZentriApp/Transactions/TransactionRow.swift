import SwiftUI
import ZentriCore

/// One transaction in the list: merchant, category, account, and the signed amount in its
/// direction's color, with Transfer and Manual badges when they apply.
///
/// The row is one accessibility element whose summary spells out the direction, because neither
/// the minus sign nor the color says "spent" to a listener.
struct TransactionRow: View {
    private let item: TransactionListItem

    @Environment(\.moneyFormat) private var moneyFormat

    init(item: TransactionListItem) {
        self.item = item
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                TransactionRowDetails(item: item)
                Spacer(minLength: Theme.Spacing.sm)
                TransactionRowAmount(item: item, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                TransactionRowDetails(item: item)
                TransactionRowAmount(item: item, alignment: .leading)
            }
        }
        .frame(minHeight: Theme.Layout.minimumTapTarget)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenSummary)
        .accessibilityIdentifier("transactions.row")
    }

    /// Merchant, category, account, the movement in words, then any badges.
    private var spokenSummary: String {
        let money = moneyFormat.currencyString(from: item.amount)
        var parts = [
            item.merchant,
            item.categoryName,
            item.accountName,
            item.direction == .credit ? String(localized: "received \(money)") : String(localized: "spent \(money)"),
        ]
        if item.isTransfer {
            parts.append(String(localized: "Transfer"))
        }
        if item.isManual {
            parts.append(String(localized: "Manual"))
        }
        return parts.joined(separator: ", ")
    }
}
