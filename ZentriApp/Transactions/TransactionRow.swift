import SwiftUI
import ZentriCore

/// One transaction in the list: its category tile, merchant, category and account, and the signed
/// amount, with a Transfer or Manual tag when one applies.
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
        HStack(spacing: Theme.Spacing.md) {
            IconTile(symbolName: item.symbolName, colorToken: item.colorToken)
            TransactionRowDetails(item: item)
            Spacer(minLength: Theme.Spacing.sm)
            TransactionRowAmount(item: item, alignment: .trailing)
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
