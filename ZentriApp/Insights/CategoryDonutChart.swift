import SwiftUI
import ZentriCore

/// The month's categories as a donut.
///
/// This view only formats the categories once, from the environment's money format, and hands the
/// result to ``CategoryDonutChartContent``; it re-renders when the categories or the format change,
/// never while a person drags around the donut.
struct CategoryDonutChart: View {
    let categories: [CategoryTotal]
    let onSelect: @MainActor (CategoryTotal) -> Void

    @Environment(\.moneyFormat) private var moneyFormat

    var body: some View {
        CategoryDonutChartContent(
            data: CategoryDonutChartData(categories: categories, moneyFormat: moneyFormat),
            onSelect: onSelect
        )
    }
}
