import SwiftUI
import ZentriCore

/// The merchants that took the most of the month's spending, with how often they were paid.
///
/// Each row opens Transactions searched for the merchant in the selected month.
struct TopMerchantsCard: View {
    let merchants: [MerchantTotal]
    let onSelect: @MainActor (String) -> Void

    var body: some View {
        SectionCard("Top merchants") {
            if merchants.isEmpty {
                ContentUnavailableView("No merchants to rank", systemImage: "storefront")
            } else {
                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(merchants, id: \.merchant) { merchant in
                        InsightsMerchantRow(merchant: merchant, onSelect: onSelect)
                    }
                }
            }
        }
    }
}

#Preview {
    TopMerchantsCard(
        merchants: [
            MerchantTotal(merchant: "Grab", amount: 750, transactionCount: 14),
            MerchantTotal(merchant: "Starbucks", amount: 250, transactionCount: 1),
        ],
        onSelect: { _ in }
    )
    .padding()
    .background(Theme.canvas)
}
