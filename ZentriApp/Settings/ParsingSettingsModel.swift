import Foundation
import Observation
import SwiftData
import ZentriCore

/// Settings › Parsing: the engine choice, whether the on-device model can run, and how many rules
/// and failed messages there are.
///
/// The engine applies the moment it is picked, through `apply`, which the app wires to
/// `AppState.updateSettings(_:)`. The counts come from one read; a read that throws is
/// ``SettingsLoadState/failed``, never zero rules.
@MainActor
@Observable
final class ParsingSettingsModel {
    /// How far the last read of the counts got.
    private(set) var loadState = SettingsLoadState.loading
    /// How many rules are stored.
    private(set) var ruleCount = 0
    /// How many archived messages failed to parse.
    private(set) var failedMessageCount = 0
    /// The on-device model's availability, once checked.
    private(set) var availability: ModelAvailability?
    /// Why the last engine change failed, for the screen's alert.
    var failureMessage: LocalizedStringResource?
    /// Counts saved changes, which the save haptic watches.
    private(set) var savedCount = 0

    @ObservationIgnored private let settingsStore: SettingsStore
    @ObservationIgnored private let apply: @MainActor (AppSettings) async throws -> Void
    @ObservationIgnored private let modelClient: any TransactionModelClient
    @ObservationIgnored private let fetchRuleCount: @MainActor () throws -> Int
    @ObservationIgnored private let fetchMessages: @MainActor () throws -> [RawMessage]

    /// Creates the model over the supplied context.
    convenience init(
        context: ModelContext,
        settingsStore: SettingsStore,
        modelClient: any TransactionModelClient,
        apply: @escaping @MainActor (AppSettings) async throws -> Void
    ) {
        self.init(
            settingsStore: settingsStore,
            modelClient: modelClient,
            fetchRuleCount: { try context.fetchCount(FetchDescriptor<ParsingRule>()) },
            fetchMessages: { try context.fetch(FetchDescriptor<RawMessage>()) },
            apply: apply
        )
    }

    /// Creates the model over supplied reads, which is how a test makes a read throw.
    init(
        settingsStore: SettingsStore,
        modelClient: any TransactionModelClient,
        fetchRuleCount: @escaping @MainActor () throws -> Int,
        fetchMessages: @escaping @MainActor () throws -> [RawMessage],
        apply: @escaping @MainActor (AppSettings) async throws -> Void
    ) {
        self.settingsStore = settingsStore
        self.modelClient = modelClient
        self.fetchRuleCount = fetchRuleCount
        self.fetchMessages = fetchMessages
        self.apply = apply
    }

    /// The saved engine. Picking a different one saves it straight away.
    var parserMode: ParserMode {
        get { (settingsStore.settings ?? .defaultValue).parserMode }
        set {
            guard newValue != parserMode else { return }
            Task { await setParserMode(newValue) }
        }
    }

    /// Saves a new engine.
    func setParserMode(_ mode: ParserMode) async {
        var updated = settingsStore.settings ?? .defaultValue
        updated.parserMode = mode
        do {
            try await apply(updated)
            savedCount += 1
        } catch {
            failureMessage = "Zentri couldn't save your settings. Try again."
        }
    }

    /// Reads the counts again.
    func refresh() {
        do {
            ruleCount = try fetchRuleCount()
            failedMessageCount = try fetchMessages().count { $0.status == .failed }
            loadState = .loaded
        } catch {
            ruleCount = 0
            failedMessageCount = 0
            loadState = .failed
        }
    }

    /// Asks the on-device model whether it can run here.
    func checkAvailability() async {
        availability = await modelClient.availability()
    }
}
