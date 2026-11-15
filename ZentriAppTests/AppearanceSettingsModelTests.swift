import Foundation
import Testing
import ZentriCore
@testable import ZentriApp

private enum SaveFailure: Error {
    case unwritable
}

@MainActor
private func makeStore() throws -> SettingsStore {
    let store = SettingsStore(repository: InMemorySettingsRepository())
    try store.save(.defaultValue)
    return store
}

@MainActor
@Test func pickingACurrencyStagesItUntilConfirmed() async throws {
    let store = try makeStore()
    var applied: [AppSettings] = []
    let model = AppearanceSettingsModel(settingsStore: store) { settings in
        applied.append(settings)
        try store.save(settings)
    }

    model.currencyCode = "USD"
    #expect(model.pendingCurrencyCode == nil)

    model.currencyCode = "INR"
    #expect(model.pendingCurrencyCode == "INR")
    #expect(model.currencyCode == "USD")
    #expect(applied.isEmpty)

    await model.confirmCurrencyChange()
    #expect(model.pendingCurrencyCode == nil)
    #expect(store.settings?.currencyCode == "INR")
    // Only the currency changes; the grouping and every other setting stay as they were.
    #expect(store.settings?.numberGrouping == AppSettings.defaultValue.numberGrouping)
    #expect(applied.count == 1)
    #expect(model.savedCount == 1)
}

@MainActor
@Test func cancellingACurrencyChangeKeepsTheSavedOne() throws {
    let store = try makeStore()
    let model = AppearanceSettingsModel(settingsStore: store) { _ in
        Issue.record("A cancelled change must not save.")
    }

    model.currencyCode = "EUR"
    model.cancelCurrencyChange()

    #expect(model.pendingCurrencyCode == nil)
    #expect(store.settings?.currencyCode == "USD")
}

@MainActor
@Test func groupingSavesStraightAway() async throws {
    let store = try makeStore()
    let model = AppearanceSettingsModel(settingsStore: store) { try store.save($0) }

    await model.setGrouping(.indian)

    #expect(store.settings?.numberGrouping == .indian)
    #expect(model.numberGrouping == .indian)
    #expect(model.savedCount == 1)
}

@MainActor
@Test func aFailedSaveKeepsTheOldSettingsAndReportsIt() async throws {
    let store = try makeStore()
    let model = AppearanceSettingsModel(settingsStore: store) { _ in throw SaveFailure.unwritable }

    await model.setGrouping(.indian)

    #expect(store.settings?.numberGrouping == .western)
    #expect(model.failureMessage != nil)
    #expect(model.savedCount == 0)
}
