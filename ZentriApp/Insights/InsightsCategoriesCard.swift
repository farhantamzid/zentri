import SwiftUI
import ZentriCore

/// Where the month's spending went: a donut of the categories over a ranked list of them.
///
/// Selecting a slice picks the category out and offers its transactions; every row of the list
/// opens them directly. The list doubles as the donut's legend, with each category's symbol and
/// name, so color is never the only way to tell the slices apart.
struct InsightsCategoriesCard: View {
    let categories: [CategoryTotal]
    let onSelect: @MainActor (CategoryTotal) -> Void

    var body: some View {
        ChartCard("Spending by category") {
            if categories.isEmpty {
                ContentUnavailableView("No spending by category", systemImage: "chart.pie")
            } else {
                VStack(spacing: Theme.Spacing.lg) {
                    CategoryDonutChart(categories: categories, onSelect: onSelect)
                    VStack(spacing: Theme.Spacing.xs) {
                        ForEach(categories, id: \.categoryName) { category in
                            InsightsCategoryRow(category: category, onSelect: onSelect)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    InsightsCategoriesCard(
        categories: [
            CategoryTotal(
                categoryID: UUID(), categoryName: "Transport", symbolName: "car", colorToken: "teal",
                amount: 750, share: 75, transactionCount: 1, previousAmount: 300, changePercent: 150
            ),
            CategoryTotal(
                categoryID: UUID(), categoryName: "Dining", symbolName: "fork.knife", colorToken: "coral",
                amount: 250, share: 25, transactionCount: 1, previousAmount: 500, changePercent: -50
            ),
        ],
        onSelect: { _ in }
    )
    .padding()
    .background(Theme.canvas)
}
