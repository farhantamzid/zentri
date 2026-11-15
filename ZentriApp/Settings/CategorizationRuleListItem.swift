import Foundation

/// One keyword rule as the rules screen shows it, copied out of the store.
struct CategorizationRuleListItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let keyword: String
    let categoryID: UUID
    let categoryName: String
    let symbolName: String
    let colorToken: String
    /// The evaluation order; lower numbers win.
    let priority: Int
    let isEnabled: Bool
}
