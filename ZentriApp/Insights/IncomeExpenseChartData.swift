import Foundation
import ZentriCore

/// Everything the six-month chart shows, formatted once per change in its months.
struct IncomeExpenseChartData {
    /// One month's pair of bars.
    struct Month: Identifiable {
        /// The first instant of the month.
        let month: Date
        let income: Decimal
        let spend: Decimal
        /// The month as VoiceOver reads it, e.g. "November 2026".
        let monthText: String
        let incomeText: String
        let spendText: String

        var id: Date { month }
    }

    let months: [Month]
    /// The legend's and VoiceOver's name for money that came in.
    let incomeSeries = String(localized: "Received")
    /// The legend's and VoiceOver's name for money that went out.
    let spendSeries = String(localized: "Spent")
    /// The newest month in a sentence: what came in and what went out.
    let summary: String
    let descriptor: InsightsChartDescriptor

    init(months: [MonthlyIncomeExpense], moneyFormat: MoneyFormat, locale: Locale) {
        let months = months.map { month in
            Month(
                month: month.month,
                income: month.income,
                spend: month.spend,
                monthText: month.month.formatted(.dateTime.month(.wide).year().locale(locale)),
                incomeText: moneyFormat.currencyString(from: month.income),
                spendText: moneyFormat.currencyString(from: month.spend)
            )
        }
        self.months = months

        if let newest = months.last {
            summary = String(localized: "\(newest.monthText): received \(newest.incomeText), spent \(newest.spendText)")
        } else {
            summary = ""
        }

        descriptor = InsightsChartDescriptor(
            title: String(localized: "Income and spending"),
            summary: summary,
            xAxisTitle: String(localized: "Month"),
            categories: months.map(\.monthText),
            yAxisTitle: String(localized: "Amount"),
            series: [
                InsightsChartDescriptor.Series(
                    name: incomeSeries,
                    points: months.map {
                        InsightsChartDescriptor.Point(
                            category: $0.monthText,
                            value: NSDecimalNumber(decimal: $0.income).doubleValue,
                            valueText: $0.incomeText
                        )
                    }
                ),
                InsightsChartDescriptor.Series(
                    name: spendSeries,
                    points: months.map {
                        InsightsChartDescriptor.Point(
                            category: $0.monthText,
                            value: NSDecimalNumber(decimal: $0.spend).doubleValue,
                            valueText: $0.spendText
                        )
                    }
                ),
            ],
            moneyFormat: moneyFormat
        )
    }
}
