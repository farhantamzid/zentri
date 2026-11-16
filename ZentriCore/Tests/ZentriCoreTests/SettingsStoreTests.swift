import Foundation
import Testing
@testable import ZentriCore

@Test func settingsRoundTripAndMissingFile() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "settings-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = FileSettingsStore(fileURL: url)
    #expect(try store.load() == nil)
    var settings = AppSettings.defaultValue
    settings.currencyCode = "BDT"
    settings.numberGrouping = .indian
    try store.save(settings)
    #expect(try store.load() == settings)
}

@Test func corruptSettingsThrow() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "settings-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: url) }
    try Data("{not json".utf8).write(to: url)
    let store = FileSettingsStore(fileURL: url)
    #expect(throws: SettingsError.self) { try store.load() }
}

@Test func defaultSettingsMatchSpecification() {
    let settings = AppSettings.defaultValue
    #expect(settings.currencyCode == "USD")
    #expect(settings.numberGrouping == .western)
    #expect(settings.appearanceMode == .system)
    #expect(settings.parserMode == .hybrid)
    #expect(settings.faceIDEnabled == false)
    #expect(settings.iCloudBackupEnabled == false)
    #expect(settings.lastBackupAt == nil)
    #expect(settings.schemaVersion == 1)
}

@Test func saveCreatesMissingParentDirectory() throws {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: "zentri-settings-\(UUID())")
        .appending(path: "nested")
    defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
    let store = FileSettingsStore(fileURL: directory.appending(path: AppGroup.settingsFileName))
    var settings = AppSettings.defaultValue
    settings.parserMode = .rules
    settings.lastBackupAt = Date(timeIntervalSinceReferenceDate: 800_000_000)
    try store.save(settings)
    #expect(try store.load() == settings)
}

// MARK: - Forward compatibility (I9)

/// A document written by another version — missing a field this one has, carrying one it does not
/// know, or naming an option it cannot read — still loads, with defaults for what it cannot use.
@Test func settingsWithMissingOrUnknownFieldsStillLoad() throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "settings-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let json = """
    {
      "currencyCode": "BDT",
      "numberGrouping": "indian",
      "parserMode": "someFutureMode",
      "aFieldFromANewerVersion": { "nested": true },
      "schemaVersion": 2
    }
    """
    try Data(json.utf8).write(to: url)

    let loaded = try #require(try FileSettingsStore(fileURL: url).load())

    #expect(loaded.currencyCode == "BDT")
    #expect(loaded.numberGrouping == .indian)
    #expect(loaded.parserMode == AppSettings.defaultValue.parserMode)
    #expect(loaded.faceIDEnabled == false)
    #expect(loaded.iCloudBackupEnabled == false)
    #expect(loaded.lastBackupAt == nil)
    #expect(loaded.schemaVersion == 2)
}

@Test func anEmptySettingsObjectLoadsAsTheDefaults() throws {
    let decoded = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
    #expect(decoded == .defaultValue)
}

/// The written document keeps the same keys, so older builds still read it.
@Test func settingsEncodeEveryFieldUnderItsName() throws {
    var settings = AppSettings.defaultValue
    settings.lastBackupAt = Date(timeIntervalSince1970: 1_795_000_000)
    let object = try #require(
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any]
    )
    #expect(Set(object.keys) == [
        "currencyCode", "numberGrouping", "appearanceMode", "parserMode", "faceIDEnabled",
        "iCloudBackupEnabled", "lastBackupAt", "schemaVersion",
    ])
}

// MARK: - Appearance mode

/// A settings file written before the appearance mode existed follows the device.
@Test func settingsWithoutAnAppearanceModeFollowTheDevice() throws {
    let json = """
    {
      "currencyCode": "BDT",
      "numberGrouping": "indian",
      "parserMode": "rules",
      "faceIDEnabled": true,
      "iCloudBackupEnabled": false,
      "schemaVersion": 1
    }
    """
    let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
    #expect(decoded.appearanceMode == .system)
    #expect(decoded.currencyCode == "BDT")
    #expect(decoded.faceIDEnabled == true)
}

@Test func anUnknownAppearanceModeFollowsTheDevice() throws {
    let json = #"{ "currencyCode": "EUR", "appearanceMode": "sepia" }"#
    let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
    #expect(decoded.appearanceMode == .system)
    #expect(decoded.currencyCode == "EUR")
}

@Test(arguments: AppearanceMode.allCases)
func appearanceModeRoundTrips(_ mode: AppearanceMode) throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "settings-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = FileSettingsStore(fileURL: url)
    var settings = AppSettings.defaultValue
    settings.appearanceMode = mode
    try store.save(settings)
    #expect(try store.load()?.appearanceMode == mode)
}
