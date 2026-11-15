import Foundation
import Testing
import ZentriCore
@testable import ZentriApp

/// A parser builder routing never reaches.
private struct UnusedRoutingParserBuilder: ParserBuilding {
    func makeParser(for mode: ParserMode, rules: [ParsingRuleSpec]) -> any TransactionParsing {
        Issue.record("Opening a URL must not parse anything.")
        return UnusedRoutingParser()
    }
}

private struct UnusedRoutingParser: TransactionParsing {
    func parse(_ input: ParseInput) async -> ParseResult {
        .notTransaction
    }
}

@MainActor
private func makeRoutingAppState() throws -> AppState {
    AppState(
        container: try ZentriContainer.make(inMemory: true),
        settingsStore: SettingsStore(repository: InMemorySettingsRepository()),
        parserBuilder: UnusedRoutingParserBuilder(),
        modelClient: UnavailableModelClient(),
        snapshotStore: FileWidgetSnapshotStore(fileURL: nil),
        timelineReloader: InertTimelineReloader()
    )
}

private func url(_ text: String) throws -> URL {
    try #require(URL(string: text))
}

@Test func eachDeepLinkMapsToItsTab() {
    #expect(AppTab(deepLink: .overview) == .overview)
    #expect(AppTab(deepLink: .transactions) == .transactions)
    #expect(AppTab(deepLink: .insights) == .insights)
}

@MainActor
@Test func openingAWidgetURLSelectsItsTab() throws {
    let appState = try makeRoutingAppState()
    appState.selectedTab = .settings

    appState.open(try url("zentri://transactions"))
    #expect(appState.selectedTab == .transactions)

    appState.open(try url("zentri://insights"))
    #expect(appState.selectedTab == .insights)

    appState.open(try url("zentri://overview"))
    #expect(appState.selectedTab == .overview)
}

@MainActor
@Test func unknownURLsLeaveTheSelectedTabAlone() throws {
    let appState = try makeRoutingAppState()
    appState.selectedTab = .insights

    for text in ["zentri://settings", "zentri://nowhere", "https://example.com/overview", "zentri://overview/extra"] {
        appState.open(try url(text))
        #expect(appState.selectedTab == .insights, "\(text)")
    }
}
