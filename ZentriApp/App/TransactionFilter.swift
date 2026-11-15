import Foundation
import ZentriCore

/// The filters the Transactions tab applies to its list.
///
/// The value is shared so the Insights tab can hand a category to Transactions and a future deep
/// link can open a filtered list. Every field defaults to "no filter", so `TransactionFilter()`
/// shows everything.
struct TransactionFilter: Equatable, Sendable {
    /// Show only transactions in this category, or all categories when nil.
    var categoryID: UUID?
    /// Show only transactions on this account, or all accounts when nil.
    var accountID: UUID?
    /// Show only money that moved this way, or both directions when nil.
    var direction: Direction?
    /// The text the list searches for in the merchant, note, and raw message.
    var searchText: String
    /// Show only transactions that came from this engine, or every source when nil.
    var engine: ParseEngine?
    /// Show only transactions on these days, inclusive of both ends' whole days, or all dates when
    /// nil. The list compares calendar days, so the times inside the range do not matter.
    var dateRange: ClosedRange<Date>?

    init(
        categoryID: UUID? = nil,
        accountID: UUID? = nil,
        direction: Direction? = nil,
        searchText: String = "",
        engine: ParseEngine? = nil,
        dateRange: ClosedRange<Date>? = nil
    ) {
        self.categoryID = categoryID
        self.accountID = accountID
        self.direction = direction
        self.searchText = searchText
        self.engine = engine
        self.dateRange = dateRange
    }

    /// Whether any filter other than the search text is narrowing the list.
    var hasActiveFilters: Bool {
        categoryID != nil || accountID != nil || direction != nil || engine != nil || dateRange != nil
    }

    /// The same filter with everything but the search text cleared.
    var clearingFilters: TransactionFilter {
        TransactionFilter(searchText: searchText)
    }
}
