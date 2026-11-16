/// Whether the on-device model can read messages on this device right now.
///
/// The reason travels with `.unavailable` so the app can explain the state to the user
/// instead of failing silently.
public enum ModelAvailability: Sendable, Equatable {
    /// The model is ready to read messages.
    case available
    /// The model cannot run here, with a user-facing reason.
    case unavailable(String)
}

/// The fields the model extracts from one message.
///
/// Values are the model's raw text, not validated numbers or dates: every field is read
/// again with the same deterministic parsers the rule engine uses, so a misread value fails
/// instead of being trusted. A `nil` field means the message did not state it.
public struct ModelTransactionOutput: Sendable, Equatable {
    /// Whether the message describes exactly one payment or transfer.
    public let isTransaction: Bool
    /// `debit` when money left the account, `credit` when it arrived.
    public let direction: String?
    /// The amount, as digits and separators only.
    public let amount: String?
    /// The merchant or payee as the message names it.
    public let merchant: String?
    /// The account balance after the transaction, as digits and separators only.
    public let balance: String?
    /// The transaction date, ideally as an ISO-8601 value.
    public let date: String?
    /// A category name, when the message makes one obvious.
    public let category: String?

    public init(
        isTransaction: Bool,
        direction: String? = nil,
        amount: String? = nil,
        merchant: String? = nil,
        balance: String? = nil,
        date: String? = nil,
        category: String? = nil
    ) {
        self.isTransaction = isTransaction
        self.direction = direction
        self.amount = amount
        self.merchant = merchant
        self.balance = balance
        self.date = date
        self.category = category
    }
}

/// Reads one message with a language model.
///
/// The protocol is deliberately small so the engine can be tested against a scripted client,
/// and so the live Foundation Models client can be compiled out on platforms without it.
/// Message text is untrusted data: an implementation must treat it as content to read, never
/// as instructions to follow.
public protocol TransactionModelClient: Sendable {
    /// Whether the model can run on this device.
    func availability() async -> ModelAvailability
    /// Extracts the transaction fields from `text`.
    func parse(text: String) async throws -> ModelTransactionOutput
}

/// A failure the client itself reports, so the engine can tell a timeout from a bad answer.
public enum ModelClientError: Error, Sendable, Equatable {
    /// The model did not answer within the client's time limit.
    case timedOut
    /// The model cannot read text in the message's language.
    case unsupportedLanguage
    /// The model answered, but not in a form the client could read.
    case unreadableAnswer
}
