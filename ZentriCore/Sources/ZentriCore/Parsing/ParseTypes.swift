import Foundation

/// A message offered to a parsing engine.
public struct ParseInput: Sendable, Equatable {
    /// The original message text, unmodified.
    public let text: String
    /// The account the message belongs to, when the caller knows it.
    public let accountID: UUID?
    /// The sender, when the caller provides it.
    public let sender: String?
    /// The message date, or when it is unavailable, the time the message reached the app.
    public let receivedAt: Date

    public init(text: String, accountID: UUID? = nil, sender: String? = nil, receivedAt: Date) {
        self.text = text
        self.accountID = accountID
        self.sender = sender
        self.receivedAt = receivedAt
    }
}

/// A transaction extracted by a parsing engine, before persistence.
///
/// ``occurredAt`` is optional because an engine may not know a date; a validated draft
/// always has one, either from the message or from the receipt time.
public struct TransactionDraft: Sendable, Equatable {
    public var direction: Direction
    public var amount: Decimal
    public var merchant: String
    public var balanceAfter: Decimal?
    public var occurredAt: Date?
    public var reference: String?
    /// A category name suggested by an engine; the categorization service decides whether to use it.
    public var categorySuggestion: String?
    /// The rule that produced the draft, when a rule engine produced it.
    public var matchedRuleID: UUID?

    public init(
        direction: Direction,
        amount: Decimal,
        merchant: String,
        balanceAfter: Decimal? = nil,
        occurredAt: Date? = nil,
        reference: String? = nil,
        categorySuggestion: String? = nil,
        matchedRuleID: UUID? = nil
    ) {
        self.direction = direction
        self.amount = amount
        self.merchant = merchant
        self.balanceAfter = balanceAfter
        self.occurredAt = occurredAt
        self.reference = reference
        self.categorySuggestion = categorySuggestion
        self.matchedRuleID = matchedRuleID
    }
}

/// The outcome of parsing a message.
public enum ParseResult: Sendable, Equatable {
    /// A validated transaction.
    case transaction(TransactionDraft)
    /// The message is not a transaction, such as an OTP or a promotion.
    case notTransaction
    /// The message could have been a transaction but could not be parsed or validated.
    case failure([ParseDiagnostic])
}

/// A user-facing reason a message could not be parsed.
///
/// Diagnostics carry the rule and field they concern so the rule tester can point at the
/// exact setting to fix. They never contain the message text.
public struct ParseDiagnostic: Sendable, Equatable {
    /// The kind of problem, for programmatic handling and tests.
    public enum Code: String, Sendable, Hashable, Codable, CaseIterable {
        /// The message is longer than the engine's limit.
        case inputTooLong
        /// A rule's pattern is not a valid regular expression.
        case invalidPattern
        /// A rule's pattern has no `amount` capture group.
        case missingAmountGroup
        /// A rule matched but a required capture group did not participate.
        case missingField
        /// A captured amount is not a number this app can read deterministically.
        case invalidAmount
        /// The validated amount is not greater than zero.
        case amountNotPositive
        /// The validated date is more than 24 hours after the message was received.
        case dateTooFarInFuture
        /// The validated merchant is empty.
        case missingMerchant
        /// The pattern could not be matched against the message.
        case matchFailed
        /// The on-device model is not available, or is turned off, on this device.
        case modelUnavailable
        /// The on-device model did not return an answer this app could use.
        case modelFailed
        /// The on-device model did not answer within the time limit.
        case modelTimedOut
    }

    /// The rule that produced the diagnostic, or `nil` for engine-wide and validation diagnostics.
    public let ruleID: UUID?
    /// The field the diagnostic concerns, such as `amount`, `date`, or `merchant`.
    public let field: String?
    /// The kind of problem.
    public let code: Code
    /// A clear, non-sensitive explanation.
    public let message: String

    public init(code: Code, ruleID: UUID? = nil, field: String? = nil, message: String) {
        self.code = code
        self.ruleID = ruleID
        self.field = field
        self.message = message
    }
}

/// A persisted rule handed to a parsing engine, without its SwiftData relationships.
public struct ParsingRuleSpec: Sendable, Equatable, Identifiable {
    public let id: UUID
    /// The rule's account. A rule without an account runs only when the input has no account.
    public let accountID: UUID?
    public let direction: Direction
    /// The Swift regex with the named capture groups `amount`, `merchant`, `balance`, `date`, `time`, and `reference`.
    public let pattern: String
    /// The format used to parse a captured `date`; when absent, the common formats are tried
    /// and the receipt time is the final fallback.
    public let dateFormat: String?
    public let isCaseInsensitive: Bool
    public let dotMatchesNewlines: Bool
    /// The evaluation order; lower values run first.
    public let priority: Int
    public let isEnabled: Bool

    public init(
        id: UUID = UUID(),
        accountID: UUID? = nil,
        direction: Direction,
        pattern: String,
        dateFormat: String? = nil,
        isCaseInsensitive: Bool = true,
        dotMatchesNewlines: Bool = false,
        priority: Int = 0,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.accountID = accountID
        self.direction = direction
        self.pattern = pattern
        self.dateFormat = dateFormat
        self.isCaseInsensitive = isCaseInsensitive
        self.dotMatchesNewlines = dotMatchesNewlines
        self.priority = priority
        self.isEnabled = isEnabled
    }
}

/// A parser that turns messages into validated transaction drafts.
public protocol TransactionParsing: Sendable {
    func parse(_ input: ParseInput) async -> ParseResult
}
