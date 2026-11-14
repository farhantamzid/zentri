import Foundation
import Testing
import ZentriCore
@testable import ZentriApp

/// A file-backed store whose delete action mirrors the one `ZentriApp` installs.
@MainActor
private func makeFileStore(at url: URL) -> SettingsStore {
    SettingsStore(
        repository: FileSettingsStore(fileURL: url),
        deleteStoredSettings: {
            let path = url.path(percentEncoded: false)
            guard FileManager.default.fileExists(atPath: path) else { return }
            try FileManager.default.removeItem(at: url)
        }
    )
}

@MainActor
@Test func settingsLoadReturnsNilWhenNothingIsStored() throws {
    let repository = InMemorySettingsRepository()
    let store = SettingsStore(repository: repository, deleteStoredSettings: { repository.clear() })
    try store.load()
    #expect(store.settings == nil)
    #expect(store.loadFailure == nil)
}

@MainActor
@Test func corruptSettingsFileRecordsTheRecoveryFailure() throws {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "zentri-settings-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    try Data("{not json".utf8).write(to: url)

    let store = makeFileStore(at: url)
    #expect(throws: SettingsError.self) { try store.load() }
    #expect(store.settings == nil)
    #expect(store.loadFailure == .unreadable)
}

@MainActor
@Test func resetDeletesTheSettingsFileAndClearsTheFailure() throws {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "zentri-settings-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    try Data("{not json".utf8).write(to: url)

    let store = makeFileStore(at: url)
    #expect(throws: SettingsError.self) { try store.load() }
    try store.reset()
    #expect(store.settings == nil)
    #expect(store.loadFailure == nil)
    #expect(!FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
}

@MainActor
@Test func completeOnboardingSavesSettingsAndClearsTheFailure() throws {
    let repository = InMemorySettingsRepository()
    let store = SettingsStore(repository: repository, deleteStoredSettings: { repository.clear() })
    var settings = AppSettings.defaultValue
    settings.currencyCode = "BDT"
    settings.numberGrouping = .indian

    try store.completeOnboarding(settings)
    #expect(store.settings == settings)
    #expect(store.loadFailure == nil)

    try store.load()
    #expect(store.settings == settings)
}
