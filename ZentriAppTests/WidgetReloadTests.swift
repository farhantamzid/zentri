import Foundation
import SwiftData
import Testing
import ZentriCore
@testable import ZentriApp

/// Counts the timeline reloads the app asks WidgetKit for.
@MainActor
final class RecordingTimelineReloader: WidgetTimelineReloading {
    private(set) var reloadCount = 0

    func reloadAllTimelines() {
        reloadCount += 1
    }
}

/// A parser that reads every message as a 12.50 debit at KFC.
private struct KFCParserBuilder: ParserBuilding {
    func makeParser(for mode: ParserMode, rules: [ParsingRuleSpec]) -> any TransactionParsing {
        KFCParser()
    }
}

private struct KFCParser: TransactionParsing {
    func parse(_ input: ParseInput) async -> ParseResult {
        .transaction(TransactionDraft(direction: .debit, amount: Decimal(string: "12.50") ?? 0, merchant: "KFC"))
    }
}

/// The app's state over the parsing test store (one account holding 1,000) and a temporary snapshot
/// file, with onboarding finished.
@MainActor
private struct ReloadFixture {
    let appState: AppState
    let reloader = RecordingTimelineReloader()
    let snapshotStore: FileWidgetSnapshotStore
    let snapshotURL: URL

    init() throws {
        let container = try ParsingTestStore().container
        let settingsStore = SettingsStore(repository: InMemorySettingsRepository())
        try settingsStore.save(AppSettings(parserMode: .rules))
        snapshotURL = FileManager.default.temporaryDirectory
            .appending(path: "zentri-reload-snapshot-\(UUID().uuidString).json")
        snapshotStore = FileWidgetSnapshotStore(fileURL: snapshotURL)
        appState = AppState(
            container: container,
            settingsStore: settingsStore,
            parserBuilder: KFCParserBuilder(),
            modelClient: UnavailableModelClient(),
            snapshotStore: snapshotStore,
            timelineReloader: reloader
        )
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: snapshotURL)
    }
}

/// Every snapshot write and the snapshot's removal reload the widgets through one refresher, so no
/// widget keeps drawing a document the app has replaced or erased.
@MainActor
@Suite
struct WidgetReloadTests {
    @Test func aSnapshotRefreshWritesThenReloadsTheWidgets() async throws {
        let fixture = try ReloadFixture()
        defer { fixture.cleanUp() }

        await fixture.appState.snapshotRefresher.refresh()

        #expect(fixture.snapshotStore.read() != nil)
        #expect(fixture.reloader.reloadCount == 1)
    }

    @Test func aSettingsChangeReloadsTheWidgets() async throws {
        let fixture = try ReloadFixture()
        defer { fixture.cleanUp() }
        var settings = AppSettings(parserMode: .rules)
        settings.currencyCode = "BDT"

        try await fixture.appState.updateSettings(settings)

        #expect(fixture.snapshotStore.read()?.currencyCode == "BDT")
        #expect(fixture.reloader.reloadCount == 1)
    }

    @Test func aMutationServiceReloadsTheWidgetsAfterItsWrite() async throws {
        let fixture = try ReloadFixture()
        defer { fixture.cleanUp() }

        _ = try await fixture.appState.makeAccountMutationService()
            .create(name: "Savings", institutionName: nil, openingBalance: 10)

        #expect(fixture.reloader.reloadCount == 1)
        #expect(fixture.snapshotStore.read()?.balance == "1010")
    }

    @Test func aCaptureReloadsTheWidgets() async throws {
        let fixture = try ReloadFixture()
        defer { fixture.cleanUp() }
        let outcome = await fixture.appState.capture(
            IngestionRequest(text: "MYBANK: USD12.50 spent at KFC.", sender: "MYBANK", receivedAt: .now)
        )

        guard case .transaction = outcome else {
            Issue.record("Expected a transaction, got \(outcome)")
            return
        }
        #expect(fixture.reloader.reloadCount >= 1)
        #expect(fixture.snapshotStore.read()?.balance == "987.5")
    }

    @Test func eraseAllDataRemovesTheSnapshotAndReloadsTheWidgets() async throws {
        let fixture = try ReloadFixture()
        defer { fixture.cleanUp() }
        await fixture.appState.snapshotRefresher.refresh()
        let before = fixture.reloader.reloadCount

        try fixture.appState.eraseAllData()

        // No snapshot is what makes every widget draw its "Open Zentri" placeholder.
        #expect(fixture.snapshotStore.read() == nil)
        #expect(WidgetDisplayModel.load(from: fixture.snapshotStore, hideAmounts: false) == nil)
        #expect(fixture.reloader.reloadCount == before + 1)
    }

    @Test func uiTestModeNeverTouchesWidgetKit() {
        #expect(AppComposition.makeTimelineReloader(isUITestMode: true) is InertTimelineReloader)
        #expect(AppComposition.makeTimelineReloader(isUITestMode: false) is WidgetCenterTimelineReloader)
    }
}
