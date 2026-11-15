import Charts
import SwiftUI
import ZentriCore

/// Income beside spending for the six months ending with the selected one.
///
/// The two series differ by position and by the legend's names as well as by color. VoiceOver hears
/// each bar's month, series, and amount, and the chart itself reads as a table — one month per
/// line with what came in and what went out.
struct IncomeExpenseChart: View {
    let months: [MonthlyIncomeExpense]

    @Environment(\.moneyFormat) private var moneyFormat
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 200

    private let incomeSeries = String(localized: "Received")
    private let spendSeries = String(localized: "Spent")

    var body: some View {
        ChartCard("Income and spending") {
            chart
                .frame(height: chartHeight)
                .chartReveal()
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Income and spending, last six months")
                .accessibilityValue(monthsTable)
                .accessibilityIdentifier("insights.incomeExpenseChart")
        }
    }

    private var chart: some View {
        Chart {
            ForEach(months, id: \.month) { month in
                bar(month: month.month, amount: month.income, series: incomeSeries)
                bar(month: month.month, amount: month.spend, series: spendSeries)
            }
        }
        .chartForegroundStyleScale([incomeSeries: Theme.income, spendSeries: Theme.spending])
        .chartLegend(position: .top, alignment: .leading)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
            }
        }
    }

    private func bar(month: Date, amount: Decimal, series: String) -> some ChartContent {
        BarMark(
            x: .value("Month", month, unit: .month),
            y: .value("Amount", amount)
        )
        .foregroundStyle(by: .value("Series", series))
        .position(by: .value("Series", series))
        .cornerRadius(Theme.Spacing.xs / 2)
        .accessibilityLabel(Text("\(monthText(month)), \(series)"))
        .accessibilityValue(Text(moneyFormat.currencyString(from: amount)))
    }

    /// The six months as a table reads them: one month per line, received then spent.
    private var monthsTable: String {
        months
            .map { month in
                String(
                    localized: """
                    \(monthText(month.month)): received \(money(month.income)), spent \(money(month.spend))
                    """
                )
            }
            .joined(separator: "\n")
    }

    private func monthText(_ month: Date) -> String {
        month.formatted(.dateTime.month(.wide).year())
    }

    private func money(_ amount: Decimal) -> String {
        moneyFormat.currencyString(from: amount)
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
