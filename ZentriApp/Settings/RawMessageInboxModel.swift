import Foundation
import Observation
import SwiftData
import ZentriCore

/// The raw-message inbox's data and actions: the archive filtered by status, reprocessing, copying,
/// deleting, and clearing.
///
/// Messages are listed newest first. Reprocessing goes through `reprocess`, which the app wires to
/// `AppState.reprocess(_:accountID:)`; deleting goes through the archive's ``RawMessageReprocessor``,
/// which never deletes a transaction. After every change the model reads again and calls
/// `onMutation`.
@MainActor
@Observable
final class RawMessageInboxModel {
    /// How far the last read got. An empty list only means "no messages" once loaded.
    private(set) var loadState = SettingsLoadState.loading
    /// The selected status filter.
    var filter = RawMessageFilter.failed {
        didSet { applyFilter() }
    }
    /// The messages under the selected filter, newest first.
    private(set) var rows: [RawMessageListItem] = []
    /// How many messages each filter holds.
    private(set) var counts: [RawMessageFilter: Int] = [:]
    /// The active accounts, offered when a message's account is ambiguous.
    private(set) var accounts: [TransactionAccountOption] = []
    /// The categories the transaction detail offers.
    private(set) var categories: [TransactionCategoryOption] = []

    @ObservationIgnored private var allItems: [RawMessageListItem] = []
    @ObservationIgnored private var storedMessages: [UUID: RawMessage] = [:]
    @ObservationIgnored private var ruleNames: [UUID: String] = [:]
    @ObservationIgnored private let fetchMessages: @MainActor () throws -> [RawMessage]
    @ObservationIgnored private let fetchRules: @MainActor () throws -> [ParsingRule]
    @ObservationIgnored private let fetchAccounts: @MainActor () throws -> [Account]
    @ObservationIgnored private let fetchCategories: @MainActor () throws -> [ZentriCore.Category]
    @ObservationIgnored private let reprocessAction: @MainActor (RawMessage, UUID?) async -> IngestionOutcome
    @ObservationIgnored private let reprocessFailuresAction: @MainActor () async -> [IngestionOutcome]
    @ObservationIgnored private let archive: RawMessageReprocessor
    @ObservationIgnored private let onMutation: @MainActor () -> Void

    /// Creates the model over the supplied context.
    convenience init(
        context: ModelContext,
        archive: RawMessageReprocessor,
        reprocess: @escaping @MainActor (RawMessage, UUID?) async -> IngestionOutcome,
        reprocessFailures: @escaping @MainActor () async -> [IngestionOutcome],
        onMutation: @escaping @MainActor () -> Void
    ) {
        self.init(
            fetchMessages: { try context.fetch(FetchDescriptor<RawMessage>()) },
            fetchRules: { try context.fetch(FetchDescriptor<ParsingRule>()) },
            fetchAccounts: { try context.fetch(FetchDescriptor<Account>()) },
            fetchCategories: { try context.fetch(FetchDescriptor<ZentriCore.Category>()) },
            archive: archive,
            reprocess: reprocess,
            reprocessFailures: reprocessFailures,
            onMutation: onMutation
        )
    }

    /// Creates the model over supplied reads, which is how a test makes a read throw.
    init(
        fetchMessages: @escaping @MainActor () throws -> [RawMessage],
        fetchRules: @escaping @MainActor () throws -> [ParsingRule],
        fetchAccounts: @escaping @MainActor () throws -> [Account],
        fetchCategories: @escaping @MainActor () throws -> [ZentriCore.Category],
        archive: RawMessageReprocessor,
        reprocess: @escaping @MainActor (RawMessage, UUID?) async -> IngestionOutcome,
        reprocessFailures: @escaping @MainActor () async -> [IngestionOutcome],
        onMutation: @escaping @MainActor () -> Void
    ) {
        self.fetchMessages = fetchMessages
        self.fetchRules = fetchRules
        self.fetchAccounts = fetchAccounts
        self.fetchCategories = fetchCategories
        self.archive = archive
        self.reprocessAction = reprocess
        self.reprocessFailuresAction = reprocessFailures
        self.onMutation = onMutation
    }

    /// Whether the archive holds any message at all.
    var hasMessages: Bool {
        !allItems.isEmpty
    }

    /// How many messages failed, which is what "Reprocess Failures" would try.
    var failedCount: Int {
        allItems.count { $0.status == .failed }
    }

    /// Reads the archive again. A read that throws becomes ``SettingsLoadState/failed`` with no
    /// rows, never an empty inbox.
    func refresh() {
        do {
            let messages = try fetchMessages().sorted { lhs, rhs in
                if lhs.receivedAt != rhs.receivedAt {
                    return lhs.receivedAt > rhs.receivedAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            ruleNames = Dictionary(try fetchRules().map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
            accounts = try fetchAccounts()
                .filter { $0.archivedAt == nil }
                .sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
                .map { TransactionAccountOption(id: $0.id, name: $0.name) }
            categories = try fetchCategories()
                .sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
                .map { TransactionCategoryOption(id: $0.id, name: $0.name, symbolName: $0.symbolName, colorToken: $0.colorToken) }
            storedMessages = Dictionary(messages.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            allItems = messages.map(item(for:))
            counts = Dictionary(
                uniqueKeysWithValues: RawMessageFilter.allCases.map { filter in
                    (filter, allItems.count { filter.includes($0.status) })
                }
            )
            loadState = .loaded
        } catch {
            storedMessages = [:]
            allItems = []
            counts = [:]
            accounts = []
            categories = []
            loadState = .failed
        }
        applyFilter()
    }

    /// The message with `id`, as last read.
    func message(id: UUID) -> RawMessageListItem? {
        allItems.first { $0.id == id }
    }

    /// Whether reprocessing `id` needs the person to choose an account first: it has no
    /// transaction to take the account from and more than one account could own it.
    func needsAccountChoice(id: UUID) -> Bool {
        guard let message = message(id: id) else { return false }
        return !message.hasTransaction && accounts.count > 1
    }

    /// Reprocesses one message, optionally as the account the person chose.
    func reprocess(id: UUID, accountID: UUID? = nil) async -> IngestionOutcome? {
        guard let message = storedMessages[id] else { return nil }
        let outcome = await reprocessAction(message, accountID)
        didMutate()
        return outcome
    }

    /// Reprocesses every failed message.
    func reprocessFailures() async -> ReprocessSummary {
        let summary = ReprocessSummary(outcomes: await reprocessFailuresAction())
        didMutate()
        return summary
    }

    /// Deletes one message; its transaction, if any, stays.
    func delete(id: UUID) throws {
        guard let message = storedMessages[id] else { return }
        try archive.delete(message)
        didMutate()
    }

    /// Deletes every message; every transaction stays.
    func clearArchive() throws {
        try archive.clearArchive()
        didMutate()
    }

    /// The transaction detail's selection for a message's transaction.
    func transactionSelection(forMessage id: UUID) -> TransactionSelection? {
        guard let transaction = storedMessages[id]?.transaction else { return nil }
        return TransactionSelection(
            id: transaction.id,
            transaction: transaction,
            matchedRuleName: transaction.matchedRuleID.flatMap { ruleNames[$0] }
        )
    }

    private func applyFilter() {
        rows = allItems.filter { filter.includes($0.status) }
    }

    private func didMutate() {
        refresh()
        onMutation()
    }

    private func item(for message: RawMessage) -> RawMessageListItem {
        RawMessageListItem(
            id: message.id,
            text: message.text,
            sender: message.sender,
            receivedAt: message.receivedAt,
            status: message.status,
            engine: message.engine,
            errorDescription: message.errorDescription,
            matchedRuleID: message.matchedRuleID,
            matchedRuleName: message.matchedRuleID.flatMap { ruleNames[$0] },
            hasTransaction: message.transaction != nil
        )
    }
}
