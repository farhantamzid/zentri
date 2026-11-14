import Foundation
import SwiftData

/// An original message kept for provenance, retries, and deduplication.
@Model
public final class RawMessage {
    /// Stable identity used by backups.
    public var id: UUID
    /// The original message text, unmodified.
    public var text: String
    /// The sender when the shortcut provides it.
    public var sender: String?
    /// The message date when available, otherwise the ingestion invocation time.
    public var receivedAt: Date
    /// When the message reached the app.
    public var ingestedAt: Date
    /// The outcome of parsing the message.
    public var status: ParseStatus
    /// The engine that parsed the message, when one ran.
    public var engine: ParseEngine?
    /// The rule that matched, when a rule produced the parse.
    public var matchedRuleID: UUID?
    /// A user-facing failure description; never contains the message or other sensitive data.
    public var errorDescription: String?
    /// The transaction parsed from this message, when parsing succeeded.
    @Relationship(inverse: \Transaction.rawMessage)
    public var transaction: Transaction?
    /// The SHA-256 hex digest used to deduplicate messages.
    #Index<RawMessage>([\.fingerprint])
    public var fingerprint: String

    public init(
        id: UUID = UUID(),
        text: String,
        sender: String? = nil,
        receivedAt: Date,
        ingestedAt: Date = .now,
        status: ParseStatus = .processing,
        engine: ParseEngine? = nil,
        matchedRuleID: UUID? = nil,
        errorDescription: String? = nil,
        fingerprint: String
    ) {
        self.id = id
        self.text = text
        self.sender = sender
        self.receivedAt = receivedAt
        self.ingestedAt = ingestedAt
        self.status = status
        self.engine = engine
        self.matchedRuleID = matchedRuleID
        self.errorDescription = errorDescription
        self.fingerprint = fingerprint
        self.transaction = nil
    }
}
