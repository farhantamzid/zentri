import Foundation
import ZentriCore

/// One parsing rule as the list and the editor show it.
struct ParsingRuleListItem: Sendable, Equatable, Identifiable {
    let id: UUID
    let accountID: UUID
    let accountName: String
    let name: String
    let direction: Direction
    let pattern: String
    let dateFormat: String?
    let isCaseInsensitive: Bool
    let dotMatchesNewlines: Bool
    let priority: Int
    let isEnabled: Bool
    /// Whether the stored pattern can be used as a rule; an imported rule may not be.
    let isPatternValid: Bool
}
