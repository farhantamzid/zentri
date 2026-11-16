import Foundation
import SwiftUI
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
    let model = AppearanceSettingsModel(settingsStore: store, biometric: StubBiometrics()) { settings in
        applied.append(settings)
        try store.save(settings)
    }

    model.currencyCode = "USD"
    #expect(model.pendingCurrencyCode == nil)

    model.currencyCode = "INR"
    #expect(model.pendingCurrencyCode == "INR")
    #expect(model.currencyCode == "USD")
    #expect(applied.isEmpty)

    // The dialog has already cleared its item by the time the confirm button's action runs.
    model.pendingCurrencyCode = nil
    await model.confirmCurrencyChange(to: "INR")
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
    let model = AppearanceSettingsModel(settingsStore: store, biometric: StubBiometrics()) { _ in
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
    let model = AppearanceSettingsModel(settingsStore: store, biometric: StubBiometrics()) { try store.save($0) }

    await model.setGrouping(.indian)

    #expect(store.settings?.numberGrouping == .indian)
    #expect(model.numberGrouping == .indian)
    #expect(model.savedCount == 1)
}

@MainActor
@Test func aFailedSaveKeepsTheOldSettingsAndReportsIt() async throws {
    let store = try makeStore()
    let model = AppearanceSettingsModel(settingsStore: store, biometric: StubBiometrics()) { _ in throw SaveFailure.unwritable }

    await model.setGrouping(.indian)

    #expect(store.settings?.numberGrouping == .western)
    #expect(model.failureMessage != nil)
    #expect(model.savedCount == 0)
}

@MainActor
@Test func turningFaceIDOnNeedsAPassingCheckFirst() async throws {
    let store = try makeStore()
    let biometric = StubBiometrics(results: [true])
    let model = AppearanceSettingsModel(settingsStore: store, biometric: biometric) { try store.save($0) }

    await model.setFaceIDEnabled(true)

    #expect(biometric.authenticateCount == 1)
    #expect(store.settings?.faceIDEnabled == true)
    #expect(model.faceIDEnabled)
    #expect(model.faceIDMessage == nil)
    #expect(model.savedCount == 1)
}

@MainActor
@Test func aFailedCheckLeavesFaceIDOffAndSaysWhy() async throws {
    let store = try makeStore()
    let biometric = StubBiometrics(results: [false])
    let model = AppearanceSettingsModel(settingsStore: store, biometric: biometric) { _ in
        Issue.record("A failed check must not save.")
    }

    await model.setFaceIDEnabled(true)

    #expect(store.settings?.faceIDEnabled == false)
    #expect(model.faceIDMessage != nil)
    #expect(model.savedCount == 0)
}

@MainActor
@Test func aDeviceThatCannotCheckItsOwnerCannotTurnFaceIDOn() async throws {
    let store = try makeStore()
    let biometric = StubBiometrics(isAvailable: false)
    let model = AppearanceSettingsModel(settingsStore: store, biometric: biometric) { _ in
        Issue.record("A device without Face ID or a passcode must not save the lock on.")
    }

    await model.setFaceIDEnabled(true)

    #expect(biometric.authenticateCount == 0)
    #expect(store.settings?.faceIDEnabled == false)
    #expect(model.faceIDMessage != nil)
}

@MainActor
@Test func turningFaceIDOffSavesWithoutACheck() async throws {
    let store = try makeStore()
    var settings = try #require(store.settings)
    settings.faceIDEnabled = true
    try store.save(settings)
    let biometric = StubBiometrics()
    let model = AppearanceSettingsModel(settingsStore: store, biometric: biometric) { try store.save($0) }

    await model.setFaceIDEnabled(false)

    #expect(biometric.authenticateCount == 0)
    #expect(store.settings?.faceIDEnabled == false)
    // Nothing else changes.
    #expect(store.settings?.currencyCode == settings.currencyCode)
}

@MainActor
@Test func appearanceModeSavesStraightAwayAndKeepsEverythingElse() async throws {
    let store = try makeStore()
    var applied: [AppSettings] = []
    let model = AppearanceSettingsModel(settingsStore: store, biometric: StubBiometrics()) { settings in
        applied.append(settings)
        try store.save(settings)
    }
    #expect(model.appearanceMode == .system)

    await model.setAppearanceMode(.dark)

    #expect(store.settings?.appearanceMode == .dark)
    #expect(model.appearanceMode == .dark)
    #expect(model.savedCount == 1)
    var expected = AppSettings.defaultValue
    expected.appearanceMode = .dark
    #expect(applied == [expected])

    await model.setAppearanceMode(.system)
    #expect(store.settings == .defaultValue)
}

@MainActor
@Test func pickingTheSavedAppearanceModeDoesNotSave() throws {
    let store = try makeStore()
    let model = AppearanceSettingsModel(settingsStore: store, biometric: StubBiometrics()) { _ in
        Issue.record("Picking the saved mode must not save.")
    }

    model.appearanceMode = .system

    #expect(model.savedCount == 0)
}

@MainActor
@Test func aFailedAppearanceSaveKeepsTheOldModeAndReportsIt() async throws {
    let store = try makeStore()
    let model = AppearanceSettingsModel(settingsStore: store, biometric: StubBiometrics()) { _ in throw SaveFailure.unwritable }

    await model.setAppearanceMode(.light)

    #expect(store.settings?.appearanceMode == .system)
    #expect(model.appearanceMode == .system)
    #expect(model.failureMessage != nil)
}

@Test func appearanceModesMapToColorSchemes() {
    #expect(AppearanceMode.system.colorScheme == nil)
    #expect(AppearanceMode.light.colorScheme == .light)
    #expect(AppearanceMode.dark.colorScheme == .dark)
}
