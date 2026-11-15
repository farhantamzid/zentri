import SwiftUI

/// The left side of a transaction row: merchant over its category and account.
struct TransactionRowDetails: View {
    let item: TransactionListItem

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(item.merchant)
                .font(.body)
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
            HStack(spacing: Theme.Spacing.sm) {
                CategoryBadge(name: item.categoryName, symbolName: item.symbolName, colorToken: item.colorToken)
                Text(item.accountName)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(1)
            }
        }
    }
}
