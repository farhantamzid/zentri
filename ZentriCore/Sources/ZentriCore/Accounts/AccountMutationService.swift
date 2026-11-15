import Foundation
import SwiftData

/// The only writer of the person's own changes to accounts: adding one, renaming it, setting its
/// balance, and archiving or restoring it.
///
/// Every mutation validates first, saves once, and then awaits one
/// ``WidgetSnapshotRefresher/refresh()``, so when the call returns the widgets already show the new
/// combined balance and the caller can tell the rest of the app to reload. A save that fails rolls
/// the context back and skips the refresh, so a rejected change never lingers in memory.
///
/// Accounts are archived rather than deleted: an archived account leaves the combined balance and the
/// pickers but keeps its transactions and checkpoints, so history never silently changes.
@MainActor
public final class AccountMutationService {
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
    ///   - snapshotRefresher: The refresher awaited after every change.
    ///   - now: The clock that stamps new accounts, checkpoints, and archive dates.
    public init(
        context: ModelContext,
        snapshotRefresher: any WidgetSnapshotRefresher,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.context = context
        self.snapshotRefresher = snapshotRefresher
        self.now = now
    }

    /// Adds an account that starts at `openingBalance`.
    ///
    /// The account sorts after every existing one and gets an ``CheckpointSource/opening``
    /// checkpoint dated now, exactly as onboarding creates the first account: balance math and
    /// backup validation both rely on every account having a checkpoint.
    ///
    /// - Throws: ``AccountMutationError`` before anything is written, or the store's error when the
    ///   save fails.
    @discardableResult
    public func create(name: String, institutionName: String?, openingBalance: Decimal) async throws -> Account {
        let name = try validatedName(name)
        guard openingBalance >= 0 else { throw AccountMutationError.negativeBalance }

        let instant = now()
        let account = Account(
            name: name,
            institutionName: Self.optionalText(institutionName),
            sortOrder: try nextSortOrder(),
            createdAt: instant
        )
        context.insert(account)
        context.insert(
            BalanceCheckpoint(
                account: account,
                amount: openingBalance,
                recordedAt: instant,
                source: .opening,
                createdAt: instant
            )
        )
        try commit()
        await snapshotRefresher.refresh()
        return account
    }

    /// Records the account's balance as `amount` at `date`, as a ``CheckpointSource/manual``
    /// checkpoint.
    ///
    /// Transactions recorded after `date` still apply on top of it. The date may not be in the future
    /// or before the newest existing checkpoint, because either way the new checkpoint would not
    /// produce the balance the person just typed.
    ///
    /// - Throws: ``AccountMutationError`` before anything is written, or the store's error when the
    ///   save fails.
    @discardableResult
    public func setBalance(account: Account, amount: Decimal, at date: Date) async throws -> BalanceCheckpoint {
        guard amount >= 0 else { throw AccountMutationError.negativeBalance }
        let instant = now()
        guard date <= instant else { throw AccountMutationError.balanceDateInFuture }
        if let latest = account.checkpoints.map(\.recordedAt).max(), date < latest {
            throw AccountMutationError.balanceDateBeforeLatestCheckpoint
        }

        let checkpoint = BalanceCheckpoint(
            account: account,
            amount: amount,
            recordedAt: date,
            source: .manual,
            createdAt: instant
        )
        context.insert(checkpoint)
        try commit()
        await snapshotRefresher.refresh()
        return checkpoint
    }

    /// Renames the account and replaces its institution; blank institution text clears it.
    public func rename(_ account: Account, name: String, institutionName: String?) async throws {
        account.name = try validatedName(name)
        account.institutionName = Self.optionalText(institutionName)
        try commit()
        await snapshotRefresher.refresh()
    }

    /// Hides the account from the combined balance, the widgets, and the pickers, keeping its history.
    public func archive(_ account: Account) async throws {
        account.archivedAt = now()
        try commit()
        await snapshotRefresher.refresh()
    }

    /// Returns an archived account to the combined balance and the pickers.
    public func unarchive(_ account: Account) async throws {
        account.archivedAt = nil
        try commit()
        await snapshotRefresher.refresh()
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

    private func validatedName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AccountMutationError.missingName }
        return trimmed
    }

    /// The sort order one past the highest one in the store, so the new account sorts last.
    private func nextSortOrder() throws -> Int {
        var descriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\.sortOrder, order: .reverse)])
        descriptor.fetchLimit = 1
        guard let last = try context.fetch(descriptor).first else { return 0 }
        return last.sortOrder + 1
    }

    /// The text as it should be stored: trimmed, or `nil` when nothing is left.
    private static func optionalText(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
