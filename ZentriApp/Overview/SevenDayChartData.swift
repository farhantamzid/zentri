import Foundation
import ZentriCore

/// What the Overview's week chart says to VoiceOver, formatted once per render.
///
/// The chart offers two alternatives to its shape: an audio graph and data table through
/// ``descriptor`` (VoiceOver's Chart Details), the same form the Insights charts use, and the
/// week as text lines — a total, then each day and its spend — which the chart also carries as its
/// accessibility value.
struct SevenDayChartData {
    /// The week as a table reads it: a total, then one day and its spend per line.
    let weekTable: String
    let descriptor: InsightsChartDescriptor

    init(days: [DailySpend], moneyFormat: MoneyFormat, locale: Locale) {
        let rows = days.map { day in
            (
                day: day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().locale(locale)),
                amount: day.amount,
                amountText: moneyFormat.currencyString(from: day.amount)
            )
        }
        let total = days.reduce(Decimal.zero) { $0 + $1.amount }
        let summary = String(localized: "Total \(moneyFormat.currencyString(from: total))")
        weekTable = ([summary] + rows.map { String(localized: "\($0.day): \($0.amountText)") })
            .joined(separator: "\n")

        descriptor = InsightsChartDescriptor(
            title: String(localized: "Spending, last seven days"),
            summary: summary,
            xAxisTitle: String(localized: "Day"),
            categories: rows.map(\.day),
            yAxisTitle: String(localized: "Spent"),
            series: [
                InsightsChartDescriptor.Series(
                    name: String(localized: "Spent"),
                    points: rows.map {
                        InsightsChartDescriptor.Point(
                            category: $0.day,
                            value: NSDecimalNumber(decimal: $0.amount).doubleValue,
                            valueText: $0.amountText
                        )
                    }
                ),
            ],
            moneyFormat: moneyFormat
        )
    }
}
