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

    /// The rules that may parse a message, as parser specs, in evaluation order.
    ///
    /// Rules of an archived account are left out: an archived account takes no new transactions,
    /// so its patterns must not compete for a message that ingestion, a retry, or a reprocess
    /// parses without a chosen account.
    public static func specs(in context: ModelContext) throws -> [ParsingRuleSpec] {
        ordered(try context.fetch(FetchDescriptor<ParsingRule>()))
            .filter { $0.account.archivedAt == nil }
            .map(\.spec)
    }
}
