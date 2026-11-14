import Foundation
import ZentriCore

/// The filters the Transactions tab applies to its list.
///
/// The value is shared so the Insights tab can hand a category to Transactions and a future deep
/// link can open a filtered list. Every field defaults to "no filter", so `TransactionFilter()`
/// shows everything; Task 12 may extend it additively.
struct TransactionFilter: Equatable, Sendable {
    /// Show only transactions in this category, or all categories when nil.
    var categoryID: UUID?
    /// Show only transactions on this account, or all accounts when nil.
    var accountID: UUID?
    /// Show only money that moved this way, or both directions when nil.
    var direction: Direction?
    /// The text the list searches for in the merchant, note, and raw message.
    var searchText: String

    init(
        categoryID: UUID? = nil,
        accountID: UUID? = nil,
        direction: Direction? = nil,
        searchText: String = ""
    ) {
        self.categoryID = categoryID
        self.accountID = accountID
        self.direction = direction
        self.searchText = searchText
    }
}
