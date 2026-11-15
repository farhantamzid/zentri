import Charts
import SwiftUI

/// The six months' grouped bars and their summary, drawn from strings formatted beforehand.
struct IncomeExpenseChartContent: View {
    let data: IncomeExpenseChartData

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Chart {
                ForEach(data.months) { month in
                    bar(month: month.month, amount: month.income, amountText: month.incomeText, monthText: month.monthText, series: data.incomeSeries)
                    bar(month: month.month, amount: month.spend, amountText: month.spendText, monthText: month.monthText, series: data.spendSeries)
                }
            }
            .chartForegroundStyleScale([data.incomeSeries: Theme.income, data.spendSeries: Theme.spending])
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
            .frame(height: chartHeight)
            .chartReveal()
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Income and spending, last six months")
            .accessibilityChartDescriptor(data.descriptor)
            .accessibilityIdentifier("insights.incomeExpenseChart")

            Text(data.summary)
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
                .accessibilityIdentifier("insights.incomeExpenseChart.summary")
        }
    }

    private func bar(
        month: Date,
        amount: Decimal,
        amountText: String,
        monthText: String,
        series: String
    ) -> some ChartContent {
        BarMark(
            x: .value("Month", month, unit: .month),
            y: .value("Amount", amount)
        )
        .foregroundStyle(by: .value("Series", series))
        .position(by: .value("Series", series))
        .cornerRadius(Theme.Spacing.xs / 2)
        .accessibilityLabel(Text("\(monthText), \(series)"))
        .accessibilityValue(Text(amountText))
    }
}
