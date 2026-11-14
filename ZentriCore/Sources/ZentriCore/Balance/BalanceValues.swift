import Foundation

/// A balance checkpoint without any SwiftData dependency, so balance math is independently testable.
public struct CheckpointValue: Sendable, Equatable {
    /// The account the checkpoint belongs to.
    public let accountID: UUID
    /// The observed or declared balance.
    public let amount: Decimal
    /// When the balance was observed.
    public let recordedAt: Date
    /// When the checkpoint was created; breaks ties between equal `recordedAt` values.
    public let createdAt: Date

    public init(accountID: UUID, amount: Decimal, recordedAt: Date, createdAt: Date) {
        self.accountID = accountID
        self.amount = amount
        self.recordedAt = recordedAt
        self.createdAt = createdAt
    }
}

/// A transaction without any SwiftData dependency, so balance math is independently testable.
public struct TransactionValue: Sendable, Equatable {
    /// The account the money moved through.
    public let accountID: UUID
    /// The positive magnitude of the movement.
    public let amount: Decimal
    /// Whether the movement left or entered the account.
    public let direction: Direction
    /// The ingestion/creation date that drives checkpoint balance math.
    public let recordedAt: Date

    public init(accountID: UUID, amount: Decimal, direction: Direction, recordedAt: Date) {
        self.accountID = accountID
        self.amount = amount
        self.direction = direction
        self.recordedAt = recordedAt
    }

    /// The movement's effect on the balance: credits add, debits subtract.
    public var signedAmount: Decimal {
        switch direction {
        case .credit: amount
        case .debit: -amount
        }
    }
}
