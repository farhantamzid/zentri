import Foundation
import SwiftData

/// An observed or declared account balance that anchors balance math.
@Model
public final class BalanceCheckpoint {
    /// Stable identity used by backups.
    public var id: UUID
    /// The account the checkpoint belongs to.
    public var account: Account
    /// The observed or declared balance.
    public var amount: Decimal
    /// When the balance was observed.
    public var recordedAt: Date
    /// How the checkpoint was established.
    public var source: CheckpointSource
    /// The transaction whose SMS established this balance, when any.
    public var sourceTransactionID: UUID?
    /// When the checkpoint was created; breaks ties between equal `recordedAt` values.
    public var createdAt: Date
    /// A user-authored note.
    public var note: String?

    public init(
        id: UUID = UUID(),
        account: Account,
        amount: Decimal,
        recordedAt: Date,
        source: CheckpointSource,
        sourceTransactionID: UUID? = nil,
        createdAt: Date = .now,
        note: String? = nil
    ) {
        self.id = id
        self.account = account
        self.amount = amount
        self.recordedAt = recordedAt
        self.source = source
        self.sourceTransactionID = sourceTransactionID
        self.createdAt = createdAt
        self.note = note
    }
}
