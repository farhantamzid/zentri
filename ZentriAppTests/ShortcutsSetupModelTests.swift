import Foundation
import SwiftData
import Testing
import ZentriCore
@testable import ZentriApp

@MainActor
@Suite
struct ShortcutsSetupModelTests {
    @Test func setupGuideHealthReadsTheArchiveLikeTheOverviewCard() throws {
        let store = try ParsingTestStore()
        let now = Date.now
        try store.addMessage("Old failure", status: .failed, receivedAt: now.addingTimeInterval(-600))
        try store.addMessage("Read", status: .parsed, receivedAt: now.addingTimeInterval(-300))
        let newest = try store.addMessage("Newest failure", status: .failed, receivedAt: now.addingTimeInterval(-60))
        let model = ShortcutsSetupModel(context: store.context)

        model.refresh()

        #expect(model.loadState == .loaded)
        #expect(model.health?.lastMessageAt == newest.receivedAt)
        #expect(model.health?.failureCount == 2)
        #expect(model.health?.lastSuccessAt != nil)
    }

    @Test func setupGuideHealthReportsNothingYetForAnEmptyArchive() throws {
        let store = try ParsingTestStore()
        let model = ShortcutsSetupModel(context: store.context)

        model.refresh()

        #expect(model.loadState == .loaded)
        #expect(model.health == IngestionHealth(lastMessageAt: nil, lastSuccessAt: nil, failureCount: 0))
    }

    /// A read that throws is not an archive where nothing failed.
    @Test func setupGuideHealthFailedReadIsNotAHealthyArchive() {
        let model = ShortcutsSetupModel(fetchMessages: { throw ParsingReadFailure.unreadable })

        model.refresh()

        #expect(model.loadState == .failed)
        #expect(model.health == nil)
    }
}
