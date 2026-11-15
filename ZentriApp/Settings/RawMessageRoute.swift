import Foundation

/// The value the inbox pushes to show one archived message.
struct RawMessageRoute: Hashable, Sendable {
    let messageID: UUID
}
