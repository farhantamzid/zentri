import SwiftUI
import ZentriCore

/// The Overview's data cards: the month summary, the activity chart, top categories, recent
/// activity, and ingestion health, each rising in after the one above it.
///
/// The cards read only the summary's values, so the screen can be rendered from a preview or a
/// store without the views knowing where the numbers came from.
struct OverviewCards: View {
    private let summary: OverviewSummary
    private let onSelectCategory: (@MainActor (CategoryTotal) -> Void)?
    private let onSeeAllTransactions: (@MainActor () -> Void)?

    init(
        summary: OverviewSummary,
        onSelectCategory: (@MainActor (CategoryTotal) -> Void)? = nil,
        onSeeAllTransactions: (@MainActor () -> Void)? = nil
    ) {
        self.summary = summary
        self.onSelectCategory = onSelectCategory
        self.onSeeAllTransactions = onSeeAllTransactions
    }

    var body: some View {
        VStack(spacing: 14) {
            MonthSummaryCard(
                spent: summary.monthSpend,
                received: summary.monthIncome,
                net: summary.monthNet
            )
            .riseIn(delay: 0.10)
            SevenDayChart(days: summary.sevenDaySpend)
                .riseIn(delay: 0.15)
            TopCategoriesCard(categories: summary.topCategories, onSelect: onSelectCategory)
                .riseIn(delay: 0.20)
            RecentTransactionsCard(transactions: summary.recentTransactions, onSeeAll: onSeeAllTransactions)
                .riseIn(delay: 0.25)
            IngestionHealthCard(health: summary.health)
                .riseIn(delay: 0.30)
        }
    }
}
