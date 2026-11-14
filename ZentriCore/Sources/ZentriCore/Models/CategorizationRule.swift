import Foundation
import SwiftData

/// A keyword rule that assigns a category to transactions whose merchant matches.
@Model
public final class CategorizationRule {
    /// Stable identity used by backups.
    public var id: UUID
    /// The keyword matched case-insensitively against the merchant display name.
    public var keyword: String
    /// The category assigned when the keyword matches.
    public var category: Category
    /// The evaluation order; lower values run first.
    public var priority: Int
    /// Whether the rule participates in categorization.
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        keyword: String,
        category: Category,
        priority: Int,
        isEnabled: Bool
    ) {
        self.id = id
        self.keyword = keyword
        self.category = category
        self.priority = priority
        self.isEnabled = isEnabled
    }
}
