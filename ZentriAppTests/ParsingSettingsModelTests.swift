import Foundation
import Testing
import ZentriCore
@testable import ZentriApp

private enum SaveFailure: Error {
    case refused
}

@MainActor
@Test func parsingSettingsCountsRulesAndFailures() async throws {
    let store = try ParsingTestStore()
    try store.addRule("Card debit")
    try store.addMessage(status: .failed)
    try store.addMessage(status: .parsed)
    let settingsStore = SettingsStore(repository: InMemorySettingsRepository())
    let model = ParsingSettingsModel(
        context: store.context,
        settingsStore: settingsStore,
        modelClient: UnavailableModelClient(),
        apply: { _ in }
    )

    model.refresh()
    await model.checkAvailability()

    #expect(model.loadState == .loaded)
    #expect(model.ruleCount == 1)
    #expect(model.failedMessageCount == 1)
    if case .unavailable = model.availability {} else {
        Issue.record("The stub model was reported available: \(String(describing: model.availability))")
    }
}

@MainActor
@Test func parsingSettingsReportsAFailedRead() throws {
    let model = ParsingSettingsModel(
        settingsStore: SettingsStore(repository: InMemorySettingsRepository()),
        modelClient: UnavailableModelClient(),
        fetchRuleCount: { throw ParsingReadFailure.unreadable },
        fetchMessages: { [] },
        apply: { _ in }
    )

    model.refresh()

    #expect(model.loadState == .failed)
}

@MainActor
@Test func choosingAnEngineSavesIt() async throws {
    let settingsStore = SettingsStore(repository: InMemorySettingsRepository())
    try settingsStore.save(.defaultValue)
    let model = ParsingSettingsModel(
        settingsStore: settingsStore,
        modelClient: UnavailableModelClient(),
        fetchRuleCount: { 0 },
        fetchMessages: { [] },
        apply: { try settingsStore.save($0) }
    )

    await model.setParserMode(.rules)

    #expect(settingsStore.settings?.parserMode == .rules)
    #expect(model.parserMode == .rules)
    #expect(model.savedCount == 1)
    #expect(model.failureMessage == nil)
}

@MainActor
@Test func aRefusedEngineChangeIsReported() async throws {
    let settingsStore = SettingsStore(repository: InMemorySettingsRepository())
    try settingsStore.save(.defaultValue)
    let model = ParsingSettingsModel(
        settingsStore: settingsStore,
        modelClient: UnavailableModelClient(),
        fetchRuleCount: { 0 },
        fetchMessages: { [] },
        apply: { _ in throw SaveFailure.refused }
    )

    await model.setParserMode(.rules)

    #expect(settingsStore.settings?.parserMode == AppSettings.defaultValue.parserMode)
    #expect(model.failureMessage != nil)
    #expect(model.savedCount == 0)
}
