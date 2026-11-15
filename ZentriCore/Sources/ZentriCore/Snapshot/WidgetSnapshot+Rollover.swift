import Foundation

extension WidgetSnapshot {
    /// The snapshot as it should read at a later instant, when no app write has happened since.
    ///
    /// A widget keeps showing the last snapshot the app wrote, and its timeline has a midnight entry
    /// so a new day does not keep yesterday's numbers. Once the day changes, today's spend is zero
    /// and the trend gains an empty day for each day that passed, dropping its oldest days to stay
    /// within ``WidgetSnapshotBuilder/trendDayCount``. Once the month changes, the month's spend,
    /// income, and top categories are zero too. The balance and the recent transactions do not
    /// depend on the date, so they are kept.
    ///
    /// - Parameters:
    ///   - date: The instant the widget is drawing for.
    ///   - calendar: The calendar that defines days and months.
    /// - Returns: The snapshot for `date`; unchanged when `date` is on the day it was generated or
    ///   earlier.
    public func rolledOver(to date: Date, calendar: Calendar) -> WidgetSnapshot {
        let generatedDay = calendar.startOfDay(for: generatedAt)
        let day = calendar.startOfDay(for: date)
        guard day > generatedDay else { return self }

        var rolled = self
        rolled.todaySpend = "0"
        if !calendar.isDate(day, equalTo: generatedDay, toGranularity: .month) {
            rolled.monthSpend = "0"
            rolled.monthIncome = "0"
            rolled.topCategories = []
        }

        if let lastDay = trend.last.map({ calendar.startOfDay(for: $0.date) }) {
            var points = trend
            // A snapshot weeks old only needs the window's worth of empty days, not one per day.
            let windowStart = calendar.date(
                byAdding: .day, value: -(WidgetSnapshotBuilder.trendDayCount - 1), to: day
            ) ?? day
            let dayAfterLast = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? day
            var next: Date? = max(dayAfterLast, windowStart)
            while let current = next, current <= day {
                points.append(TrendPoint(date: current, spend: "0"))
                next = calendar.date(byAdding: .day, value: 1, to: current)
            }
            rolled.trend = Array(points.suffix(WidgetSnapshotBuilder.trendDayCount))
        }
        return rolled
    }
}
