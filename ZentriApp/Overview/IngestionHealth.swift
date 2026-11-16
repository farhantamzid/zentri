import Foundation
import SwiftData
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

extension IngestionHealth {
    /// The archive's health read straight from the store: a count and two one-row fetches, so the
    /// Overview never loads every message, with its text, to state three numbers.
    ///
    /// - Throws: The store's error when a read fails.
    @MainActor
    init(context: ModelContext) throws {
        var newestMessage = FetchDescriptor<RawMessage>(sortBy: [SortDescriptor(\.receivedAt, order: .reverse)])
        newestMessage.fetchLimit = 1

        let parsed = ParseStatus.parsed
        var newestSuccess = FetchDescriptor<RawMessage>(
            predicate: #Predicate { $0.status == parsed },
            sortBy: [SortDescriptor(\.ingestedAt, order: .reverse)]
        )
        newestSuccess.fetchLimit = 1

        let failed = ParseStatus.failed
        let failures = FetchDescriptor<RawMessage>(predicate: #Predicate { $0.status == failed })

        self.init(
            lastMessageAt: try context.fetch(newestMessage).first?.receivedAt,
            lastSuccessAt: try context.fetch(newestSuccess).first?.ingestedAt,
            failureCount: try context.fetchCount(failures)
        )
    }
}
