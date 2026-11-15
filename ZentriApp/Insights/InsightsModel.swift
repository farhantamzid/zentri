import Foundation
import Observation
import SwiftData
import ZentriCore

/// The Insights screen's data: one calendar month's summary, its largest spends, and its
/// observations.
///
/// The model is the only part of the screen that reads SwiftData. It maps the active accounts'
/// transactions the same way the Overview does and hands them to the same calculator, so this
/// month's totals here and on the Overview always agree. Refreshing never writes to the store, which
/// keeps a refresh from asking for the next one through `AppState.dataRevision`.
///
/// The selected month never moves past the month containing `now`: a month that has not started has
/// nothing to show.
@MainActor
@Observable
final class InsightsModel {
    /// The first instant of the month the screen shows.
    private(set) var selectedMonth: Date
    /// The selected month's summary, or `nil` before the first read and after a failed one.
    private(set) var summary: InsightsSummary?
    /// The selected month's largest spends, largest first; income never ranks here.
    private(set) var largestSpends: [TransactionSnapshot] = []
    /// The selected month's observations, in the order the screen lists them.
    private(set) var observations: [InsightsObservation] = []
    /// How far the last read got. A `nil` summary only means "not yet read" while this is
    /// `.loading`; once `.failed`, the store could not be read.
    private(set) var loadState = InsightsLoadState.loading

    private let reads: InsightsStoreReads
    private let now: () -> Date
    private let calendar: Calendar

    /// Creates the model over the supplied context.
    ///
    /// - Parameters:
    ///   - context: The main-actor context the screen reads.
    ///   - now: The instant "this month" and "the days so far" are measured from. A test passes a
    ///     fixed one.
    ///   - calendar: The calendar that defines days and months. A test passes a fixed one.
    convenience init(context: ModelContext, now: @escaping () -> Date = { .now }, calendar: Calendar = .current) {
        self.init(reads: InsightsStoreReads(context: context), now: now, calendar: calendar)
    }

    /// Creates the model over supplied store reads, which is how a test makes a read throw.
    init(reads: InsightsStoreReads, now: @escaping () -> Date = { .now }, calendar: Calendar = .current) {
        self.reads = reads
        self.now = now
        self.calendar = calendar
        self.selectedMonth = calendar.monthPeriod(containing: now()).start
    }

    /// Whether the selected month is the month containing `now`, which is as far forward as the
    /// selection goes.
    var isShowingThisMonth: Bool {
        selectedMonth >= currentMonthStart
    }

    /// Whether the selected month has any income or spend to describe.
    var hasActivity: Bool {
        (summary?.transactionCount ?? 0) > 0
    }

    /// Recalculates the selected month from the store.
    ///
    /// A failed read becomes ``InsightsLoadState/failed`` with nothing to show, never an empty
    /// month. The category catalog only decides how uncategorized rows look, so a failure to read it
    /// degrades to the default `Other` styling instead of hiding the month.
    func refresh() {
        do {
            let snapshots = try transactionSnapshots()
            load(snapshots)
            loadState = .loaded
        } catch {
            summary = nil
            largestSpends = []
            observations = []
            loadState = .failed
        }
    }

    /// Shows the month before the selected one.
    func previousMonth() {
        select(month(adding: -1))
    }

    /// Shows the month after the selected one, unless the selected month is this month.
    func nextMonth() {
        guard !isShowingThisMonth else { return }
        select(month(adding: 1))
    }

    /// Shows the month containing `now`.
    func thisMonth() {
        select(currentMonthStart)
    }

    /// The Transactions filter that lists what a category's total is made of: the category's spends
    /// in the selected month.
    ///
    /// - Returns: The filter, or `nil` when the category has no identity to filter by, which only
    ///   happens for uncategorized spend in a store whose catalog has no `Other` category.
    func transactionFilter(for category: CategoryTotal) -> TransactionFilter? {
        guard let categoryID = category.categoryID else { return nil }
        return TransactionFilter(categoryID: categoryID, direction: .debit, dateRange: selectedRange)
    }

    /// The Transactions filter that lists a merchant's spends in the selected month, by searching for
    /// its name.
    func transactionFilter(forMerchant merchant: String) -> TransactionFilter {
        TransactionFilter(direction: .debit, searchText: merchant, dateRange: selectedRange)
    }
}

// MARK: - Months

private extension InsightsModel {
    var currentMonthStart: Date {
        calendar.monthPeriod(containing: now()).start
    }

    var selectedPeriod: InsightsPeriod {
        calendar.monthPeriod(containing: selectedMonth)
    }

    var selectedRange: ClosedRange<Date> {
        let period = selectedPeriod
        return period.start...period.end
    }

    func month(adding months: Int) -> Date {
        calendar.date(byAdding: .month, value: months, to: selectedMonth) ?? selectedMonth
    }

    /// Selects a month, never one after this month, and reads it.
    func select(_ month: Date) {
        selectedMonth = min(calendar.monthPeriod(containing: month).start, currentMonthStart)
        refresh()
    }
}

// MARK: - Reading and calculating

private extension InsightsModel {
    /// The active accounts' transactions as snapshots, with uncategorized rows shown as `Other`.
    func transactionSnapshots() throws -> [TransactionSnapshot] {
        let transactions = try reads.accounts()
            .filter { $0.archivedAt == nil }
            .flatMap(\.transactions)
        let fallback = transactions.isEmpty ? nil : fallbackCategory()
        return transactions.map { TransactionSnapshot(stored: $0, fallback: fallback) }
    }

    /// The live `Other` category, or `nil` when the catalog cannot be read or has none.
    func fallbackCategory() -> ZentriCore.Category? {
        let categories = (try? reads.categories()) ?? []
        return categories.first { $0.name == CategorizationService.fallbackCategoryName }
    }

    func load(_ snapshots: [TransactionSnapshot]) {
        let period = selectedPeriod
        let summary = InsightsCalculator.summary(transactions: snapshots, period: period, calendar: calendar)
        // A month in progress is averaged over the days that have happened, not the whole month.
        let peakDay = InsightsCalculator.peakDay(in: summary.dailySpend, through: min(now(), period.end))

        self.summary = summary
        largestSpends = InsightsCalculator.largestSpends(transactions: snapshots, period: period)
        observations = InsightsObservation.observations(summary: summary, peakDay: peakDay)
    }
}
