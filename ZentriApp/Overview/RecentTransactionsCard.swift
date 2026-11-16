import SwiftUI
import ZentriCore

/// The newest transactions across the active accounts, with a way to the full list.
///
/// Each row reads as a single statement — merchant, category, and amount — so VoiceOver announces
/// what a person sees rather than three unrelated labels.
struct RecentTransactionsCard: View {
    private let transactions: [OverviewTransaction]
    private let onSeeAll: (@MainActor () -> Void)?

    init(transactions: [OverviewTransaction], onSeeAll: (@MainActor () -> Void)? = nil) {
        self.transactions = transactions
        self.onSeeAll = onSeeAll
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent activity")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let onSeeAll, !transactions.isEmpty {
                    Button("See all", action: onSeeAll)
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                        .frame(minHeight: Theme.Layout.minimumTapTarget)
                        .accessibilityIdentifier("overview.recent.seeAll")
                }
            }
            if transactions.isEmpty {
                ContentUnavailableView("No transactions yet", systemImage: "list.bullet.rectangle")
            } else {
                ForEach(Array(transactions.prefix(4).enumerated()), id: \.element.id) { index, transaction in
                    RecentTransactionRow(transaction: transaction)
                    if index < min(transactions.count, 4) - 1 {
                        Rectangle()
                            .fill(Theme.hairline)
                            .frame(height: 0.5)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface()
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
        ],
        onSeeAll: {}
    )
    .padding()
    .ambientBackground()
}
