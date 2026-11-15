import Foundation
import Observation
import SwiftData
import ZentriCore

/// The rule tester: a sample message, the account to test as, and the rules' and model's answers.
///
/// The tester never writes. It reads the stored rules and accounts, hands them to
/// ``RuleTesterService`` — which parses off the main actor — and keeps only the answer. A newer run
/// supersedes an older one: the older run's task is cancelled and its result discarded.
@MainActor
@Observable
final class RuleTesterModel {
    /// How far the read of rules and accounts got; the tester cannot run without it.
    private(set) var loadState = SettingsLoadState.loading
    /// The accounts the tester can test as.
    private(set) var accounts: [TransactionAccountOption] = []
    /// The stored rules' names, to name the matched and competing rules.
    private(set) var ruleNames: [UUID: String] = [:]
    /// The last run.
    private(set) var state = RuleTestState.idle

    /// The sample message.
    var text = ""
    /// The account to test as, or `nil` to run every account's rules.
    var accountID: UUID?
    /// Whether the on-device model runs beside the rules.
    var comparesWithModel = false

    @ObservationIgnored private var rules: [ParsingRuleSpec] = []
    @ObservationIgnored private var runTask: Task<Void, Never>?
    @ObservationIgnored private let fetchRules: @MainActor () throws -> [ParsingRule]
    @ObservationIgnored private let fetchAccounts: @MainActor () throws -> [Account]
    @ObservationIgnored private let tester: RuleTesterService

    /// Creates the model over the supplied context.
    convenience init(context: ModelContext, tester: RuleTesterService) {
        self.init(
            fetchRules: { try context.fetch(FetchDescriptor<ParsingRule>()) },
            fetchAccounts: { try context.fetch(FetchDescriptor<Account>()) },
            tester: tester
        )
    }

    /// Creates the model over supplied reads, which is how a test makes a read throw.
    init(
        fetchRules: @escaping @MainActor () throws -> [ParsingRule],
        fetchAccounts: @escaping @MainActor () throws -> [Account],
        tester: RuleTesterService
    ) {
        self.fetchRules = fetchRules
        self.fetchAccounts = fetchAccounts
        self.tester = tester
    }

    /// Whether there is something to test.
    var canRun: Bool {
        loadState == .loaded && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The finished comparison, if the last run finished.
    var comparison: RuleComparison? {
        if case .finished(let comparison) = state { return comparison }
        return nil
    }

    /// Reads the rules and accounts again. A read that throws becomes ``SettingsLoadState/failed``,
    /// never "no rules", which would make every message look unmatched.
    func refresh() {
        do {
            let storedRules = StoredParsingRules.ordered(try fetchRules())
            let storedAccounts = try fetchAccounts()
                .filter { $0.archivedAt == nil }
                .sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
            rules = storedRules.map(\.spec)
            ruleNames = Dictionary(storedRules.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
            accounts = storedAccounts.map { TransactionAccountOption(id: $0.id, name: $0.name) }
            if let accountID, !accounts.contains(where: { $0.id == accountID }) {
                self.accountID = nil
            }
            loadState = .loaded
        } catch {
            rules = []
            ruleNames = [:]
            accounts = []
            loadState = .failed
        }
    }

    /// Starts a run, cancelling one already in progress.
    func startRun() {
        runTask?.cancel()
        runTask = Task { await run() }
    }

    /// Tests the sample and keeps the answer, unless a newer run replaced this one.
    func run() async {
        guard canRun else { return }
        state = .running
        let comparison = await tester.test(
            text: text,
            accountID: accountID,
            rules: rules,
            mode: comparesWithModel ? .hybrid : .rules
        )
        guard !Task.isCancelled else { return }
        state = .finished(comparison)
    }

    /// The name of a rule, or a placeholder for one that has been deleted since.
    func ruleName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return ruleNames[id] ?? String(localized: "A rule that no longer exists")
    }
}
