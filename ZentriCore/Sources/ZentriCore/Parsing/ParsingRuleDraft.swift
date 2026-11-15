import Foundation

/// The values a person enters for a parsing rule, before ``ParsingRuleMutationService`` checks and
/// stores them.
public struct ParsingRuleDraft: Sendable, Equatable {
    public var accountID: UUID
    public var name: String
    public var direction: Direction
    public var pattern: String
    /// The format for a captured `date`; blank means none.
    public var dateFormat: String?
    public var isCaseInsensitive: Bool
    public var dotMatchesNewlines: Bool
    public var priority: Int
    public var isEnabled: Bool

    public init(
        accountID: UUID,
        name: String,
        direction: Direction,
        pattern: String,
        dateFormat: String? = nil,
        isCaseInsensitive: Bool = true,
        dotMatchesNewlines: Bool = false,
        priority: Int = 0,
        isEnabled: Bool = true
    ) {
        self.accountID = accountID
        self.name = name
        self.direction = direction
        self.pattern = pattern
        self.dateFormat = dateFormat
        self.isCaseInsensitive = isCaseInsensitive
        self.dotMatchesNewlines = dotMatchesNewlines
        self.priority = priority
        self.isEnabled = isEnabled
    }
}
