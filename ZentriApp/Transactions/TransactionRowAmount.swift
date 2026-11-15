import SwiftUI

/// The right side of a transaction row: the signed amount in its direction's color, and the badges.
///
/// The sign and the badges' words carry the meaning, so the color is never the only cue.
struct TransactionRowAmount: View {
    let item: TransactionListItem
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: Theme.Spacing.xs) {
            MoneyText(item.signedAmount)
                .font(.body.weight(.semibold))
                .foregroundStyle(item.direction == .credit ? Theme.income : Theme.spending)
            if item.isTransfer {
                TransactionBadge(title: "Transfer", systemImage: "arrow.left.arrow.right")
            }
            if item.isManual {
                TransactionBadge(title: "Manual", systemImage: "hand.point.up.left")
            }
        }
    }
}
