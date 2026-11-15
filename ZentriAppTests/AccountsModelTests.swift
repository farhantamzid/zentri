import Foundation
import SwiftData
import Testing
import ZentriCore
@testable import ZentriApp

/// A refresher that does nothing; these tests are about the model, not the widgets.
private struct InertRefresher: WidgetSnapshotRefresher {
    func refresh() async {}
}

private enum ReadFailure: Error {
    case unreadable
}

/// Counts how often the model told the app the store changed.
@MainActor
private final class MutationCounter {
    var count = 0
    func record() { count += 1 }
}

@MainActor
private struct Fixture {
    let container: ModelContainer
    let model: AccountsModel
    let counter: MutationCounter
    var context: ModelContext { container.mainContext }
}

/// A store with one active account at 1,000 and one archived account at 50.
@MainActor
private func makeFixture() throws -> Fixture {
    let container = try ZentriContainer.make(inMemory: true)
    let context = container.mainContext
    let openedAt = Date.now.addingTimeInterval(-3_600)
    let everyday = Account(name: "Everyday", institutionName: "City Bank", sortOrder: 0, createdAt: openedAt)
    let old = Account(name: "Old", sortOrder: 1, createdAt: openedAt, archivedAt: openedAt)
    context.insert(everyday)
    context.insert(old)
    context.insert(BalanceCheckpoint(account: everyday, amount: 1_000, recordedAt: openedAt, source: .opening))
    context.insert(BalanceCheckpoint(account: old, amount: 50, recordedAt: openedAt, source: .opening))
    try context.save()
    let counter = MutationCounter()
    let model = AccountsModel(
        context: context,
        service: AccountMutationService(context: context, snapshotRefresher: InertRefresher()),
        onMutation: counter.record
    )
    return Fixture(container: container, model: model, counter: counter)
}

@MainActor
@Test func accountsModelSplitsActiveAndArchivedWithBalances() throws {
    let fixture = try makeFixture()
    #expect(fixture.model.loadState == .loading)

    fixture.model.refresh()

    #expect(fixture.model.loadState == .loaded)
    #expect(fixture.model.activeAccounts.map(\.name) == ["Everyday"])
    #expect(fixture.model.activeAccounts.first?.balance == 1_000)
    #expect(fixture.model.activeAccounts.first?.institutionName == "City Bank")
    #expect(fixture.model.archivedAccounts.map(\.name) == ["Old"])
    #expect(fixture.model.archivedAccounts.first?.isArchived == true)
    #expect(fixture.model.hasAccounts)
}

@MainActor
@Test func accountsModelReportsAFailedReadInsteadOfAnEmptyList() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let model = AccountsModel(
        fetchAccounts: { throw ReadFailure.unreadable },
        service: AccountMutationService(context: container.mainContext, snapshotRefresher: InertRefresher()),
        onMutation: {}
    )

    model.refresh()

    #expect(model.loadState == .failed)
    #expect(!model.hasAccounts)
}

@MainActor
@Test func accountsModelCreatesSetsBalanceAndArchivesThenTellsTheApp() async throws {
    let fixture = try makeFixture()
    fixture.model.refresh()

    try await fixture.model.create(name: "Savings", institutionName: "", openingBalance: 2_500)
    let savings = try #require(fixture.model.activeAccounts.first { $0.name == "Savings" })
    #expect(savings.balance == 2_500)
    #expect(fixture.counter.count == 1)

    try await fixture.model.setBalance(id: savings.id, amount: 3_000, at: .now)
    #expect(fixture.model.account(id: savings.id)?.balance == 3_000)
    #expect(fixture.counter.count == 2)

    try await fixture.model.rename(id: savings.id, name: "Rainy Day", institutionName: "Metro")
    #expect(fixture.model.account(id: savings.id)?.name == "Rainy Day")

    try await fixture.model.setArchived(true, id: savings.id)
    #expect(fixture.model.archivedAccounts.contains { $0.id == savings.id })
    try await fixture.model.setArchived(false, id: savings.id)
    #expect(fixture.model.activeAccounts.contains { $0.id == savings.id })
    #expect(fixture.counter.count == 5)
}

@MainActor
@Test func accountsModelRethrowsARefusalWithoutTellingTheApp() async throws {
    let fixture = try makeFixture()
    fixture.model.refresh()

    await #expect(throws: AccountMutationError.missingName) {
        try await fixture.model.create(name: " ", institutionName: "", openingBalance: 1)
    }
    #expect(fixture.counter.count == 0)
    #expect(fixture.model.activeAccounts.count == 1)
}

@MainActor
@Test func accountEditorNeedsANameAndANonNegativeOpeningBalanceOnlyWhenCreating() {
    let creating = AccountEditorModel(account: nil, locale: Locale(identifier: "en_US"))
    #expect(creating.isCreating)
    #expect(!creating.canSave)
    creating.name = "Savings"
    #expect(!creating.canSave)
    creating.openingBalanceText = "1,234.50"
    #expect(creating.openingBalance == Decimal(string: "1234.50"))
    #expect(creating.canSave)
    creating.openingBalanceText = "-3"
    #expect(!creating.canSave)

    let existing = AccountListItem(
        id: UUID(), name: "Everyday", institutionName: "City", balance: 0, asOf: nil, isArchived: false
    )
    let editing = AccountEditorModel(account: existing)
    #expect(!editing.isCreating)
    #expect(editing.name == "Everyday")
    #expect(editing.institutionName == "City")
    #expect(editing.canSave)
    editing.name = "  "
    #expect(!editing.canSave)
}

@MainActor
@Test func accountEditorReadsTheLocaleSeparators() {
    let model = AccountEditorModel(account: nil, locale: Locale(identifier: "de_DE"))
    model.openingBalanceText = "1.000,50"
    #expect(model.openingBalance == Decimal(string: "1000.50"))
}

@MainActor
@Test func setBalanceOffersDatesFromTheLatestCheckpointToNow() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let latest = now.addingTimeInterval(-600)
    let model = SetBalanceModel(latestCheckpoint: latest, now: now, locale: Locale(identifier: "en_US"))
    #expect(model.dateRange == latest...now)
    #expect(model.date == now)
    #expect(!model.canSave)

    model.amountText = "3000"
    #expect(model.amount == 3_000)
    #expect(model.canSave)

    model.amountText = "-1"
    #expect(!model.canSave)

    model.amountText = "5"
    model.date = latest.addingTimeInterval(-1)
    #expect(!model.canSave)
}
