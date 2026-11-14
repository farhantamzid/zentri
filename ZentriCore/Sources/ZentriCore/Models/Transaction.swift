import Foundation
import SwiftData

/// A money movement recorded against an account.
@Model
public final class Transaction {
    /// Stable identity used by backups and widget snapshots.
    public var id: UUID
    /// The account the money moved through.
    public var account: Account
    /// The positive magnitude of the movement.
    public var amount: Decimal
    /// Whether the movement left or entered the account.
    public var direction: Direction
    /// The reporting date: the SMS date when available, otherwise when the transaction was recorded.
    public var occurredAt: Date
    /// The ingestion/creation date that drives checkpoint balance math.
    public var recordedAt: Date
    /// The merchant as extracted, or the full message when extraction failed.
    public var merchantRaw: String
    /// The merchant trimmed and whitespace-collapsed for display and matching.
    public var merchantDisplay: String
    /// The assigned category, nil until the transaction is categorized.
    public var category: Category?
    /// How the category was assigned.
    public var categorySource: CategorySource?
    /// The balance reported by the SMS, when present.
    public var balanceAfter: Decimal?
    /// The raw message this transaction was parsed from, when any.
    public var rawMessage: RawMessage?
    /// The engine that parsed the transaction.
    public var parseEngine: ParseEngine?
    /// The rule that produced the parse, when a rule matched.
    public var matchedRuleID: UUID?
    /// Whether both sides of a transfer are excluded from spend and income reports.
    public var isTransfer: Bool
    /// A user-authored note.
    public var note: String?
    /// When the transaction was created.
    public var createdAt: Date
    /// When the transaction was last edited.
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        account: Account,
        amount: Decimal,
        direction: Direction,
        occurredAt: Date,
        recordedAt: Date = .now,
        merchantRaw: String,
        merchantDisplay: String,
        category: Category? = nil,
        categorySource: CategorySource? = nil,
        balanceAfter: Decimal? = nil,
        rawMessage: RawMessage? = nil,
        parseEngine: ParseEngine? = nil,
        matchedRuleID: UUID? = nil,
        isTransfer: Bool = false,
        note: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.account = account
        self.amount = amount
        self.direction = direction
        self.occurredAt = occurredAt
        self.recordedAt = recordedAt
        self.merchantRaw = merchantRaw
        self.merchantDisplay = merchantDisplay
        self.category = category
        self.categorySource = categorySource
        self.balanceAfter = balanceAfter
        self.rawMessage = rawMessage
        self.parseEngine = parseEngine
        self.matchedRuleID = matchedRuleID
        self.isTransfer = isTransfer
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
