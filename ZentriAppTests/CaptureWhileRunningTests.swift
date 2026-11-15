import Foundation
import SwiftData
import Testing
import ZentriCore
@testable import ZentriApp

/// A builder whose parser reads every message as a 12.50 debit at KFC, or cancels it.
private struct RunningAppParserBuilder: ParserBuilding {
    let result: ParseResult

    func makeParser(for mode: ParserMode, rules: [ParsingRuleSpec]) -> any TransactionParsing {
        RunningAppParser(result: result)
    }
}

private struct RunningAppParser: TransactionParsing {
    let result: ParseResult

    func parse(_ input: ParseInput) async -> ParseResult {
        result
    }
}

private let runningAppDraft = TransactionDraft(
    direction: .debit,
    amount: Decimal(string: "12.50") ?? 0,
    merchant: "KFC"
)

/// The app's shared state over the parsing test store, with onboarding finished.
@MainActor
private func makeRunningApp(
    _ store: ParsingTestStore,
    result: ParseResult = .transaction(runningAppDraft)
) throws -> AppState {
    let settingsStore = SettingsStore(repository: InMemorySettingsRepository())
    try settingsStore.save(AppSettings(parserMode: .rules))
    return AppState(
        container: store.container,
        settingsStore: settingsStore,
        parserBuilder: RunningAppParserBuilder(result: result),
        modelClient: UnavailableModelClient(),
        snapshotStore: FileWidgetSnapshotStore(fileURL: nil)
    )
}

/// A capture made while Zentri is in memory — in the foreground, or suspended when the message
/// arrives — goes through the app's own container and tells the app, so the screens it already has
/// open show the new transaction without a relaunch.
@MainActor
@Suite
struct CaptureWhileRunningTests {
    @Test func captureWhileTheAppIsAliveReachesItsOpenScreens() async throws {
        let store = try ParsingTestStore()
        let appState = try makeRunningApp(store)
        // The Overview has already read the store, so its context holds fetched models.
        let overview = OverviewModel(context: appState.container.mainContext)
        overview.refresh()
        let balanceBefore = try #require(overview.summary?.balance)
        #expect(overview.summary?.recentTransactions.isEmpty == true)
        let revisionBefore = appState.dataRevision

        let outcome = await appState.capture(
            IngestionRequest(text: "MYBANK: USD12.50 spent at KFC.", sender: "MYBANK", receivedAt: .now)
        )

        guard case .transaction(let id) = outcome else {
            Issue.record("Expected a transaction, got \(outcome)")
            return
        }
        #expect(appState.dataRevision == revisionBefore + 1)
        overview.refresh()
        #expect(overview.summary?.recentTransactions.map(\.id) == [id])
        #expect(overview.summary?.balance == balanceBefore - (Decimal(string: "12.50") ?? 0))
    }

    @Test func returningToTheForegroundReloadsAndRetriesPendingMessages() async throws {
        let store = try ParsingTestStore()
        try store.addRule("Card debit")
        let pending = try store.addMessage(status: .processing)
        let appState = try makeRunningApp(store, result: .transaction(runningAppDraft))
        // The launch retry already ran this session.
        await appState.retryPendingIngestion()
        #expect(pending.status == .parsed)
        let revisionAfterLaunch = appState.dataRevision
        // A capture cancelled while the app was suspended leaves its message processing.
        let laterPending = try store.addMessage("MYBANK: RM9.00 spent at Later Cafe. Thank you.", status: .processing)

        await appState.sceneDidBecomeActive()

        #expect(appState.dataRevision > revisionAfterLaunch)
        #expect(laterPending.status == .parsed)
    }

    @Test func returningToTheForegroundBeforeSetupDoesNothingButReload() async throws {
        let store = try ParsingTestStore()
        let pending = try store.addMessage(status: .processing)
        let appState = AppState(
            container: store.container,
            settingsStore: SettingsStore(repository: InMemorySettingsRepository()),
            parserBuilder: RunningAppParserBuilder(result: .transaction(runningAppDraft)),
            modelClient: UnavailableModelClient(),
            snapshotStore: FileWidgetSnapshotStore(fileURL: nil)
        )

        await appState.sceneDidBecomeActive()

        #expect(appState.dataRevision == 1)
        #expect(pending.status == .processing)
    }
}
