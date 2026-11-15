import SwiftUI
import ZentriCore

/// The detail's headline: the signed amount, the merchant, and when it happened.
struct TransactionDetailHeader: View {
    let transaction: ZentriCore.Transaction

    @Environment(\.moneyFormat) private var moneyFormat

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                MoneyText(signedAmount)
                    .font(.largeTitle.weight(.semibold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(transaction.direction == .credit ? Theme.income : Theme.spending)
                    .accessibilityLabel(Text(spokenAmount))
                    .accessibilityIdentifier("transactions.detail.amount")
                Text(transaction.merchantDisplay)
                    .font(.title3)
                    .foregroundStyle(Theme.ink)
                    .accessibilityLabel(Text(transaction.merchantDisplay))
                    .accessibilityIdentifier("transactions.detail.merchant")
                Text(transaction.occurredAt, format: .dateTime.weekday(.wide).day().month(.wide).year().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
    }

    private var signedAmount: Decimal {
        transaction.direction == .credit ? transaction.amount : -transaction.amount
    }

    private var spokenAmount: String {
        let money = moneyFormat.currencyString(from: transaction.amount)
        return transaction.direction == .credit
            ? String(localized: "received \(money)")
            : String(localized: "spent \(money)")
    }
}
