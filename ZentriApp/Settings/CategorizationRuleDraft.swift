import Foundation

/// The fields the rule editor collects, before the service validates and stores them.
struct CategorizationRuleDraft: Equatable, Sendable {
    var keyword: String
    var categoryID: UUID
    var priority: Int
    var isEnabled: Bool
}
