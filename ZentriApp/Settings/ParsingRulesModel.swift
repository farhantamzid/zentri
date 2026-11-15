import Foundation
import Observation
import SwiftData
import ZentriCore

/// The parsing rule list's data and actions, run through ``ParsingRuleMutationService``.
///
/// Rules are grouped by account and then by direction, each group in the order the engine runs it:
/// priority, then creation date. The list can be limited to one account, which is how an account's
/// detail opens its own rules. After every successful change the model reads again, remembers that
/// the rules changed — which is when "Reprocess Failures" is offered — and calls `onMutation`.
@MainActor
@Observable
final class ParsingRulesModel {
    /// How far the last read got. An empty list only means "no rules" once loaded.
    private(set) var loadState = SettingsLoadState.loading
    /// The rules, grouped by account and direction.
    private(set) var sections: [ParsingRuleSection] = []
    /// The accounts a rule can belong to: the active ones, plus the shown account when it is archived.
    private(set) var accounts: [TransactionAccountOption] = []
    /// How many archived messages failed to parse.
    private(set) var failedMessageCount = 0
    /// Whether a rule was added, edited, switched, or deleted since the screen opened.
    private(set) var hasChangedRules = false

    /// The account the list is limited to, or `nil` for every account.
    let accountID: UUID?

    @ObservationIgnored private var storedRules: [UUID: ParsingRule] = [:]
    @ObservationIgnored private let fetchRules: @MainActor () throws -> [ParsingRule]
    @ObservationIgnored private let fetchAccounts: @MainActor () throws -> [Account]
    @ObservationIgnored private let fetchMessages: @MainActor () throws -> [RawMessage]
    @ObservationIgnored private let service: ParsingRuleMutationService
    @ObservationIgnored private let reprocessFailuresAction: @MainActor () async -> [IngestionOutcome]
    @ObservationIgnored private let onMutation: @MainActor () -> Void

    /// Creates the model over the supplied context.
    convenience init(
        accountID: UUID?,
        context: ModelContext,
        service: ParsingRuleMutationService,
        reprocessFailures: @escaping @MainActor () async -> [IngestionOutcome],
        onMutation: @escaping @MainActor () -> Void
    ) {
        self.init(
            accountID: accountID,
            fetchRules: { try context.fetch(FetchDescriptor<ParsingRule>()) },
            fetchAccounts: { try context.fetch(FetchDescriptor<Account>()) },
            fetchMessages: { try context.fetch(FetchDescriptor<RawMessage>()) },
            service: service,
            reprocessFailures: reprocessFailures,
            onMutation: onMutation
        )
    }

    /// Creates the model over supplied reads, which is how a test makes a read throw.
    init(
        accountID: UUID?,
        fetchRules: @escaping @MainActor () throws -> [ParsingRule],
        fetchAccounts: @escaping @MainActor () throws -> [Account],
        fetchMessages: @escaping @MainActor () throws -> [RawMessage],
        service: ParsingRuleMutationService,
        reprocessFailures: @escaping @MainActor () async -> [IngestionOutcome],
        onMutation: @escaping @MainActor () -> Void
    ) {
        self.accountID = accountID
        self.fetchRules = fetchRules
        self.fetchAccounts = fetchAccounts
        self.fetchMessages = fetchMessages
        self.service = service
        self.reprocessFailuresAction = reprocessFailures
        self.onMutation = onMutation
    }

    /// Whether "Reprocess Failures" is worth offering: the rules changed and something failed.
    var offersReprocessFailures: Bool {
        hasChangedRules && failedMessageCount > 0
    }

    /// The account a new rule starts on: the shown one, or the first active account.
    var defaultAccountID: UUID? {
        accountID ?? accounts.first?.id
    }

    /// Reads the rules, accounts, and failure count again. A read that throws becomes
    /// ``SettingsLoadState/failed`` with no rows, never an empty list.
    func refresh() {
        do {
            let allAccounts = try fetchAccounts().sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
            let rules = StoredParsingRules.ordered(try fetchRules())
                .filter { accountID == nil || $0.account.id == accountID }
            failedMessageCount = try fetchMessages().count { $0.status == .failed }
            storedRules = Dictionary(rules.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            accounts = allAccounts
                .filter { $0.archivedAt == nil || $0.id == accountID }
                .map { TransactionAccountOption(id: $0.id, name: $0.name) }
            sections = Self.sections(for: rules, accounts: allAccounts)
            loadState = .loaded
        } catch {
            storedRules = [:]
            sections = []
            accounts = []
            failedMessageCount = 0
            loadState = .failed
        }
    }

    /// Adds a rule.
    func create(_ draft: ParsingRuleDraft) throws {
        try service.create(draft)
        didMutate()
    }

    /// Replaces a rule's values.
    func update(id: UUID, with draft: ParsingRuleDraft) throws {
        guard let rule = storedRules[id] else { return }
        try service.update(rule, with: draft)
        didMutate()
    }

    /// Turns a rule on or off. Turning on a rule whose pattern is broken is refused.
    func setEnabled(_ isEnabled: Bool, id: UUID) throws {
        guard let rule = storedRules[id] else { return }
        try service.setEnabled(rule, isEnabled: isEnabled)
        didMutate()
    }

    /// Deletes a rule; transactions it produced keep their values.
    func delete(id: UUID) throws {
        guard let rule = storedRules[id] else { return }
        try service.delete(rule)
        didMutate()
    }

    /// Reprocesses every failed message with the current rules.
    func reprocessFailures() async -> ReprocessSummary {
        let summary = ReprocessSummary(outcomes: await reprocessFailuresAction())
        hasChangedRules = false
        refresh()
        return summary
    }

    private func didMutate() {
        hasChangedRules = true
        refresh()
        onMutation()
    }

    /// The rules grouped by account, in account order, then debits before credits.
    private static func sections(for rules: [ParsingRule], accounts: [Account]) -> [ParsingRuleSection] {
        accounts.flatMap { account in
            Direction.allCases.compactMap { direction -> ParsingRuleSection? in
                let items = rules
                    .filter { $0.account.id == account.id && $0.direction == direction }
                    .map(Self.item(for:))
                guard !items.isEmpty else { return nil }
                return ParsingRuleSection(
                    accountID: account.id,
                    accountName: account.name,
                    direction: direction,
                    rules: items
                )
            }
        }
    }

    private static func item(for rule: ParsingRule) -> ParsingRuleListItem {
        ParsingRuleListItem(
            id: rule.id,
            accountID: rule.account.id,
            accountName: rule.account.name,
            name: rule.name,
            direction: rule.direction,
            pattern: rule.pattern,
            dateFormat: rule.dateFormat,
            isCaseInsensitive: rule.isCaseInsensitive,
            dotMatchesNewlines: rule.dotMatchesNewlines,
            priority: rule.priority,
            isEnabled: rule.isEnabled,
            isPatternValid: RegexValidator.validateRule(pattern: rule.pattern) == nil
        )
    }
}
