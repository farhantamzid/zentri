import Foundation
import SwiftData

/// A regex rule that parses an account's messages into transactions.
@Model
public final class ParsingRule {
    /// Stable identity used by backups and by transactions that reference the rule.
    public var id: UUID
    /// The account the rule applies to.
    public var account: Account
    /// A display name, e.g. "Debit — card ending 1234".
    public var name: String
    /// Whether the rule matches debits or credits.
    public var direction: Direction
    /// The Swift regex with named capture groups such as `amount` and `merchant`.
    public var pattern: String
    /// The format for a captured `date` group; when absent, the receipt time is used.
    public var dateFormat: String?
    /// Whether matching ignores case. Defaults to true.
    public var isCaseInsensitive: Bool
    /// Whether `.` in the pattern also matches newlines. Defaults to false.
    public var dotMatchesNewlines: Bool
    /// The evaluation order; lower values run first.
    public var priority: Int
    /// Whether the rule participates in parsing.
    public var isEnabled: Bool
    /// When the rule was created.
    public var createdAt: Date
    /// When the rule was last edited.
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        account: Account,
        name: String,
        direction: Direction,
        pattern: String,
        dateFormat: String? = nil,
        isCaseInsensitive: Bool = true,
        dotMatchesNewlines: Bool = false,
        priority: Int,
        isEnabled: Bool,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.account = account
        self.name = name
        self.direction = direction
        self.pattern = pattern
        self.dateFormat = dateFormat
        self.isCaseInsensitive = isCaseInsensitive
        self.dotMatchesNewlines = dotMatchesNewlines
        self.priority = priority
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
