import SwiftUI
import ZentriCore

/// The newest transactions across the active accounts.
///
/// Each row reads as a single statement — merchant, category, and amount — so VoiceOver announces
/// what a person sees rather than three unrelated labels.
struct RecentTransactionsCard: View {
    private let transactions: [OverviewTransaction]

    init(transactions: [OverviewTransaction]) {
        self.transactions = transactions
    }

    var body: some View {
        SectionCard("Recent activity") {
            if transactions.isEmpty {
                ContentUnavailableView(
                    "No transactions yet",
                    systemImage: "list.bullet.rectangle"
                )
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(transactions) { transaction in
                        RecentTransactionRow(transaction: transaction)
                    }
                }
            }
        }
    }
}

#Preview {
    RecentTransactionsCard(
        transactions: [
            OverviewTransaction(
                id: UUID(), merchant: "Starbucks", categoryName: "Dining", symbolName: "fork.knife",
                colorToken: "coral", amount: 12.5, direction: .debit, occurredAt: .now, isTransfer: false
            ),
            OverviewTransaction(
                id: UUID(), merchant: "Employer", categoryName: "Income", symbolName: "arrow.up.right",
                colorToken: "green", amount: 5_000, direction: .credit, occurredAt: .now, isTransfer: false
            ),
        ]
    )
    .padding()
    .background(Theme.canvas)
}
