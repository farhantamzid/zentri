import SwiftUI
import ZentriCore

/// The month's largest spends, largest first. Income is left out, so a salary never tops the list.
struct LargestSpendsCard: View {
    let spends: [TransactionSnapshot]

    var body: some View {
        SectionCard("Largest spends") {
            if spends.isEmpty {
                ContentUnavailableView("No spending to rank", systemImage: "list.number")
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(spends) { spend in
                        LargestSpendRow(spend: spend)
                    }
                }
            }
        }
    }
}

#Preview {
    LargestSpendsCard(
        spends: [
            TransactionSnapshot(
                id: UUID(), accountID: UUID(), amount: 1_200, direction: .debit, occurredAt: .now,
                merchant: "Rent", categoryName: "Housing", symbolName: "house", colorToken: "indigo"
            ),
            TransactionSnapshot(
                id: UUID(), accountID: UUID(), amount: 250, direction: .debit, occurredAt: .now,
                merchant: "Starbucks", categoryName: "Dining", symbolName: "fork.knife", colorToken: "coral"
            ),
        ]
    )
    .padding()
    .background(Theme.canvas)
}
