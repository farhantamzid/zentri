import Foundation
import SwiftData

/// A bank account that owns transactions, checkpoints, and parsing rules.
@Model
public final class Account {
    /// Stable identity used by backups and widget snapshots.
    public var id: UUID
    /// The name shown in account pickers, e.g. "Everyday Account".
    public var name: String
    /// Free-text institution name.
    public var institutionName: String?
    /// The user's preferred ordering.
    public var sortOrder: Int
    /// When the account was created.
    public var createdAt: Date
    /// Set when the account is archived; archived accounts are hidden from pickers.
    public var archivedAt: Date?

    /// Parsing rules scoped to this account, deleted with it.
    @Relationship(deleteRule: .cascade, inverse: \ParsingRule.account)
    public var rules: [ParsingRule]
    /// Transactions recorded against this account, deleted with it.
    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    public var transactions: [Transaction]
    /// Balance checkpoints observed for this account, deleted with it.
    @Relationship(deleteRule: .cascade, inverse: \BalanceCheckpoint.account)
    public var checkpoints: [BalanceCheckpoint]

    public init(
        id: UUID = UUID(),
        name: String,
        institutionName: String? = nil,
        sortOrder: Int,
        createdAt: Date,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.institutionName = institutionName
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.archivedAt = archivedAt
        self.rules = []
        self.transactions = []
        self.checkpoints = []
    }
}
