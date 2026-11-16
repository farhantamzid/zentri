import SwiftUI
import ZentriCore

/// The selected month's cards, from the headline totals down to the largest spends.
///
/// The cards read only values, so the screen can be rendered from a preview without a store. A tap
/// on a category or merchant is handed up, and the screen decides where it leads.
struct InsightsCards: View {
    let summary: InsightsSummary
    let observations: [InsightsObservation]
    let largestSpends: [TransactionSnapshot]
    let onSelectCategory: @MainActor (CategoryTotal) -> Void
    let onSelectMerchant: @MainActor (String) -> Void

    var body: some View {
        VStack(spacing: 14) {
            InsightsTotalsCard(spent: summary.totalSpend, received: summary.totalIncome)
                .riseIn(delay: 0.08)
            if !observations.isEmpty {
                InsightsObservationsCard(observations: observations)
                    .riseIn(delay: 0.12)
            }
            // A new month is a new chart: its selection starts empty.
            DailySpendingChart(days: summary.dailySpend, total: summary.totalSpend)
                .id(summary.period.start)
                .riseIn(delay: 0.16)
            InsightsCategoriesCard(categories: summary.categoryTotals, onSelect: onSelectCategory)
                .id(summary.period.start)
                .riseIn(delay: 0.20)
            TopMerchantsCard(merchants: summary.merchantTotals, onSelect: onSelectMerchant)
                .riseIn(delay: 0.24)
            IncomeExpenseChart(months: summary.monthlyIncomeExpense)
                .riseIn(delay: 0.28)
            LargestSpendsCard(spends: largestSpends)
                .riseIn(delay: 0.32)
        }
    }
}
