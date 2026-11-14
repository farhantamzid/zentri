import Foundation

/// A category without any SwiftData dependency, so categorization and insights are independently testable.
public struct CategorySnapshot: Sendable, Equatable, Identifiable {
    /// The category's stable identity, used by backups and widget snapshots.
    public let id: UUID
    /// The display name, e.g. "Bills & Utilities".
    public let name: String
    /// The SF Symbol shown beside the category.
    public let symbolName: String
    /// The token the design system maps to a palette color.
    public let colorToken: String

    public init(id: UUID, name: String, symbolName: String, colorToken: String) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.colorToken = colorToken
    }
}

/// A keyword rule without any SwiftData dependency, so categorization is independently testable.
public struct CategorizationRuleSpec: Sendable, Equatable {
    /// The keyword matched case-insensitively against the merchant.
    public let keyword: String
    /// The category assigned when the keyword matches.
    public let categoryName: String
    /// The evaluation order; lower values win.
    public let priority: Int
    /// Whether the rule participates in categorization.
    public let isEnabled: Bool

    public init(keyword: String, categoryName: String, priority: Int, isEnabled: Bool) {
        self.keyword = keyword
        self.categoryName = categoryName
        self.priority = priority
        self.isEnabled = isEnabled
    }
}

/// The category a transaction was assigned and how the assignment was made.
public struct CategoryMatch: Sendable, Equatable {
    /// The category's display name.
    public let categoryName: String
    /// Whether a keyword rule, an AI suggestion, or the fallback decided the category.
    public let source: CategorySource

    public init(categoryName: String, source: CategorySource) {
        self.categoryName = categoryName
        self.source = source
    }
}

/// Assigns a category to a merchant from keyword rules, an AI suggestion, and the built-in category list.
///
/// Matching is deterministic and locale-independent: case-insensitive keyword containment, the lowest
/// priority number first, then the longer keyword, then the lexicographically smaller keyword and
/// category name. The service never creates a category; anything it cannot resolve becomes `Other`.
public enum CategorizationService: Sendable {
    /// The category used when no rule matches and no known suggestion is available.
    ///
    /// Taken from ``SeedData`` so the fallback always names a category a fresh store contains.
    public static let fallbackCategoryName = SeedData.fallbackCategoryName

    /// The categories a fresh store ships with, in display order.
    ///
    /// Taken from ``SeedData/builtInCategoryNames``, the single source of truth for the built-in names, so
    /// the seeded rows and the names a suggestion is validated against cannot drift apart. It is only used
    /// to validate suggestions when the caller supplies no live category list.
    public static let builtInCategoryNames: [String] = SeedData.builtInCategoryNames

    /// The locale used for every comparison, so a match never depends on the device's locale.
    private static let matchingLocale = Locale(identifier: "en_US_POSIX")

    /// Chooses the category for a merchant.
    ///
    /// An enabled keyword rule always wins over the AI suggestion. When no rule matches, the suggestion
    /// is accepted only when it names a category the catalog knows, so an invented category never reaches
    /// the store. Everything else falls back to ``fallbackCategoryName`` with ``CategorySource/default``.
    ///
    /// - Parameters:
    ///   - merchant: The merchant display name, as extracted from the message.
    ///   - rules: The keyword rules to evaluate, in any order.
    ///   - suggestion: The category an AI parse suggested, when there was one.
    ///   - categories: The categories that exist in the store. Pass `nil` to validate against
    ///     ``builtInCategoryNames``; an empty list rejects every suggestion.
    public static func match(
        merchant: String,
        rules: [CategorizationRuleSpec],
        suggestion: String?,
        categories: [CategorySnapshot]? = nil
    ) -> CategoryMatch {
        if let rule = matchingRule(merchant: merchant, rules: rules) {
            // The rule's name is returned verbatim: callers use it to look the category up in the store.
            return CategoryMatch(categoryName: rule.categoryName, source: .rule)
        }
        let knownNames = categories.map { $0.map(\.name) } ?? builtInCategoryNames
        if let name = knownCategoryName(for: suggestion, in: knownNames) {
            return CategoryMatch(categoryName: name, source: .ai)
        }
        return CategoryMatch(categoryName: fallbackCategoryName, source: .default)
    }

    /// The enabled rule that best matches the merchant, or `nil` when no rule matches.
    private static func matchingRule(
        merchant: String,
        rules: [CategorizationRuleSpec]
    ) -> CategorizationRuleSpec? {
        rules
            .filter { rule in
                let keyword = normalized(rule.keyword)
                guard rule.isEnabled, !keyword.isEmpty, !normalized(rule.categoryName).isEmpty else {
                    return false
                }
                return merchant.range(
                    of: keyword,
                    options: .caseInsensitive,
                    range: nil,
                    locale: matchingLocale
                ) != nil
            }
            .min(by: isPreferred)
    }

    /// Whether the first rule should win over the second when both match.
    private static func isPreferred(_ lhs: CategorizationRuleSpec, _ rhs: CategorizationRuleSpec) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority < rhs.priority
        }
        let lhsKeyword = normalized(lhs.keyword)
        let rhsKeyword = normalized(rhs.keyword)
        if lhsKeyword.count != rhsKeyword.count {
            // The longer keyword is the more specific rule, e.g. "grab car" over "grab".
            return lhsKeyword.count > rhsKeyword.count
        }
        if lhsKeyword != rhsKeyword {
            return lhsKeyword < rhsKeyword
        }
        return normalized(lhs.categoryName) < normalized(rhs.categoryName)
    }

    /// The catalog's spelling of the suggested category, or `nil` when the suggestion is unknown.
    private static func knownCategoryName(for suggestion: String?, in names: [String]) -> String? {
        let suggestion = normalized(suggestion ?? "")
        guard !suggestion.isEmpty else { return nil }
        return names.first { name in
            normalized(name).compare(
                suggestion,
                options: .caseInsensitive,
                range: nil,
                locale: matchingLocale
            ) == .orderedSame
        }
    }

    /// The value with leading, trailing, and repeated whitespace removed.
    private static func normalized(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
