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
        VStack(spacing: Theme.Spacing.lg) {
            InsightsTotalsCard(spent: summary.totalSpend, received: summary.totalIncome)
            if !observations.isEmpty {
                InsightsObservationsCard(observations: observations)
            }
            DailySpendingChart(days: summary.dailySpend, total: summary.totalSpend)
            InsightsCategoriesCard(categories: summary.categoryTotals, onSelect: onSelectCategory)
            TopMerchantsCard(merchants: summary.merchantTotals, onSelect: onSelectMerchant)
            IncomeExpenseChart(months: summary.monthlyIncomeExpense)
            LargestSpendsCard(spends: largestSpends)
        }
    }
}
