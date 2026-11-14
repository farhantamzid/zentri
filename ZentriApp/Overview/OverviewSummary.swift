import Foundation
import ZentriCore

/// Everything the Overview dashboard shows, as values.
///
/// The summary is `Sendable` and free of SwiftData, so the view can render it without holding a
/// live model object and a test can compare it field by field.
struct OverviewSummary: Sendable, Equatable {
    /// The combined balance of the active accounts.
    let balance: Decimal
    /// The instant of the newest checkpoint the balance rests on.
    let asOf: Date
    /// Today's spend so far, excluding transfers.
    let todaySpend: Decimal
    /// This calendar month's spend, excluding transfers.
    let monthSpend: Decimal
    /// This calendar month's income, excluding transfers.
    let monthIncome: Decimal
    /// One entry per day for the seven days ending today, including days without spend.
    let sevenDaySpend: [DailySpend]
    /// This month's three largest categories, highest spend first.
    let topCategories: [CategoryTotal]
    /// The five newest transactions across the active accounts, newest first.
    let recentTransactions: [OverviewTransaction]
    /// How message ingestion has been going.
    let health: IngestionHealth

    /// What this month took in less what it paid out.
    var monthNet: Decimal {
        monthIncome - monthSpend
    }
}
