import Foundation
import SwiftData
import ZentriCore

/// The extra spending an Insights UI test needs on top of ``DashboardFixture``: a second category
/// this month, and a previous month to compare with.
///
/// It is a separate switch so the Overview's and Transactions' fixture numbers stay exactly as their
/// tests assert them. With the dashboard's Starbucks debit (Dining, 250), this month spends 1,000, a
/// quarter of it on Dining; last month spent 800, so Dining is half what it was and Transport is up.
/// Every date comes from the run's own clock — this month's row is stamped now, last month's on its
/// 10th, a day every month has — so the fixture works on any day of any month.
enum InsightsFixture {
    /// This month's Transport debit.
    static let transportThisMonth = Decimal(750)
    /// Last month's Dining debit.
    static let diningLastMonth = Decimal(500)
    /// Last month's Transport debit.
    static let transportLastMonth = Decimal(300)

    /// Inserts the rows into the dashboard fixture's account and saves.
    ///
    /// - Throws: When the dashboard fixture has not been seeded first, or the save fails.
    @MainActor
    static func seed(into context: ModelContext, calendar: Calendar = .current) throws {
        guard let account = try context.fetch(FetchDescriptor<Account>()).first else {
            throw CocoaError(.coderValueNotFound)
        }
        let categories = try context.fetch(FetchDescriptor<ZentriCore.Category>())
        let dining = categories.first { $0.name == "Dining" }
        let transport = categories.first { $0.name == "Transport" }

        let now = Date.now
        let thisMonth = calendar.monthPeriod(containing: now).start
        guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: thisMonth),
              let lastMonthTenth = calendar.date(byAdding: DateComponents(day: 9, hour: 12), to: lastMonth)
        else {
            throw CocoaError(.coderValueNotFound)
        }

        insertDebit(transportThisMonth, merchant: "Grab", category: transport, at: now, account: account, in: context)
        insertDebit(diningLastMonth, merchant: "Noodle Bar", category: dining, at: lastMonthTenth, account: account, in: context)
        insertDebit(transportLastMonth, merchant: "Metro", category: transport, at: lastMonthTenth, account: account, in: context)
        try context.save()
    }

    @MainActor
    private static func insertDebit(
        _ amount: Decimal,
        merchant: String,
        category: ZentriCore.Category?,
        at date: Date,
        account: Account,
        in context: ModelContext
    ) {
        context.insert(
            ZentriCore.Transaction(
                account: account,
                amount: amount,
                direction: .debit,
                occurredAt: date,
                recordedAt: date,
                merchantRaw: merchant,
                merchantDisplay: merchant,
                category: category,
                categorySource: .rule
            )
        )
    }
}
