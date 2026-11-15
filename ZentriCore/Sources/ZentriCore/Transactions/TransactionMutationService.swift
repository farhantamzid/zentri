import Foundation
import SwiftData

/// The only writer of the person's own changes to transactions: manual adds, edits, deletes, the
/// transfer flag, and category corrections.
///
/// Every mutation that changes a transaction saves and then awaits one
/// ``WidgetSnapshotRefresher/refresh()``, so when the call returns the widgets already describe the
/// new balance and the caller can tell the rest of the app to reload. A save that fails rolls the
/// context back and skips the refresh, so a rejected change never lingers in memory.
///
/// Raw messages are never deleted here: a transaction's message is the evidence it came from, and
/// the archive outlives any edit or delete of the transaction.
@MainActor
public final class TransactionMutationService {
    private let context: ModelContext
    private let snapshotRefresher: any WidgetSnapshotRefresher
    private let now: @Sendable () -> Date

    /// The save every write goes through, replaceable so a test can make persistence fail.
    ///
    /// Production leaves this at `ModelContext.save()`; a healthy store cannot be made to fail a save
    /// on demand, so the rollback path is only reachable through this internal seam.
    internal var saveHandler: @MainActor (ModelContext) throws -> Void = { try $0.save() }

    /// Creates the service.
    ///
    /// - Parameters:
    ///   - context: The context every write goes through.
    ///   - snapshotRefresher: The refresher awaited after every transaction change.
    ///   - now: The clock that stamps `createdAt` and `updatedAt`.
    public init(
        context: ModelContext,
        snapshotRefresher: any WidgetSnapshotRefresher,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.context = context
        self.snapshotRefresher = snapshotRefresher
        self.now = now
    }

    // MARK: - Saving

    /// Adds a manual transaction, or applies an edit to an existing one.
    ///
    /// A new transaction is marked ``ParseEngine/manual`` and, when it has a category,
    /// ``CategorySource/manual``. It counts toward the balance from when it happened, because a missed
    /// transaction is already reflected in any balance the bank reported after it. An edit keeps the
    /// raw message, the engine, the raw merchant, and — for a message-sourced transaction — the
    /// instant the message arrived, which is what anchors it among the balance checkpoints. Changing
    /// the category marks it as the person's choice.
    ///
    /// - Throws: ``TransactionMutationError`` when the edit is invalid, before anything changes, or
    ///   the store's error when the save fails.
    @discardableResult
    public func save(_ edit: TransactionEdit, existing: Transaction?) async throws -> Transaction {
        guard edit.amount > 0 else { throw TransactionMutationError.invalidAmount }
        let merchant = edit.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !merchant.isEmpty else { throw TransactionMutationError.missingMerchant }
        guard let account = try account(id: edit.accountID) else { throw TransactionMutationError.missingAccount }
        let category = try edit.categoryID.map { id in
            guard let category = try self.category(id: id) else { throw TransactionMutationError.missingCategory }
            return category
        }
        let note = edit.note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let storedNote = (note?.isEmpty ?? true) ? nil : note
        let instant = now()

        let transaction: Transaction
        if let existing {
            transaction = existing
            if transaction.category?.id != category?.id {
                transaction.category = category
                transaction.categorySource = category == nil ? nil : .manual
            }
            transaction.account = account
            transaction.amount = edit.amount
            transaction.direction = edit.direction
            transaction.occurredAt = edit.occurredAt
            if transaction.parseEngine == .manual {
                transaction.recordedAt = edit.occurredAt
            }
            transaction.merchantDisplay = merchant
            transaction.note = storedNote
            transaction.isTransfer = edit.isTransfer
            transaction.updatedAt = instant
        } else {
            transaction = Transaction(
                account: account,
                amount: edit.amount,
                direction: edit.direction,
                occurredAt: edit.occurredAt,
                recordedAt: edit.occurredAt,
                merchantRaw: merchant,
                merchantDisplay: merchant,
                category: category,
                categorySource: category == nil ? nil : .manual,
                parseEngine: .manual,
                isTransfer: edit.isTransfer,
                note: storedNote,
                createdAt: instant,
                updatedAt: instant
            )
            context.insert(transaction)
        }

        try commit()
        await snapshotRefresher.refresh()
        return transaction
    }

    /// Deletes a transaction and leaves its raw message in the archive, unlinked.
    public func delete(_ transaction: Transaction) async throws {
        transaction.rawMessage?.transaction = nil
        context.delete(transaction)
        try commit()
        await snapshotRefresher.refresh()
    }

    /// Marks a transaction as a transfer between the person's own accounts, or clears the mark.
    public func setTransfer(_ transaction: Transaction, isTransfer: Bool) async throws {
        transaction.isTransfer = isTransfer
        transaction.updatedAt = now()
        try commit()
        await snapshotRefresher.refresh()
    }

    /// Recategorizes a transaction as the person's choice, or clears its category.
    public func setCategory(_ transaction: Transaction, categoryID: UUID?) async throws {
        let category = try categoryID.map { id in
            guard let category = try self.category(id: id) else { throw TransactionMutationError.missingCategory }
            return category
        }
        transaction.category = category
        transaction.categorySource = category == nil ? nil : .manual
        transaction.updatedAt = now()
        try commit()
        await snapshotRefresher.refresh()
    }

    /// Makes every future transaction from this merchant land in the category.
    ///
    /// The merchant becomes a lowercase keyword rule that outranks every existing rule, because the
    /// person asked for "always". A rule with the same keyword is updated and re-enabled instead of
    /// duplicated. Existing transactions are left alone, so the widgets need no refresh.
    public func alwaysCategorize(merchant: String, categoryID: UUID) async throws {
        let keyword = merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else { throw TransactionMutationError.missingMerchant }
        guard let category = try category(id: categoryID) else { throw TransactionMutationError.missingCategory }

        let rules = try context.fetch(FetchDescriptor<CategorizationRule>())
        let topPriority = (rules.map(\.priority).min() ?? 0) - 1
        if let existing = rules.first(where: { $0.keyword.lowercased() == keyword }) {
            existing.category = category
            existing.isEnabled = true
            existing.priority = min(existing.priority, topPriority)
        } else {
            context.insert(CategorizationRule(keyword: keyword, category: category, priority: topPriority, isEnabled: true))
        }
        try commit()
    }

    // MARK: - Helpers

    private func commit() throws {
        do {
            try saveHandler(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    private func account(id: UUID) throws -> Account? {
        try context.fetch(FetchDescriptor<Account>(predicate: #Predicate { $0.id == id })).first
    }

    private func category(id: UUID) throws -> Category? {
        try context.fetch(FetchDescriptor<Category>(predicate: #Predicate { $0.id == id })).first
    }
}
