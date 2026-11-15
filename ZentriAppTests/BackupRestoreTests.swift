import Foundation
import SwiftData
import Testing
import ZentriCore
@testable import ZentriApp

/// A parser builder a restore never reaches.
private struct UnusedParserBuilder: ParserBuilding {
    func makeParser(for mode: ParserMode, rules: [ParsingRuleSpec]) -> any TransactionParsing {
        Issue.record("A restore must not parse anything.")
        return NeverParser()
    }
}

private struct NeverParser: TransactionParsing {
    func parse(_ input: ParseInput) async -> ParseResult {
        .notTransaction
    }
}

private enum SettingsWriteFailure: Error {
    case diskFull
}

/// Settings storage whose writes fail on demand, and whose stored document can be unreadable.
private final class ControllableSettingsRepository: SettingsRepository, @unchecked Sendable {
    var stored: AppSettings?
    var failsSaving = false
    var isUnreadable = false

    func load() throws -> AppSettings? {
        if isUnreadable { throw SettingsWriteFailure.diskFull }
        return stored
    }

    func save(_ settings: AppSettings) throws {
        if failsSaving { throw SettingsWriteFailure.diskFull }
        stored = settings
        isUnreadable = false
    }

    func remove() throws {
        stored = nil
    }
}

/// The app's state over a store holding one account, "Everyday", with USD settings.
@MainActor
private struct RestoreAppFixture {
    let appState: AppState
    let repository = ControllableSettingsRepository()
    let snapshotStore: FileWidgetSnapshotStore
    let snapshotURL: URL
    let folder = FakeBackupFolder(hasFolder: true)

    init() throws {
        let container = try ZentriContainer.make(inMemory: true)
        let context = container.mainContext
        let account = Account(name: "Everyday", sortOrder: 0, createdAt: .now)
        context.insert(account)
        context.insert(BalanceCheckpoint(account: account, amount: 10, recordedAt: .now, source: .opening))
        try context.save()
        let lastBackup = Date(timeIntervalSince1970: 1_790_000_000)
        repository.stored = AppSettings(currencyCode: "USD", iCloudBackupEnabled: true, lastBackupAt: lastBackup)
        let settingsStore = SettingsStore(repository: repository)
        try settingsStore.load()
        snapshotURL = FileManager.default.temporaryDirectory
            .appending(path: "zentri-restore-snapshot-\(UUID().uuidString).json")
        snapshotStore = FileWidgetSnapshotStore(fileURL: snapshotURL)
        appState = AppState(
            container: container,
            settingsStore: settingsStore,
            parserBuilder: UnusedParserBuilder(),
            modelClient: UnavailableModelClient(),
            snapshotStore: snapshotStore,
            timelineReloader: InertTimelineReloader(),
            backupFolder: folder
        )
    }

    var accountNames: [String] {
        let accounts = (try? appState.container.mainContext.fetch(FetchDescriptor<Account>())) ?? []
        return accounts.map(\.name).sorted()
    }
}

@MainActor
@Test func replaceSwapsTheDataAppliesTheBackupsSettingsAndTellsEveryScreen() async throws {
    let fixture = try RestoreAppFixture()
    defer { try? FileManager.default.removeItem(at: fixture.snapshotURL) }
    fixture.appState.transactionFilter.searchText = "cafe"
    let deviceLastBackup = fixture.appState.settingsStore.settings?.lastBackupAt

    let summary = try await fixture.appState.restoreBackup(
        makeBackupDocument(transactionCount: 2, accountName: "Restored", currencyCode: "BDT"),
        mode: .replace
    )

    #expect(summary.mode == .replace)
    #expect(fixture.accountNames == ["Restored"])
    #expect(fixture.appState.settingsStore.settings?.currencyCode == "BDT")
    #expect(fixture.appState.settingsStore.settings?.numberGrouping == .indian)
    // When this device last backed up is this device's fact, not the backup's.
    #expect(fixture.appState.settingsStore.settings?.lastBackupAt == deviceLastBackup)
    #expect(fixture.appState.dataRevision == 1)
    #expect(fixture.appState.storeReplacementCount == 1)
    #expect(fixture.appState.transactionFilter == TransactionFilter())
    // The widgets follow the restored data and currency.
    #expect(fixture.snapshotStore.read()?.currencyCode == "BDT")
}

@MainActor
@Test func mergeAddsMissingRowsAndKeepsTheSettings() async throws {
    let fixture = try RestoreAppFixture()
    defer { try? FileManager.default.removeItem(at: fixture.snapshotURL) }

    let summary = try await fixture.appState.restoreBackup(
        makeBackupDocument(accountName: "Restored", currencyCode: "BDT"),
        mode: .merge
    )

    #expect(summary.mode == .merge)
    #expect(fixture.accountNames == ["Everyday", "Restored"])
    #expect(fixture.appState.settingsStore.settings?.currencyCode == "USD")
    #expect(fixture.appState.dataRevision == 1)
    #expect(fixture.appState.storeReplacementCount == 0)
}

@MainActor
@Test func anInvalidBackupChangesNothing() async throws {
    let fixture = try RestoreAppFixture()
    defer { try? FileManager.default.removeItem(at: fixture.snapshotURL) }
    var broken = makeBackupDocument(currencyCode: "BDT")
    broken.transactions[0].accountID = UUID()

    await #expect(throws: BackupError.self) {
        try await fixture.appState.restoreBackup(broken, mode: .replace)
    }

    #expect(fixture.accountNames == ["Everyday"])
    #expect(fixture.appState.settingsStore.settings?.currencyCode == "USD")
    #expect(fixture.appState.dataRevision == 0)
}

@MainActor
@Test func aBackupWithUnreadableSettingsIsRejectedBeforeTheDataChanges() async throws {
    let fixture = try RestoreAppFixture()
    defer { try? FileManager.default.removeItem(at: fixture.snapshotURL) }
    var broken = makeBackupDocument(currencyCode: "BDT")
    broken.settings.lastBackupAt = "yesterday"

    await #expect(throws: BackupError.self) {
        try await fixture.appState.restoreBackup(broken, mode: .replace)
    }

    #expect(fixture.accountNames == ["Everyday"])
    #expect(fixture.appState.settingsStore.settings?.currencyCode == "USD")
}

@MainActor
@Test func settingsThatCannotBeSavedAfterAReplaceAreReportedNotHidden() async throws {
    let fixture = try RestoreAppFixture()
    defer { try? FileManager.default.removeItem(at: fixture.snapshotURL) }
    fixture.repository.failsSaving = true

    await #expect(throws: BackupRestoreError.settingsNotSaved) {
        try await fixture.appState.restoreBackup(
            makeBackupDocument(accountName: "Restored", currencyCode: "BDT"),
            mode: .replace
        )
    }

    // The data is restored and every screen told; the settings are the old ones, and the error says so.
    #expect(fixture.accountNames == ["Restored"])
    #expect(fixture.appState.settingsStore.settings?.currencyCode == "USD")
    #expect(fixture.appState.dataRevision == 1)

    // Restoring again once the settings can be written finishes the job.
    fixture.repository.failsSaving = false
    _ = try await fixture.appState.restoreBackup(
        makeBackupDocument(accountName: "Restored", currencyCode: "BDT"),
        mode: .replace
    )
    #expect(fixture.appState.settingsStore.settings?.currencyCode == "BDT")
}

@MainActor
@Test func replaceRecoversFromSettingsThatCouldNotBeRead() async throws {
    let fixture = try RestoreAppFixture()
    defer { try? FileManager.default.removeItem(at: fixture.snapshotURL) }
    fixture.repository.isUnreadable = true
    #expect(throws: (any Error).self) { try fixture.appState.settingsStore.load() }
    #expect(fixture.appState.settingsStore.loadFailure == .unreadable)

    _ = try await fixture.appState.restoreBackup(
        makeBackupDocument(accountName: "Restored", currencyCode: "BDT"),
        mode: .replace
    )

    #expect(fixture.appState.settingsStore.loadFailure == nil)
    #expect(fixture.appState.settingsStore.settings?.currencyCode == "BDT")
    #expect(fixture.accountNames == ["Restored"])
}

@MainActor
@Test func eraseAllDataForgetsTheBackupFolder() throws {
    let fixture = try RestoreAppFixture()
    defer { try? FileManager.default.removeItem(at: fixture.snapshotURL) }
    #expect(fixture.folder.hasFolder)

    try fixture.appState.eraseAllData()

    #expect(fixture.folder.hasFolder == false)
}

@MainActor
@Test func dataChangesScheduleAnAutomaticBackupThroughTheAppsScheduler() async throws {
    let fixture = try RestoreAppFixture()
    defer { try? FileManager.default.removeItem(at: fixture.snapshotURL) }

    fixture.appState.backupScheduler.schedule()
    await fixture.appState.backupScheduler.flush()

    #expect(fixture.folder.writeCount == 1)
    let written = try #require(fixture.folder.snapshotData.last)
    #expect(try BackupCodec.decode(written).accounts.map(\.name) == ["Everyday"])
    // A successful backup is recorded in the settings for the status line.
    #expect(fixture.appState.settingsStore.settings?.lastBackupAt != Date(timeIntervalSince1970: 1_790_000_000))
    #expect(fixture.appState.settingsStore.settings?.currencyCode == "USD")
}
