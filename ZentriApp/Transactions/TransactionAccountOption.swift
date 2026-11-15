import Foundation

/// An account a filter or editor can choose.
struct TransactionAccountOption: Sendable, Equatable, Identifiable {
    let id: UUID
    let name: String
}
