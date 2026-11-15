import Foundation
import ZentriCore

/// One archived message as the inbox and its detail show it.
struct RawMessageListItem: Sendable, Equatable, Identifiable {
    let id: UUID
    let text: String
    let sender: String?
    let receivedAt: Date
    let status: ParseStatus
    let engine: ParseEngine?
    /// The stored, user-facing reason the last attempt failed.
    let errorDescription: String?
    let matchedRuleID: UUID?
    /// The matched rule's name, or `nil` when no rule matched or it has been deleted.
    let matchedRuleName: String?
    /// Whether a transaction is still linked to the message.
    let hasTransaction: Bool
}
