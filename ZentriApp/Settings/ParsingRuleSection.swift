import Foundation
import ZentriCore

/// The rules one account uses for one direction, in the order they run.
struct ParsingRuleSection: Sendable, Equatable, Identifiable {
    let accountID: UUID
    let accountName: String
    let direction: Direction
    let rules: [ParsingRuleListItem]

    var id: String { "\(accountID.uuidString)-\(direction.rawValue)" }
}
