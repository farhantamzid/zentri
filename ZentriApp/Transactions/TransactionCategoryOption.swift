import Foundation

/// A category a filter, editor, or detail picker can choose.
struct TransactionCategoryOption: Sendable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let symbolName: String
    let colorToken: String
}
