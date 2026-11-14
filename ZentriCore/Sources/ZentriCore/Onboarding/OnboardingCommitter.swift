import Foundation
import SwiftData

/// Creates everything a first run needs — the first account, its opening balance, the seeded
/// categories and rules, and the saved settings — so onboarding either finishes completely or
/// leaves nothing behind.
///
/// The committer writes the settings document first, then every row, then one `ModelContext.save()`.
/// If that save fails, the rows are rolled back and the settings document is put back the way it was
/// (resaved, or removed when the first run had none), so a failed setup cannot leave the app
/// half-configured with settings that promise an account the store does not have.
///
/// It runs once, from the flow's final step. Nothing here is idempotent beyond seeding: a second
/// call legitimately creates a second account, like any other account-adding screen.
@MainActor
public struct OnboardingCommitter {
    /// The repository the effective settings are written through.
    private let settingsRepository: any SettingsRepository

    /// The save every write goes through, replaceable so a test can make persistence fail.
    ///
    /// Production leaves this at `ModelContext.save()`. The seam exists because the rollback can
    /// only be reached by making the save throw at the instant the committer holds unsaved rows,
    /// which no real store can be made to do on demand. It is internal, so only the test target can
    /// replace it; the public initializer stays the only way to build a committer.
    internal var saveHandler: @MainActor (ModelContext) throws -> Void = { try $0.save() }

    /// Creates a committer that persists settings through `settingsRepository`.
    public init(settingsRepository: any SettingsRepository) {
        self.settingsRepository = settingsRepository
    }

    /// Creates the first account, its opening checkpoint, the seeded categories and rules, and the
    /// settings, in one save.
    ///
    /// - Parameters:
    ///   - settings: The settings the flow collected, except Face ID, which has its own parameter.
    ///   - accountName: The account's name. Surrounding whitespace is trimmed.
    ///   - institutionName: The optional institution. Blank text becomes `nil`.
    ///   - openingBalance: The balance the account starts at, as an `.opening` checkpoint.
    ///   - faceIDEnabled: The optional lock choice. It wins over the value in `settings`, so the
    ///     document that is persisted always matches the toggle the user saw.
    ///   - context: The context the rows are written to and saved.
    /// - Returns: The account that was created.
    /// - Throws: Whatever the repository or the save throws, after the rows and settings have been
    ///   put back as they were.
    @discardableResult
    public func commit(
        settings: AppSettings,
        accountName: String,
        institutionName: String?,
        openingBalance: Decimal,
        faceIDEnabled: Bool,
        context: ModelContext
    ) throws -> Account {
        var effectiveSettings = settings
        effectiveSettings.faceIDEnabled = faceIDEnabled
        let previousSettings = try? settingsRepository.load()

        try settingsRepository.save(effectiveSettings)

        do {
            let now = Date.now
            let account = Account(
                name: accountName.trimmingCharacters(in: .whitespacesAndNewlines),
                institutionName: Self.optionalInstitutionName(institutionName),
                sortOrder: try nextSortOrder(in: context),
                createdAt: now
            )
            context.insert(account)
            let checkpoint = BalanceCheckpoint(
                account: account,
                amount: openingBalance,
                recordedAt: now,
                source: .opening,
                createdAt: now
            )
            context.insert(checkpoint)
            try SeedData.insert(into: context)
            try saveHandler(context)
            return account
        } catch {
            context.rollback()
            restore(previousSettings)
            throw error
        }
    }

    /// The sort order one past the highest one in the store, so the new account sorts last.
    private func nextSortOrder(in context: ModelContext) throws -> Int {
        var descriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\.sortOrder, order: .reverse)])
        descriptor.fetchLimit = 1
        guard let last = try context.fetch(descriptor).first else { return 0 }
        return last.sortOrder + 1
    }

    /// The institution as it should be stored: trimmed, or `nil` when nothing is left.
    private static func optionalInstitutionName(_ institutionName: String?) -> String? {
        guard
            let trimmed = institutionName?.trimmingCharacters(in: .whitespacesAndNewlines),
            !trimmed.isEmpty
        else {
            return nil
        }
        return trimmed
    }

    /// Puts the settings document back to what the committer found.
    ///
    /// Restoring is best effort: the commit already failed, and the caller needs that original
    /// error rather than a second one from the rollback itself.
    private func restore(_ previousSettings: AppSettings?) {
        if let previousSettings {
            try? settingsRepository.save(previousSettings)
        } else {
            try? settingsRepository.remove()
        }
    }
}
