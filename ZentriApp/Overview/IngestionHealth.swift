import Foundation

/// What the ingestion health card reports about the message archive.
///
/// These are the three questions a person has when a transaction is missing: did the message
/// arrive, when did one last parse, and how many are stuck. The inbox itself arrives with the raw
/// message screen, so this card reports the counts without a link.
struct IngestionHealth: Sendable, Equatable {
    /// The newest message's arrival time, or `nil` when no message has arrived.
    let lastMessageAt: Date?
    /// When the newest successfully parsed message was ingested, or `nil` when none has parsed.
    let lastSuccessAt: Date?
    /// How many messages failed to parse.
    let failureCount: Int
}
