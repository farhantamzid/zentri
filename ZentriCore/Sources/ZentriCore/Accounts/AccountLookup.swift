import Foundation
import SwiftData

/// The account reads that pickers, the Shortcuts account parameter, and ingestion share.
///
/// Every read throws instead of answering "no accounts", so a caller can tell a store with no
/// account apart from a store it could not read.
public enum AccountLookup {
    /// The non-archived accounts, in the order an account picker shows them: by sort order, then by
    /// id so equal sort orders still have a stable order.
    @MainActor
    public static func activeAccounts(in context: ModelContext) throws -> [Account] {
        try context.fetch(FetchDescriptor<Account>())
            .filter { $0.archivedAt == nil }
            .sorted(by: pickerOrder)
    }

    /// The accounts with the given ids, archived ones included, in picker order.
    ///
    /// A Shortcut keeps the account it was configured with even after that account is archived.
    /// Resolving it still finds the account, so the capture reports the account as unavailable instead
    /// of silently landing on another one. Ids that match no account are left out.
    @MainActor
    public static func accounts(withIDs ids: [UUID], in context: ModelContext) throws -> [Account] {
        let wanted = Set(ids)
        return try context.fetch(FetchDescriptor<Account>())
            .filter { wanted.contains($0.id) }
            .sorted(by: pickerOrder)
    }

    /// Sort order first, then id.
    private static func pickerOrder(_ lhs: Account, _ rhs: Account) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
