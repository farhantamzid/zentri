import SwiftUI
import ZentriCore

/// This month's three largest spending categories, each with a bar of its share.
///
/// Tapping a category opens its transactions. Each row reads as one statement — category, amount,
/// and share — so VoiceOver does not have to relate three separate labels. Color never carries the
/// meaning alone: the symbol and the name do.
struct TopCategoriesCard: View {
    private let categories: [CategoryTotal]
    private let onSelect: (@MainActor (CategoryTotal) -> Void)?

    init(categories: [CategoryTotal], onSelect: (@MainActor (CategoryTotal) -> Void)? = nil) {
        self.categories = categories
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Top categories")
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 6)
            if categories.isEmpty {
                ContentUnavailableView("No spending yet this month", systemImage: "chart.pie")
            } else {
                let largest = categories.map(\.share).max() ?? 100
                ForEach(Array(categories.enumerated()), id: \.element.categoryName) { index, category in
                    TopCategoryRow(
                        category: category,
                        barFraction: largest > 0 ? NSDecimalNumber(decimal: category.share / largest).doubleValue : 0,
                        delay: 0.2 + Double(index) * 0.08,
                        onSelect: category.categoryID == nil ? nil : onSelect.map { action in { action(category) } }
                    )
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface()
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
        ]
    )
    .padding()
    .ambientBackground()
}
