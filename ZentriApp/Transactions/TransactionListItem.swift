import Foundation
import ZentriCore

/// One transaction as the list shows and searches it, copied out of the store.
struct TransactionListItem: Sendable, Equatable, Identifiable {
    /// The transaction's stable identity.
    let id: UUID
    /// The account's identity, for the account filter.
    let accountID: UUID
    /// The account's name, shown on the row.
    let accountName: String
    /// The merchant as the app displays it.
    let merchant: String
    /// The merchant as the message stated it, which search also matches.
    let merchantRaw: String
    /// The person's note, when there is one.
    let note: String?
    /// The bank message the transaction came from, when there is one.
    let rawText: String?
    /// The category's identity, or `nil` for an uncategorized transaction.
    let categoryID: UUID?
    /// The category's display name.
    let categoryName: String
    /// The category's SF Symbol.
    let symbolName: String
    /// The token the design system maps to the category's palette color.
    let colorToken: String
    /// The positive magnitude of the movement.
    let amount: Decimal
    /// Whether the money left or entered the account.
    let direction: Direction
    /// When the transaction happened.
    let occurredAt: Date
    /// The engine that produced the transaction, when it is known.
    let engine: ParseEngine?
    /// Whether the movement is a transfer between the person's own accounts.
    let isTransfer: Bool

    /// The signed amount: credits positive, debits negative.
    var signedAmount: Decimal {
        direction == .credit ? amount : -amount
    }

    /// Whether the person entered the transaction by hand.
    var isManual: Bool {
        engine == .manual
    }
}
