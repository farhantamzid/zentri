import Foundation
import SwiftData
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
    let settingsStore = SettingsStore(repository: InMemorySettingsRepository())
    let appState = AppState(
        container: container,
        settingsStore: settingsStore,
        parserBuilder: UnusedParserBuilder(),
        modelClient: UnavailableModelClient(),
        snapshotStore: FileWidgetSnapshotStore(fileURL: nil),
        timelineReloader: InertTimelineReloader()
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

@MainActor
@Test func updateSettingsSavesAndRewritesTheWidgetSnapshot() async throws {
    let container = try ZentriContainer.make(inMemory: true)
    let settingsStore = SettingsStore(repository: InMemorySettingsRepository())
    try settingsStore.save(.defaultValue)
    let url = FileManager.default.temporaryDirectory.appending(path: "zentri-settings-snapshot-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let snapshotStore = FileWidgetSnapshotStore(fileURL: url)
    let appState = AppState(
        container: container,
        settingsStore: settingsStore,
        parserBuilder: UnusedParserBuilder(),
        modelClient: UnavailableModelClient(),
        snapshotStore: snapshotStore,
        timelineReloader: InertTimelineReloader()
    )
    var settings = AppSettings.defaultValue
    settings.currencyCode = "BDT"
    settings.numberGrouping = .indian

    try await appState.updateSettings(settings)

    #expect(settingsStore.settings == settings)
    #expect(snapshotStore.read()?.currencyCode == "BDT")
    #expect(snapshotStore.read()?.numberGrouping == .indian)
}

@MainActor
@Test func eraseAllDataEmptiesTheStoreSnapshotAndSettings() async throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = container.mainContext
    try SeedData.seed(into: context)
    let account = Account(name: "Everyday", sortOrder: 0, createdAt: .now)
    context.insert(account)
    context.insert(BalanceCheckpoint(account: account, amount: 10, recordedAt: .now, source: .opening))
    try context.save()
    let settingsStore = SettingsStore(repository: InMemorySettingsRepository())
    try settingsStore.save(.defaultValue)
    let url = FileManager.default.temporaryDirectory.appending(path: "zentri-erase-snapshot-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let snapshotStore = FileWidgetSnapshotStore(fileURL: url)
    let appState = AppState(
        container: container,
        settingsStore: settingsStore,
        parserBuilder: UnusedParserBuilder(),
        modelClient: UnavailableModelClient(),
        snapshotStore: snapshotStore,
        timelineReloader: InertTimelineReloader()
    )
    await appState.snapshotRefresher.refresh()
    #expect(snapshotStore.read() != nil)
    appState.selectedTab = .settings
    appState.transactionFilter.searchText = "cafe"

    try appState.eraseAllData()

    #expect(try context.fetchCount(FetchDescriptor<Account>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<ZentriCore.Category>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<CategorizationRule>()) == 0)
    #expect(snapshotStore.read() == nil)
    // No settings sends the root back to onboarding.
    #expect(settingsStore.settings == nil)
    #expect(appState.selectedTab == .overview)
    #expect(appState.transactionFilter == TransactionFilter())
    #expect(appState.dataRevision == 1)
}

// MARK: - Settings recovery (I9)

@MainActor
private func makeRecoveringAppState(accountNames: [String]) throws -> (AppState, SettingsStore) {
    let container = try ZentriContainer.make(inMemory: true)
    for (index, name) in accountNames.enumerated() {
        container.mainContext.insert(Account(name: name, sortOrder: index, createdAt: .now))
    }
    try container.mainContext.save()
    let settingsStore = SettingsStore(repository: UnreadableSettingsRepository())
    try? settingsStore.load()
    let appState = AppState(
        container: container,
        settingsStore: settingsStore,
        parserBuilder: UnusedParserBuilder(),
        modelClient: UnavailableModelClient(),
        snapshotStore: FileWidgetSnapshotStore(fileURL: nil),
        timelineReloader: InertTimelineReloader()
    )
    return (appState, settingsStore)
}

/// With accounts already stored, "Use Defaults" saves default settings and opens the app: running
/// onboarding again would add a second account and opening balance beside the existing ones.
@MainActor
@Test func useDefaultSettingsKeepsTheStoredAccountsAndOpensTheApp() async throws {
    let (appState, settingsStore) = try makeRecoveringAppState(accountNames: ["Everyday"])
    #expect(settingsStore.loadFailure != nil)

    try await appState.useDefaultSettings()

    #expect(settingsStore.loadFailure == nil)
    #expect(settingsStore.settings == .defaultValue)
    #expect(try appState.container.mainContext.fetchCount(FetchDescriptor<Account>()) == 1)
}

/// With no account stored there is nothing to keep, so setup runs as on a fresh install.
@MainActor
@Test func useDefaultSettingsWithoutAccountsReturnsToSetup() async throws {
    let (appState, settingsStore) = try makeRecoveringAppState(accountNames: [])

    try await appState.useDefaultSettings()

    #expect(settingsStore.loadFailure == nil)
    #expect(settingsStore.settings == nil)
}
