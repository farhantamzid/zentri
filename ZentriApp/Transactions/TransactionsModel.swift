import Foundation
import Observation
import SwiftData
import ZentriCore

/// The Transactions list's data: every transaction, filtered, grouped by day, newest first.
///
/// The model reads the store only in ``refresh(filter:)`` and copies each row into a
/// ``TransactionListItem``; applying a new filter or search text re-filters those copies in memory
/// without another fetch, which is plenty for v1's data volume and keeps typing in the search field
/// off the store. Refreshing never writes, so it can never ask for the next refresh through
/// `AppState.dataRevision`.
@MainActor
@Observable
final class TransactionsModel {
    /// The filtered transactions, one section per day, newest day first.
    private(set) var sections: [TransactionDaySection] = []
    /// How far the last read got. An empty ``sections`` only means "nothing to show" once loaded.
    private(set) var loadState = TransactionsLoadState.loading
    /// Whether the store holds any transaction at all, which tells "no history yet" apart from
    /// "nothing matches the filter".
    private(set) var hasTransactions = false
    /// The combined balance of the active accounts, or `nil` when there is no active account.
    private(set) var balance: Decimal?
    /// The active accounts, in the order the app lists them.
    private(set) var accounts: [TransactionAccountOption] = []
    /// Every category, in the catalog's order.
    private(set) var categories: [TransactionCategoryOption] = []

    @ObservationIgnored private var items: [TransactionListItem] = []
    @ObservationIgnored private var storedTransactions: [UUID: ZentriCore.Transaction] = [:]
    @ObservationIgnored private var ruleNames: [UUID: String] = [:]
    /// The live `Other` category, which uncategorized rows are shown as and filtered as.
    @ObservationIgnored private var fallbackCategoryID: UUID?

    private let reads: TransactionsStoreReads
    private let calendar: Calendar

    /// Creates the model over the supplied context.
    ///
    /// - Parameter calendar: The calendar that defines days. A test passes a fixed one.
    init(context: ModelContext, calendar: Calendar = .current) {
        self.reads = TransactionsStoreReads(context: context)
        self.calendar = calendar
    }

    /// Creates the model over supplied reads, which is how a test makes a read throw.
    init(reads: TransactionsStoreReads, calendar: Calendar = .current) {
        self.reads = reads
        self.calendar = calendar
    }

    /// Reads the store again and applies the filter.
    ///
    /// A read that throws becomes ``TransactionsLoadState/failed`` with no rows, never an empty
    /// history. Parsing rules only label the detail's matched rule, so a failure to read them
    /// degrades to an unnamed rule instead of hiding the list.
    func refresh(filter: TransactionFilter) {
        do {
            let transactions = try reads.transactions()
            let accounts = try reads.accounts()
            let categories = try reads.categories().sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
            let rules = (try? reads.parsingRules()) ?? []
            load(transactions: transactions, accounts: accounts, categories: categories, rules: rules)
            loadState = .loaded
        } catch {
            items = []
            storedTransactions = [:]
            ruleNames = [:]
            fallbackCategoryID = nil
            hasTransactions = false
            balance = nil
            accounts = []
            categories = []
            loadState = .failed
        }
        apply(filter)
    }

    /// Re-filters the transactions read last time, without reading the store.
    func apply(_ filter: TransactionFilter) {
        let matching = items.filter { matches($0, filter) }
        let byDay = Dictionary(grouping: matching) { calendar.startOfDay(for: $0.occurredAt) }
        sections = byDay
            .map { day, items in TransactionDaySection(day: day, items: items.sorted(by: Self.isNewer)) }
            .sorted { $0.day > $1.day }
    }

    /// The stored transaction behind a row, for the detail and editor.
    func transaction(id: UUID) -> ZentriCore.Transaction? {
        storedTransactions[id]
    }

    /// The name of the parsing rule that produced a transaction, when it can be found.
    func ruleName(id: UUID?) -> String? {
        id.flatMap { ruleNames[$0] }
    }
}

// MARK: - Loading

private extension TransactionsModel {
    func load(
        transactions: [ZentriCore.Transaction],
        accounts allAccounts: [Account],
        categories catalog: [ZentriCore.Category],
        rules: [ParsingRule]
    ) {
        let fallback = catalog.first { $0.name == CategorizationService.fallbackCategoryName }
        fallbackCategoryID = fallback?.id
        items = transactions.map { item(from: $0, fallback: fallback) }
        storedTransactions = Dictionary(transactions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        ruleNames = Dictionary(rules.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        hasTransactions = !transactions.isEmpty

        let active = allAccounts
            .filter { $0.archivedAt == nil }
            .sorted { ($0.sortOrder, $0.id.uuidString) < ($1.sortOrder, $1.id.uuidString) }
        accounts = active.map { TransactionAccountOption(id: $0.id, name: $0.name) }
        categories = catalog.map {
            TransactionCategoryOption(id: $0.id, name: $0.name, symbolName: $0.symbolName, colorToken: $0.colorToken)
        }
        // The same shared calculation the Overview hero uses, so the two always agree.
        balance = active.isEmpty ? nil : BalanceCalculator.combined(accounts: active)
    }

    /// The list's copy of a stored transaction. An uncategorized one is shown as the live `Other`
    /// category, or the app's default styling for it when the catalog has none.
    func item(from transaction: ZentriCore.Transaction, fallback: ZentriCore.Category?) -> TransactionListItem {
        let category = transaction.category ?? fallback
        return TransactionListItem(
            id: transaction.id,
            accountID: transaction.account.id,
            accountName: transaction.account.name,
            merchant: transaction.merchantDisplay,
            merchantRaw: transaction.merchantRaw,
            note: transaction.note,
            rawText: transaction.rawMessage?.text,
            categoryID: transaction.category?.id,
            categoryName: category?.name ?? CategorizationService.fallbackCategoryName,
            symbolName: category?.symbolName ?? "ellipsis",
            colorToken: category?.colorToken ?? "slate",
            amount: transaction.amount,
            direction: transaction.direction,
            occurredAt: transaction.occurredAt,
            engine: transaction.parseEngine,
            isTransfer: transaction.isTransfer
        )
    }
}

// MARK: - Filtering

private extension TransactionsModel {
    func matches(_ item: TransactionListItem, _ filter: TransactionFilter) -> Bool {
        if let accountID = filter.accountID, item.accountID != accountID { return false }
        // An uncategorized row is shown as `Other`, and the Overview and Insights count it there,
        // so filtering by `Other` must include it.
        if let categoryID = filter.categoryID, (item.categoryID ?? fallbackCategoryID) != categoryID { return false }
        if let direction = filter.direction, item.direction != direction { return false }
        if let engine = filter.engine, item.engine != engine { return false }
        if let range = filter.dateRange, !contains(range, item.occurredAt) { return false }
        return matchesSearch(item, filter.searchText)
    }

    /// Whether the date falls on any whole day the range touches.
    func contains(_ range: ClosedRange<Date>, _ date: Date) -> Bool {
        let start = calendar.startOfDay(for: range.lowerBound)
        let lastDay = calendar.startOfDay(for: range.upperBound)
        let end = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
        return date >= start && date < end
    }

    /// Whether the merchant, the message's merchant, the note, or the raw SMS holds the search text,
    /// ignoring case and diacritics the way the system's search does.
    func matchesSearch(_ item: TransactionListItem, _ searchText: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return [item.merchant, item.merchantRaw, item.note, item.rawText]
            .compactMap(\.self)
            .contains { $0.localizedStandardContains(query) }
    }

    /// Newest first; transactions at the same instant keep a stable order.
    static func isNewer(_ lhs: TransactionListItem, _ rhs: TransactionListItem) -> Bool {
        if lhs.occurredAt != rhs.occurredAt {
            return lhs.occurredAt > rhs.occurredAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
