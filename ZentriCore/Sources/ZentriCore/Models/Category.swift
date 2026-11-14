import Foundation
import SwiftData

/// A spending or income category, seeded with the app's built-in set.
@Model
public final class Category {
    /// Stable identity used by backups and widget snapshots.
    public var id: UUID
    /// The display name, e.g. "Bills & Utilities".
    public var name: String
    /// The SF Symbol shown beside the category.
    public var symbolName: String
    /// The token the design system maps to a palette color.
    public var colorToken: String
    /// The user's preferred ordering.
    public var sortOrder: Int
    /// Whether the category ships with the app and cannot be deleted.
    public var isSystem: Bool

    /// Transactions currently assigned to this category.
    @Relationship(inverse: \Transaction.category)
    public var transactions: [Transaction]
    /// Keyword rules that assign this category, deleted with it.
    @Relationship(deleteRule: .cascade, inverse: \CategorizationRule.category)
    public var categorizationRules: [CategorizationRule]

    public init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        colorToken: String,
        sortOrder: Int,
        isSystem: Bool = false
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.colorToken = colorToken
        self.sortOrder = sortOrder
        self.isSystem = isSystem
        self.transactions = []
        self.categorizationRules = []
    }
}
