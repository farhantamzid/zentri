import Foundation
import ZentriCore

/// One row of the Overview's recent activity, as values.
struct OverviewTransaction: Sendable, Equatable, Identifiable {
    /// The transaction's stable identity.
    let id: UUID
    /// The merchant as the app displays it.
    let merchant: String
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
    /// The reporting date the row shows.
    let occurredAt: Date
    /// Whether the row is a transfer; the row shows it, but the totals leave it out.
    let isTransfer: Bool

    init(
        id: UUID,
        merchant: String,
        categoryName: String,
        symbolName: String,
        colorToken: String,
        amount: Decimal,
        direction: Direction,
        occurredAt: Date,
        isTransfer: Bool
    ) {
        self.id = id
        self.merchant = merchant
        self.categoryName = categoryName
        self.symbolName = symbolName
        self.colorToken = colorToken
        self.amount = amount
        self.direction = direction
        self.occurredAt = occurredAt
        self.isTransfer = isTransfer
    }

    init(snapshot: TransactionSnapshot) {
        self.init(
            id: snapshot.id,
            merchant: snapshot.merchant,
            categoryName: snapshot.categoryName,
            symbolName: snapshot.symbolName,
            colorToken: snapshot.colorToken,
            amount: snapshot.amount,
            direction: snapshot.direction,
            occurredAt: snapshot.occurredAt,
            isTransfer: snapshot.isTransfer
        )
    }

    /// The signed amount, so a row reads as money in or money out without a separate column.
    var signedAmount: Decimal {
        direction == .credit ? amount : -amount
    }
}
