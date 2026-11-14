import Foundation
import Testing
import ZentriCore
@testable import ZentriApp

/// A parser builder the retry must never reach: with no pending messages there is nothing to parse.
private struct UnusedParserBuilder: ParserBuilding {
    func makeParser(for mode: ParserMode, rules: [ParsingRuleSpec]) -> any TransactionParsing {
        Issue.record("A retry with no pending messages must not build a parser.")
        return NotATransactionParser()
    }
}

/// A parser that is never asked to parse anything.
private struct NotATransactionParser: TransactionParsing {
    func parse(_ input: ParseInput) async -> ParseResult {
        .notTransaction
    }
}

@MainActor
private func makeAppState() throws -> (AppState, SettingsStore) {
    let container = try ZentriContainer.make(inMemory: true)
    let repository = InMemorySettingsRepository()
    let settingsStore = SettingsStore(
        repository: repository,
        deleteStoredSettings: { repository.clear() }
    )
    let appState = AppState(
        container: container,
        settingsStore: settingsStore,
        parserBuilder: UnusedParserBuilder(),
        snapshotStore: FileWidgetSnapshotStore(fileURL: nil)
    )
    return (appState, settingsStore)
}

@MainActor
@Test func retryPendingIngestionIsANoOpUntilSettingsExist() async throws {
    let (appState, settingsStore) = try makeAppState()

    await appState.retryPendingIngestion()
    #expect(appState.dataRevision == 0)

    try settingsStore.completeOnboarding(.defaultValue)
    await appState.retryPendingIngestion()
    #expect(appState.dataRevision == 1)

    // A second appearance must not retry again in the same session.
    await appState.retryPendingIngestion()
    #expect(appState.dataRevision == 1)
}

@MainActor
@Test func moneyFormatFollowsTheLiveSettings() throws {
    let (appState, settingsStore) = try makeAppState()
    var settings = AppSettings.defaultValue
    settings.currencyCode = "INR"
    settings.numberGrouping = .indian
    try settingsStore.save(settings)

    let format = appState.moneyFormat(locale: Locale(identifier: "en_US"))
    #expect(format.currencyString(from: 1_000_000) == "₹10,00,000.00")
}
