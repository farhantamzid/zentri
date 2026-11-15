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
            let messages = try reads.messages()
            summary = summary(for: accounts, health: health(from: messages))
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
        let snapshots = transactions.map { transactionSnapshot(from: $0, fallback: fallbackCategory) }
        let month = calculateSummary(transactions: snapshots, in: monthPeriod(containing: instant))

        return OverviewSummary(
            balance: BalanceCalculator.combined(accounts: accounts),
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
            health: health
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

    /// The newest messages, stated the three ways the health card reports them.
    func health(from messages: [RawMessage]) -> IngestionHealth {
        IngestionHealth(
            lastMessageAt: messages.map(\.receivedAt).max(),
            lastSuccessAt: messages.filter { $0.status == .parsed }.map(\.ingestedAt).max(),
            failureCount: messages.count { $0.status == .failed }
        )
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

    /// The insights projection of a stored transaction, with its category styling resolved.
    ///
    /// A transaction without a category takes the live `Other` category when the store has one, so
    /// uncategorized spend still appears in the totals with the app's current styling for it.
    func transactionSnapshot(
        from transaction: ZentriCore.Transaction,
        fallback: ZentriCore.Category?
    ) -> TransactionSnapshot {
        guard let category = transaction.category ?? fallback else {
            return TransactionSnapshot(
                id: transaction.id,
                accountID: transaction.account.id,
                amount: transaction.amount,
                direction: transaction.direction,
                occurredAt: transaction.occurredAt,
                merchant: transaction.merchantDisplay,
                isTransfer: transaction.isTransfer
            )
        }
        return TransactionSnapshot(
            id: transaction.id,
            accountID: transaction.account.id,
            amount: transaction.amount,
            direction: transaction.direction,
            occurredAt: transaction.occurredAt,
            merchant: transaction.merchantDisplay,
            categoryID: category.id,
            categoryName: category.name,
            symbolName: category.symbolName,
            colorToken: category.colorToken,
            isTransfer: transaction.isTransfer
        )
    }
}

// MARK: - Periods and totals

private extension OverviewModel {
    /// The current calendar month, from its first instant to its last.
    ///
    /// The month's end is its last instant rather than the next month's first one, which is the
    /// shape `InsightsCalculator` needs to report month-over-month comparisons.
    func monthPeriod(containing instant: Date) -> InsightsPeriod {
        let start = calendar.dateInterval(of: .month, for: instant)?.start ?? calendar.startOfDay(for: instant)
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: start),
              let lastSecond = calendar.date(byAdding: .second, value: -1, to: nextMonth)
        else {
            return InsightsPeriod(start: start, end: instant)
        }
        return InsightsPeriod(start: start, end: lastSecond)
    }

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
