import SwiftUI
import ZentriCore

/// The Overview's data cards: the month summary, the activity chart, top categories, recent
/// activity, and ingestion health.
///
/// The cards read only the summary's values, so the screen can be rendered from a preview or a
/// store without the views knowing where the numbers came from.
struct OverviewCards: View {
    private let summary: OverviewSummary

    init(summary: OverviewSummary) {
        self.summary = summary
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            MonthSummaryCard(
                spent: summary.monthSpend,
                received: summary.monthIncome,
                net: summary.monthNet
            )
            SevenDayChart(days: summary.sevenDaySpend)
            TopCategoriesCard(categories: summary.topCategories)
            RecentTransactionsCard(transactions: summary.recentTransactions)
            IngestionHealthCard(health: summary.health)
        }
    }
}
