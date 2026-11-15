import Foundation
import SwiftData

/// The stored parsing rules in the order the rule engine evaluates them.
///
/// Ingestion, reprocessing, the rule list, and the tester all read rules through here, so every
/// screen shows rules in the order they actually run: priority, then creation date, then
/// identity. `sorted(by:)` is not stable, so every key is spelled out — without the last two,
/// rules that share a priority would run in whatever order the store returned them.
public enum StoredParsingRules {
    /// `rules` in evaluation order.
    public static func ordered(_ rules: [ParsingRule]) -> [ParsingRule] {
        rules.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// Every stored rule as a parser spec, in evaluation order.
    public static func specs(in context: ModelContext) throws -> [ParsingRuleSpec] {
        ordered(try context.fetch(FetchDescriptor<ParsingRule>())).map(\.spec)
    }
}

extension ParsingRule {
    /// The rule as the parsing engines see it, without its SwiftData relationships.
    public var spec: ParsingRuleSpec {
        ParsingRuleSpec(
            id: id,
            accountID: account.id,
            direction: direction,
            pattern: pattern,
            dateFormat: dateFormat,
            isCaseInsensitive: isCaseInsensitive,
            dotMatchesNewlines: dotMatchesNewlines,
            priority: priority,
            isEnabled: isEnabled
        )
    }
}
