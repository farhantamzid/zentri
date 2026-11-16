import SwiftUI
import ZentriCore

/// Where the month's spending went: a donut of the categories beside a legend of them.
///
/// Selecting a slice picks the category out and offers its transactions; every legend row opens
/// them directly. The legend names each category beside its color, so color is never the only way
/// to tell the slices apart. At large text sizes the legend moves under the donut.
struct InsightsCategoriesCard: View {
    let categories: [CategoryTotal]
    let onSelect: @MainActor (CategoryTotal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Categories")
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            if categories.isEmpty {
                ContentUnavailableView("No spending by category", systemImage: "chart.pie")
            } else {
                CategoryDonutChart(categories: categories, onSelect: onSelect) {
                    VStack(spacing: 2) {
                        ForEach(categories, id: \.categoryName) { category in
                            InsightsCategoryRow(category: category, onSelect: onSelect)
                        }
                    }
                }
            }
        }
        .glassCard()
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
    .ambientBackground()
}
