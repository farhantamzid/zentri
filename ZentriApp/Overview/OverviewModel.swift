import Foundation
import Observation
import SwiftData
import ZentriCore

/// The Overview dashboard's data, calculated from the store.
///
/// The model is the only part of the screen that reads SwiftData: it copies each row into a
/// sendable value, then hands the calculators the same inputs the widgets and the Insights tab use,
/// so the three can never disagree. Refreshing never writes to the store, which is what keeps a
/// refresh from asking for the next one through `AppState.dataRevision`.
@MainActor
@Observable
final class OverviewModel {
    /// The number of transactions the recent list shows.
    static let recentTransactionLimit = 5
    /// The number of categories the top list shows.
    static let topCategoryLimit = 3
    /// The number of days the activity chart covers, ending today.
    static let chartDayCount = 7
    /// The number of days the hero's balance line covers, ending today.
    static let historyDayCount = 30

    /// The dashboard's numbers, or `nil` when no active account exists.
    private(set) var summary: OverviewSummary?
    /// How far the last read got, so the screen can tell "not yet read", "read", and "could not
    /// read" apart. A summary of `nil` only means "no active account" while this is `.loaded`.
    private(set) var loadState = OverviewLoadState.loading

    private let reads: OverviewStoreReads
    private let now: () -> Date
    private let calendar: Calendar

    /// Creates the model.
    ///
    /// - Parameters:
    ///   - context: The main-actor context the dashboard reads.
    ///   - now: The instant "today" and "this month" are measured from. A test passes a fixed one.
    ///   - calendar: The calendar that defines days and months. A test passes a fixed one.
    init(context: ModelContext, now: @escaping () -> Date = { .now }, calendar: Calendar = .current) {
        self.reads = OverviewStoreReads(context: context)
        self.now = now
        self.calendar = calendar
    }

    /// Creates a model over supplied store reads, which is how a test makes a read throw.
    init(reads: OverviewStoreReads, now: @escaping () -> Date = { .now }, calendar: Calendar = .current) {
        self.reads = reads
        self.now = now
        self.calendar = calendar
    }

    /// Recalculates the summary from the store.
    ///
    /// A read the screen cannot do without becomes ``OverviewLoadState/failed`` instead of an empty
    /// result. Both reads here carry a claim the dashboard makes — whether there is an account at
    /// all, and whether ingestion is healthy — and an empty answer to either is not neutral: it
    /// tells someone with accounts to finish setup, and reports a store that could not be read as
    /// one where nothing has failed.
    func refresh() {
        do {
            let accounts = try activeAccounts()
            guard !accounts.isEmpty else {
                summary = nil
                loadState = .loaded
                return
            }
            summary = summary(for: accounts, health: try reads.health())
            loadState = .loaded
        } catch {
            summary = nil
            loadState = .failed
        }
    }
}

// MARK: - Summary

private extension OverviewModel {
    /// The dashboard's numbers for the accounts that were read and the health of the messages.
    func summary(for accounts: [Account], health: IngestionHealth) -> OverviewSummary {
        let instant = now()
        let transactions = accounts.flatMap(\.transactions)
        let fallbackCategory = transactions.isEmpty ? nil : fallbackCategory()
        let snapshots = transactions.map { TransactionSnapshot(stored: $0, fallback: fallbackCategory) }
        let month = calculateSummary(transactions: snapshots, in: calendar.monthPeriod(containing: instant))
        let balance = BalanceCalculator.combined(accounts: accounts)

        return OverviewSummary(
            balance: balance,
            asOf: asOf(accounts: accounts) ?? instant,
            todaySpend: calculateSummary(
                transactions: snapshots,
                in: InsightsPeriod(start: calendar.startOfDay(for: instant), end: instant)
            ).totalSpend,
            monthSpend: month.totalSpend,
            monthIncome: month.totalIncome,
            sevenDaySpend: calculateSummary(
                transactions: snapshots,
                in: chartPeriod(endingAt: instant)
            ).dailySpend,
            topCategories: Array(month.categoryTotals.prefix(Self.topCategoryLimit)),
            recentTransactions: recentTransactions(from: snapshots),
            health: health,
            balanceHistory: balanceHistory(ending: balance, at: instant, snapshots: snapshots)
        )
    }
}

// MARK: - Store reads

private extension OverviewModel {
    /// The non-archived accounts, in the order the app lists them.
    ///
    /// Throws rather than reporting no rows when the read itself fails, so the caller can tell a
    /// store with no account from a store it could not open.
    func activeAccounts() throws -> [Account] {
        try reads.accounts()
            .filter { $0.archivedAt == nil }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    /// When the balance was last read: the newest checkpoint the balance actually rests on.
    ///
    /// Only each account's newest checkpoint anchors its balance, so an older checkpoint never
    /// makes the combined balance look more recent than it is.
    func asOf(accounts: [Account]) -> Date? {
        accounts
            .compactMap { account in
                account.checkpoints.max { lhs, rhs in
                    (lhs.recordedAt, lhs.createdAt) < (rhs.recordedAt, rhs.createdAt)
                }?.recordedAt
            }
            .max()
    }

    /// The live `Other` category, which an uncategorized transaction is shown as.
    ///
    /// Reading the catalog instead of `TransactionSnapshot`'s constants means a renamed or restyled
    /// `Other` reaches the dashboard, which is the same rule the widget snapshot follows. A catalog
    /// that cannot be read is not worth failing the whole screen over: this lookup only decides the
    /// symbol and color of uncategorized rows, so it degrades to `TransactionSnapshot`'s defaults
    /// instead of hiding the balance and totals it has already read.
    func fallbackCategory() -> ZentriCore.Category? {
        let categories = (try? reads.categories()) ?? []
        let name = CategorizationService.fallbackCategoryName
        return categories.first { $0.name == name }
    }
}

// MARK: - Periods and totals

private extension OverviewModel {
    /// The seven calendar days ending with today, up to the supplied instant.
    func chartPeriod(endingAt instant: Date) -> InsightsPeriod {
        let today = calendar.startOfDay(for: instant)
        let start = calendar.date(byAdding: .day, value: -(Self.chartDayCount - 1), to: today) ?? today
        return InsightsPeriod(start: start, end: instant)
    }

    func calculateSummary(
        transactions: [TransactionSnapshot],
        in period: InsightsPeriod
    ) -> InsightsSummary {
        InsightsCalculator.summary(transactions: transactions, period: period, calendar: calendar)
    }

    /// The combined balance at the end of each of the last thirty days, oldest first.
    ///
    /// Each day's balance is today's balance with every movement after that day taken back out, so
    /// the line always ends on the balance the hero shows. Transfers move money between the
    /// person's own accounts and count like any other movement, as they do in the balance itself.
    func balanceHistory(ending balance: Decimal, at instant: Date, snapshots: [TransactionSnapshot]) -> [BalancePoint] {
        let today = calendar.startOfDay(for: instant)
        let days = (0..<Self.historyDayCount).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
        guard let first = days.first else { return [] }
        // Net movement per day, for only the days the line covers.
        var netByDay: [Date: Decimal] = [:]
        for snapshot in snapshots where snapshot.occurredAt >= first && snapshot.occurredAt <= instant {
            let day = calendar.startOfDay(for: snapshot.occurredAt)
            let signed = snapshot.direction == .credit ? snapshot.amount : -snapshot.amount
            netByDay[day, default: 0] += signed
        }
        var running = balance
        var points: [BalancePoint] = []
        points.reserveCapacity(days.count)
        for day in days.reversed() {
            points.append(BalancePoint(day: day, balance: running))
            running -= netByDay[day] ?? 0
        }
        return points.reversed()
    }

    /// The newest transactions across the active accounts, transfers included, newest first.
    ///
    /// Transfers stay in the list because they are real movements the dashboard reports; only the
    /// spend and income totals leave them out.
    func recentTransactions(from snapshots: [TransactionSnapshot]) -> [OverviewTransaction] {
        snapshots
            .sorted { lhs, rhs in
                if lhs.occurredAt != rhs.occurredAt {
                    return lhs.occurredAt > rhs.occurredAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .prefix(Self.recentTransactionLimit)
            .map(OverviewTransaction.init(snapshot:))
    }
}
