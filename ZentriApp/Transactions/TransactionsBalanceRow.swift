import SwiftUI
import ZentriCore

/// The combined balance above the list, so an edit's effect on it is visible where it was made.
/// The figure rolls to its new value after an edit.
struct TransactionsBalanceRow: View {
    let balance: Decimal

    @Environment(\.moneyFormat) private var moneyFormat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            Text("Combined balance")
                .foregroundStyle(Theme.secondaryInk)
            Spacer()
            MoneyText(balance)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.ink)
                .contentTransition(reduceMotion ? .identity : .numericText(value: NSDecimalNumber(decimal: balance).doubleValue))
                .animation(Theme.Motion.settle, value: balance)
        }
        .font(.subheadline)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Combined balance, \(moneyFormat.currencyString(from: balance))"))
        .accessibilityIdentifier("transactions.balance")
    }
}
