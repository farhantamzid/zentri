import Foundation
import ZentriCore

extension Calendar {
    /// The calendar month that contains the instant, from its first instant to its last.
    ///
    /// The month's end is its last instant rather than the next month's first one, which is the
    /// shape `InsightsCalculator` needs to report month-over-month comparisons. The Overview's month
    /// totals and the Insights month both come from here, so they always cover the same range.
    func monthPeriod(containing instant: Date) -> InsightsPeriod {
        let start = dateInterval(of: .month, for: instant)?.start ?? startOfDay(for: instant)
        guard let nextMonth = date(byAdding: .month, value: 1, to: start),
              let lastSecond = date(byAdding: .second, value: -1, to: nextMonth)
        else {
            return InsightsPeriod(start: start, end: instant)
        }
        return InsightsPeriod(start: start, end: lastSecond)
    }
}
