import SwiftUI
import ZentriCore

/// The combined balance above the list, so an edit's effect on it is visible where it was made.
struct TransactionsBalanceRow: View {
    let balance: Decimal

    @Environment(\.moneyFormat) private var moneyFormat

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Text("Combined balance")
                Spacer()
                MoneyText(balance)
                    .font(.headline)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Combined balance")
                MoneyText(balance)
                    .font(.headline)
            }
        }
        .foregroundStyle(Theme.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Combined balance, \(moneyFormat.currencyString(from: balance))"))
        .accessibilityIdentifier("transactions.balance")
    }
}
