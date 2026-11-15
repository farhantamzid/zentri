import Foundation

/// One account as the Accounts screens show it, copied out of the store so the views never compute
/// a balance in `body`.
struct AccountListItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let institutionName: String?
    /// The newest checkpoint plus the transactions recorded after it.
    let balance: Decimal
    /// When the newest checkpoint was recorded, or `nil` for an account without one.
    let asOf: Date?
    let isArchived: Bool
}
