import Foundation
import SwiftData

/// The only writer of the person's parsing rules: adding, editing, switching, and deleting them.
///
/// Every pattern is checked with ``RegexValidator`` before it is stored — it must compile and have
/// an `amount` group — and so is any rule being switched on. That is the guard against a broken
/// pattern: the rule engine reports a pattern that does not compile as a failure for every message
/// it sees, so an enabled broken rule would fail even one-time passwords. Turning a rule off is
/// always allowed, so a broken imported rule can still be silenced.
///
/// Rules do not change any balance, so no change here refreshes the widgets.
@MainActor
public final class ParsingRuleMutationService {
    private let context: ModelContext
    private let now: @Sendable () -> Date

    /// The save every write goes through, replaceable so a test can make persistence fail.
    internal var saveHandler: @MainActor (ModelContext) throws -> Void = { try $0.save() }

    public init(context: ModelContext, now: @escaping @Sendable () -> Date = { .now }) {
        self.context = context
        self.now = now
    }

    /// Adds a rule.
    ///
    /// - Throws: ``ParsingRuleMutationError`` before anything is written, or the store's error.
    @discardableResult
    public func create(_ draft: ParsingRuleDraft) throws -> ParsingRule {
        let values = try validated(draft)
        let instant = now()
        let rule = ParsingRule(
            account: values.account,
            name: values.name,
            direction: draft.direction,
            pattern: draft.pattern,
            dateFormat: values.dateFormat,
            isCaseInsensitive: draft.isCaseInsensitive,
            dotMatchesNewlines: draft.dotMatchesNewlines,
            priority: draft.priority,
            isEnabled: draft.isEnabled,
            createdAt: instant,
            updatedAt: instant
        )
        context.insert(rule)
        try commit()
        return rule
    }

    /// Replaces every field of a rule. Its creation date, which breaks priority ties, is kept.
    public func update(_ rule: ParsingRule, with draft: ParsingRuleDraft) throws {
        let values = try validated(draft)
        rule.account = values.account
        rule.name = values.name
        rule.direction = draft.direction
        rule.pattern = draft.pattern
        rule.dateFormat = values.dateFormat
        rule.isCaseInsensitive = draft.isCaseInsensitive
        rule.dotMatchesNewlines = draft.dotMatchesNewlines
        rule.priority = draft.priority
        rule.isEnabled = draft.isEnabled
        rule.updatedAt = now()
        try commit()
    }

    /// Switches a rule on or off. Switching on checks the pattern first.
    public func setEnabled(_ rule: ParsingRule, isEnabled: Bool) throws {
        if isEnabled, let error = RegexValidator.validateRule(pattern: rule.pattern) {
            throw ParsingRuleMutationError.invalidPattern(error)
        }
        rule.isEnabled = isEnabled
        rule.updatedAt = now()
        try commit()
    }

    /// Deletes a rule. Transactions it produced keep their values and their matched-rule id.
    public func delete(_ rule: ParsingRule) throws {
        context.delete(rule)
        try commit()
    }

    // MARK: - Helpers

    private struct ValidatedValues {
        let account: Account
        let name: String
        let dateFormat: String?
    }

    private func validated(_ draft: ParsingRuleDraft) throws -> ValidatedValues {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ParsingRuleMutationError.missingName }
        if let error = RegexValidator.validateRule(pattern: draft.pattern) {
            throw ParsingRuleMutationError.invalidPattern(error)
        }
        let accountID = draft.accountID
        guard let account = try context.fetch(
            FetchDescriptor<Account>(predicate: #Predicate { $0.id == accountID })
        ).first else {
            throw ParsingRuleMutationError.missingAccount
        }
        let format = draft.dateFormat?.trimmingCharacters(in: .whitespacesAndNewlines)
        return ValidatedValues(
            account: account,
            name: name,
            dateFormat: (format?.isEmpty ?? true) ? nil : format
        )
    }

    private func commit() throws {
        do {
            try saveHandler(context)
        } catch {
            context.rollback()
            throw error
        }
    }
}
