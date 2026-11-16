import SwiftUI
import ZentriCore

/// The detail's headline: the category's tile, the signed amount, the merchant, and when it
/// happened, centered over the sheet.
struct TransactionDetailHeader: View {
    let transaction: ZentriCore.Transaction

    @Environment(\.moneyFormat) private var moneyFormat

    var body: some View {
        Section {
            VStack(spacing: Theme.Spacing.xs) {
                IconTile(
                    symbolName: transaction.category?.symbolName ?? "ellipsis",
                    colorToken: transaction.category?.colorToken ?? "slate",
                    size: 68
                )
                .padding(.bottom, Theme.Spacing.sm)
                Text(moneyFormat.signedCurrencyString(from: signedAmount))
                    .font(.system(size: 48, weight: .semibold))
                    .kerning(-1.4)
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(transaction.direction == .credit ? Theme.income : Theme.spending)
                    .accessibilityLabel(Text(spokenAmount))
                    .accessibilityIdentifier("transactions.detail.amount")
                    .riseIn(delay: 0.12)
                Text(transaction.merchantDisplay)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel(Text(transaction.merchantDisplay))
                    .accessibilityIdentifier("transactions.detail.merchant")
                    .riseIn(delay: 0.17)
                Text(transaction.occurredAt, format: .dateTime.weekday(.wide).day().month(.wide).year().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
                    .multilineTextAlignment(.center)
                    .riseIn(delay: 0.2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xs)
        }
        .listRowBackground(Color.clear)
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
