import SwiftUI

/// The right side of a transaction row: the signed amount, and a Transfer or Manual tag under it.
///
/// The sign and the tags' words carry the meaning, so the color is never the only cue.
struct TransactionRowAmount: View {
    let item: TransactionListItem
    let alignment: HorizontalAlignment

    @Environment(\.moneyFormat) private var moneyFormat

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(moneyFormat.signedCurrencyString(from: item.signedAmount))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(item.direction == .credit ? Theme.income : Theme.ink)
            if item.isTransfer {
                Text("Transfer")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
            } else if item.isManual {
                Text("Manual")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
    }
}
