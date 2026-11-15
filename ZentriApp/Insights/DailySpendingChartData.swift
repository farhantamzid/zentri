import Foundation
import ZentriCore

/// Everything the daily spending chart shows, formatted once per change in the month's data.
///
/// The chart redraws on every frame of a drag, so the money and date strings, the spoken summary,
/// and the audio graph are built here rather than in its body, and a touched instant finds its day
/// through a lookup instead of a search.
struct DailySpendingChartData {
    /// One day's bar.
    struct Point: Identifiable {
        /// The first instant of the day.
        let date: Date
        let amount: Decimal
        /// The amount as the bar's callout and VoiceOver read it.
        let amountText: String
        /// The day as VoiceOver reads it, e.g. "Sunday, Nov 15".
        let dayText: String

        var id: Date { date }
    }

    let points: [Point]
    /// The month in a sentence: its total and its highest day.
    let summary: String
    let descriptor: InsightsChartDescriptor
    private let indexByDay: [Date: Int]
    private let calendar: Calendar

    init(days: [DailySpend], total: Decimal, moneyFormat: MoneyFormat, locale: Locale, calendar: Calendar) {
        let points = days.map { day in
            Point(
                date: day.date,
                amount: day.amount,
                amountText: moneyFormat.currencyString(from: day.amount),
                dayText: day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().locale(locale))
            )
        }
        self.points = points
        self.calendar = calendar
        indexByDay = Dictionary(
            points.enumerated().map { (calendar.startOfDay(for: $0.element.date), $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )

        let totalText = moneyFormat.currencyString(from: total)
        // The earliest of equal highest days, as the peak-day observation names it.
        let highest = points.reduce(nil as Point?) { best, point in
            guard let best else { return point }
            return point.amount > best.amount ? point : best
        }
        if let highest, highest.amount > 0 {
            summary = String(localized: "Total \(totalText). Highest: \(highest.amountText) on \(highest.dayText).")
        } else {
            summary = String(localized: "Total \(totalText)")
        }

        descriptor = InsightsChartDescriptor(
            title: String(localized: "Daily spending"),
            summary: summary,
            xAxisTitle: String(localized: "Day"),
            categories: points.map(\.dayText),
            yAxisTitle: String(localized: "Spent"),
            series: [
                InsightsChartDescriptor.Series(
                    name: String(localized: "Spent"),
                    points: points.map {
                        InsightsChartDescriptor.Point(
                            category: $0.dayText,
                            value: NSDecimalNumber(decimal: $0.amount).doubleValue,
                            valueText: $0.amountText
                        )
                    }
                ),
            ],
            moneyFormat: moneyFormat
        )
    }

    /// The day that contains the instant, if the month has it.
    func point(containing instant: Date) -> Point? {
        indexByDay[calendar.startOfDay(for: instant)].map { points[$0] }
    }
}
