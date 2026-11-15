import Charts
import SwiftUI
import ZentriCore

/// Income beside spending for the six months ending with the selected one.
///
/// The two series differ by position and by the legend's names as well as by color. Each bar
/// announces its month, series, and amount, the chart offers VoiceOver an audio graph and data
/// table, and the summary beneath it states the newest month in words.
struct IncomeExpenseChart: View {
    let months: [MonthlyIncomeExpense]

    @Environment(\.moneyFormat) private var moneyFormat
    @Environment(\.locale) private var locale

    var body: some View {
        ChartCard("Income and spending") {
            IncomeExpenseChartContent(
                data: IncomeExpenseChartData(months: months, moneyFormat: moneyFormat, locale: locale)
            )
        }
    }
}

#Preview {
    IncomeExpenseChart(
        months: (0..<6).map { offset in
            MonthlyIncomeExpense(
                month: Calendar.current.date(byAdding: .month, value: offset - 5, to: .now) ?? .now,
                income: 5_000,
                spend: Decimal(2_000 + offset * 300)
            )
        }
    )
    .padding()
    .background(Theme.canvas)
}
