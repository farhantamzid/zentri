import SwiftUI

/// The middle of a transaction row: merchant over its category and account.
struct TransactionRowDetails: View {
    let item: TransactionListItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.merchant)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Text(verbatim: "\(item.categoryName) · \(item.accountName)")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
                .lineLimit(1)
        }
    }
}
