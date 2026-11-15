import Foundation

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
