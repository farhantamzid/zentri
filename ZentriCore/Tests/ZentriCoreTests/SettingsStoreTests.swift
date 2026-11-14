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
