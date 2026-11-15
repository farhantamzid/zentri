import Foundation
import ZentriCore

/// What the ingestion health card reports about the message archive.
///
/// These are the three questions a person has when a transaction is missing: did the message
/// arrive, when did one last parse, and how many are stuck.
struct IngestionHealth: Sendable, Equatable {
    /// The newest message's arrival time, or `nil` when no message has arrived.
    let lastMessageAt: Date?
    /// When the newest successfully parsed message was ingested, or `nil` when none has parsed.
    let lastSuccessAt: Date?
    /// How many messages failed to parse.
    let failureCount: Int
}

extension IngestionHealth {
    /// The archive's messages, stated the three ways the health card reports them.
    ///
    /// The Overview card and the Shortcuts setup guide both build their summary here, so the two can
    /// never disagree.
    init(messages: [RawMessage]) {
        self.init(
            lastMessageAt: messages.map(\.receivedAt).max(),
            lastSuccessAt: messages.filter { $0.status == .parsed }.map(\.ingestedAt).max(),
            failureCount: messages.count { $0.status == .failed }
        )
    }
}
