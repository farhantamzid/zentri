import SwiftUI
import ZentriCore

/// This month's three largest spending categories.
///
/// Each row reads as one statement — category, amount, and share — so VoiceOver does not have to
/// relate three separate labels. Color never carries the meaning alone: the symbol and the name do.
struct TopCategoriesCard: View {
    private let categories: [CategoryTotal]

    init(categories: [CategoryTotal]) {
        self.categories = categories
    }

    var body: some View {
        SectionCard("Top categories") {
            if categories.isEmpty {
                ContentUnavailableView(
                    "No spending yet this month",
                    systemImage: "chart.pie"
                )
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(categories, id: \.categoryName) { category in
                        TopCategoryRow(category: category)
                    }
                }
            }
        }
    }
}

#Preview {
    TopCategoriesCard(
        categories: [
            CategoryTotal(
                categoryID: nil, categoryName: "Dining", symbolName: "fork.knife", colorToken: "coral",
                amount: 420, share: 62.5, transactionCount: 7, previousAmount: 300, changePercent: 40
            ),
            CategoryTotal(
                categoryID: nil, categoryName: "Transport", symbolName: "car", colorToken: "teal",
                amount: 180, share: 26.79, transactionCount: 4, previousAmount: 200, changePercent: -10
            ),
            CategoryTotal(
                categoryID: nil, categoryName: "Groceries", symbolName: "cart", colorToken: "green",
                amount: 72, share: 10.71, transactionCount: 2, previousAmount: 0, changePercent: nil
            ),
        ]
    )
    .padding()
    .background(Theme.canvas)
}
