import Foundation

/// The fields a person can set when adding or editing a transaction.
///
/// It is a plain value so an editor can build one without touching the store, and
/// ``TransactionMutationService`` validates it before anything is written.
public struct TransactionEdit: Sendable, Equatable {
    /// The account the money moved in.
    public var accountID: UUID
    /// The positive magnitude of the movement.
    public var amount: Decimal
    /// Whether the money left or entered the account.
    public var direction: Direction
    /// When the transaction happened.
    public var occurredAt: Date
    /// The merchant as the app displays it.
    public var merchant: String
    /// The category, or `nil` to leave the transaction uncategorized.
    public var categoryID: UUID?
    /// A free-form note; blank text is stored as no note.
    public var note: String?
    /// Whether the movement is a transfer between the person's own accounts.
    public var isTransfer: Bool

    public init(
        accountID: UUID,
        amount: Decimal,
        direction: Direction,
        occurredAt: Date,
        merchant: String,
        categoryID: UUID?,
        note: String?,
        isTransfer: Bool
    ) {
        self.accountID = accountID
        self.amount = amount
        self.direction = direction
        self.occurredAt = occurredAt
        self.merchant = merchant
        self.categoryID = categoryID
        self.note = note
        self.isTransfer = isTransfer
    }

    /// The edit that would leave a stored transaction exactly as it is, which an editor starts from.
    @MainActor
    public init(_ transaction: Transaction) {
        self.init(
            accountID: transaction.account.id,
            amount: transaction.amount,
            direction: transaction.direction,
            occurredAt: transaction.occurredAt,
            merchant: transaction.merchantDisplay,
            categoryID: transaction.category?.id,
            note: transaction.note,
            isTransfer: transaction.isTransfer
        )
    }
}
