import Foundation
import SwiftData

/// Deletes every row in the store, for "Delete All Data".
///
/// Every model the schema declares is deleted in one save; a failed save rolls the context back, so
/// the store is either emptied completely or left exactly as it was. The settings document and the
/// widget snapshot live outside the store, so the caller removes those separately.
@MainActor
public struct StoreEraser {
    /// The save the deletion goes through, replaceable so a test can make persistence fail.
    ///
    /// Production leaves this at `ModelContext.save()`; a healthy store cannot be made to fail a save
    /// on demand, so the rollback path is only reachable through this internal seam.
    internal var saveHandler: @MainActor (ModelContext) throws -> Void = { try $0.save() }

    public init() {}

    /// Deletes every account, transaction, checkpoint, raw message, parsing rule, category, and
    /// keyword rule, then saves.
    public func eraseAll(in context: ModelContext) throws {
        do {
            try deleteAll(Transaction.self, in: context)
            try deleteAll(BalanceCheckpoint.self, in: context)
            try deleteAll(RawMessage.self, in: context)
            try deleteAll(ParsingRule.self, in: context)
            try deleteAll(CategorizationRule.self, in: context)
            try deleteAll(Account.self, in: context)
            try deleteAll(Category.self, in: context)
            try saveHandler(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    private func deleteAll<Row: PersistentModel>(_ type: Row.Type, in context: ModelContext) throws {
        for row in try context.fetch(FetchDescriptor<Row>()) {
            context.delete(row)
        }
    }
}
