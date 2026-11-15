import SwiftUI
import ZentriCore

/// One merchant: its name, how many times it was paid, and how much. Tapping it opens its
/// transactions.
///
/// The row is one button, so VoiceOver reads the merchant and its figures as one statement.
struct InsightsMerchantRow: View {
    let merchant: MerchantTotal
    let onSelect: @MainActor (String) -> Void

    var body: some View {
        Button(action: select) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Spacing.sm) {
                    details
                    Spacer(minLength: Theme.Spacing.sm)
                    amount
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    details
                    amount
                }
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Shows this merchant's transactions"))
        .accessibilityIdentifier("insights.merchant.row")
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
            Text(merchant.merchant)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
            Text("^[\(merchant.transactionCount) transaction](inflect: true)")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
        }
    }

    private var amount: some View {
        MoneyText(merchant.amount)
            .font(.subheadline)
            .foregroundStyle(Theme.ink)
    }

    private func select() {
        onSelect(merchant.merchant)
    }
}
