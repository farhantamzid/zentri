import Foundation

/// The value the Accounts list pushes to show one account's detail.
struct AccountRoute: Hashable, Sendable {
    let accountID: UUID
}
