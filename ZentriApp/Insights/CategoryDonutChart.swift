import Charts
import SwiftUI
import ZentriCore

/// The month's categories as a donut, with a slice picked out by touch.
///
/// Touching a slice names the category, its amount, and its share in the middle of the donut and
/// offers a button to its transactions. VoiceOver hears each slice's category and figures, and the
/// chart itself reads as a table of every category for a person who would rather hear the numbers.
/// The slices follow the ranked list's order and colors, and the list beneath names them, so the
/// chart never relies on color alone.
struct CategoryDonutChart: View {
    let categories: [CategoryTotal]
    let onSelect: @MainActor (CategoryTotal) -> Void

    @Environment(\.moneyFormat) private var moneyFormat
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 220
    @State private var selectedAngle: Double?

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            chart
                .frame(height: chartHeight)
                .overlay {
                    CategoryDonutCenterLabel(category: selectedCategory)
                        .frame(maxWidth: chartHeight * 0.45)
                }
                .chartReveal()
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Spending by category")
                .accessibilityValue(categoryTable)
                .accessibilityIdentifier("insights.categoryChart")
                .sensoryFeedback(.selection, trigger: selectedCategory?.categoryName)

            if let selectedCategory, selectedCategory.categoryID != nil {
                Button("Show \(selectedCategory.categoryName) Transactions", systemImage: "list.bullet", action: showSelected)
                .buttonStyle(.bordered)
                .frame(minHeight: Theme.Layout.minimumTapTarget)
                .accessibilityIdentifier("insights.categoryChart.show")
            }
        }
    }

    private var chart: some View {
        Chart(categories, id: \.categoryName) { category in
            SectorMark(
                angle: .value("Amount", amount(category)),
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .cornerRadius(Theme.Spacing.xs)
            .foregroundStyle(Theme.categoryColor(for: category.colorToken))
            .opacity(selectedCategory == nil || selectedCategory?.categoryName == category.categoryName ? 1 : 0.35)
            .accessibilityLabel(Text(category.categoryName))
            .accessibilityValue(Text(figures(category)))
        }
        .chartAngleSelection(value: $selectedAngle)
    }

    /// The category whose slice covers the selected angle.
    ///
    /// The selection is a position along the donut's running total, so the slice is the first one
    /// whose running total reaches it.
    private var selectedCategory: CategoryTotal? {
        guard let selectedAngle else { return nil }
        var runningTotal = 0.0
        for category in categories {
            runningTotal += amount(category)
            if selectedAngle <= runningTotal {
                return category
            }
        }
        return nil
    }

    /// The donut as a table reads it: one category and its figures per line.
    private var categoryTable: String {
        categories
            .map { String(localized: "\($0.categoryName): \(figures($0))") }
            .joined(separator: "\n")
    }

    private func showSelected() {
        guard let selectedCategory else { return }
        onSelect(selectedCategory)
    }

    private func amount(_ category: CategoryTotal) -> Double {
        NSDecimalNumber(decimal: category.amount).doubleValue
    }

    /// A category's amount and share, e.g. "$250.00, 25%".
    private func figures(_ category: CategoryTotal) -> String {
        String(localized: "\(moneyFormat.currencyString(from: category.amount)), \(category.formattedShare)")
    }
}
