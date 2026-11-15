import Foundation

extension WidgetSnapshot {
    /// A plausible snapshot for widget previews, the widget gallery, and the redacted placeholder.
    ///
    /// It is never written to the App Group: it only gives a widget the shape of real data — a
    /// balance, a month of trend, six recent rows, and four categories — when there is no snapshot
    /// to draw or the system asks for a preview.
    ///
    /// - Parameters:
    ///   - now: The instant the sample describes; its trend ends on this day.
    ///   - calendar: The calendar that defines the trend's days.
    public static func sample(now: Date = .now, calendar: Calendar = .current) -> WidgetSnapshot {
        let today = calendar.startOfDay(for: now)
        let dailySpend = [
            "12.5", "0", "42", "8.75", "0", "19.99", "7.4", "64.2", "3.5", "0",
            "28", "15.25", "0", "9.9", "51.3", "22", "0", "6.75", "33.4", "11",
            "0", "48.6", "17.2", "5", "0", "26.8", "13.45", "39.9", "0", "82.4",
        ]
        let trend = dailySpend.enumerated().map { offset, spend in
            TrendPoint(
                date: calendar.date(byAdding: .day, value: offset - (dailySpend.count - 1), to: today) ?? today,
                spend: spend
            )
        }
        let recent: [(String, String, String, String, String, Direction)] = [
            ("Daily Grind", "Dining", "fork.knife", "coral", "4.8", .debit),
            ("Salary", "Income", "arrow.down.left", "green", "5200", .credit),
            ("Metro Card", "Transport", "tram", "teal", "25", .debit),
            ("Green Grocer", "Groceries", "cart", "green", "63.15", .debit),
            ("Bookshop", "Shopping", "bag", "violet", "18.99", .debit),
            ("Pharmacy", "Health", "cross.case", "cyan", "12.4", .debit),
        ]
        return WidgetSnapshot(
            generatedAt: now,
            currencyCode: "USD",
            numberGrouping: .western,
            balance: "12845.67",
            balanceAsOf: now,
            todaySpend: "82.4",
            monthSpend: "1284.5",
            monthIncome: "5200",
            trend: trend,
            recentTransactions: recent.enumerated().map { index, row in
                RecentTransaction(
                    id: UUID(),
                    merchant: row.0,
                    categoryName: row.1,
                    symbolName: row.2,
                    colorToken: row.3,
                    amount: row.4,
                    direction: row.5,
                    occurredAt: now.addingTimeInterval(TimeInterval(-index * 5_400))
                )
            },
            topCategories: [
                TopCategory(name: "Groceries", symbolName: "cart", colorToken: "green", amount: "412.3", share: "32.1"),
                TopCategory(name: "Dining", symbolName: "fork.knife", colorToken: "coral", amount: "286.4", share: "22.3"),
                TopCategory(name: "Transport", symbolName: "tram", colorToken: "teal", amount: "190", share: "14.8"),
                TopCategory(name: "Shopping", symbolName: "bag", colorToken: "violet", amount: "142.75", share: "11.1"),
            ]
        )
    }
}
