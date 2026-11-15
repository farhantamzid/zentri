import Foundation

/// One category as the Categories screen shows it, copied out of the store.
struct CategoryListItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let symbolName: String
    let colorToken: String
    /// How many transactions are filed here, which a delete moves to `Other`.
    let transactionCount: Int
    /// Whether this is the fallback category, which can be reordered but not renamed or deleted.
    let isFallback: Bool
}
