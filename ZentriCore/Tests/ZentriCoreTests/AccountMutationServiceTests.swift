import Foundation
import SwiftData
import Testing
@testable import ZentriCore

/// Counts snapshot refreshes so a test can prove a mutation refreshed the widgets.
private actor CountingSnapshotRefresher: WidgetSnapshotRefresher {
    private(set) var refreshCount = 0

    func refresh() async {
        refreshCount += 1
    }
}

/// The instant the tests treat as now.
private let now = Date(timeIntervalSince1970: 1_800_000_000)

/// Holds the container for as long as a test uses its context.
@MainActor
private struct Store {
    let container: ModelContainer
    let account: Account
    var context: ModelContext { container.mainContext }
}

/// A store with one account that opened at 1,000 an hour before now.
@MainActor
private func makeStore() throws -> Store {
    let container = try ZentriContainer.make(inMemory: true)
    let context = container.mainContext
    let openedAt = now.addingTimeInterval(-3_600)
    let account = Account(name: "Everyday", sortOrder: 3, createdAt: openedAt)
    context.insert(account)
    context.insert(BalanceCheckpoint(account: account, amount: 1_000, recordedAt: openedAt, source: .opening, createdAt: openedAt))
    try context.save()
    return Store(container: container, account: account)
}

@MainActor
private func makeService(_ store: Store, refresher: any WidgetSnapshotRefresher) -> AccountMutationService {
    AccountMutationService(context: store.context, snapshotRefresher: refresher, now: { now })
}

@MainActor
@Suite("AccountMutationService")
struct AccountMutationServiceTests {
    @Test("Creating an account stores it with an opening checkpoint and refreshes the snapshot")
    func createWithOpeningCheckpoint() async throws {
        let store = try makeStore()
        let refresher = CountingSnapshotRefresher()
        let service = makeService(store, refresher: refresher)

        let account = try await service.create(name: "  Savings ", institutionName: "  ", openingBalance: 2_500)

        #expect(account.name == "Savings")
        #expect(account.institutionName == nil)
        #expect(account.sortOrder == 4)
        #expect(account.createdAt == now)
        #expect(account.archivedAt == nil)
        let checkpoints = account.checkpoints
        #expect(checkpoints.count == 1)
        #expect(checkpoints.first?.source == .opening)
        #expect(checkpoints.first?.amount == 2_500)
        #expect(checkpoints.first?.recordedAt == now)
        #expect(BalanceCalculator.combined(accounts: [account]) == 2_500)
        #expect(try store.context.fetch(FetchDescriptor<Account>()).count == 2)
        #expect(await refresher.refreshCount == 1)
    }

    @Test("Creating keeps a named institution, trimmed")
    func createKeepsInstitution() async throws {
        let store = try makeStore()
        let service = makeService(store, refresher: CountingSnapshotRefresher())

        let account = try await service.create(name: "Savings", institutionName: " City Bank ", openingBalance: 0)

        #expect(account.institutionName == "City Bank")
    }

    @Test("A blank name or a negative opening balance is refused before anything is written")
    func createValidates() async throws {
        let store = try makeStore()
        let refresher = CountingSnapshotRefresher()
        let service = makeService(store, refresher: refresher)

        await #expect(throws: AccountMutationError.missingName) {
            _ = try await service.create(name: "   ", institutionName: nil, openingBalance: 10)
        }
        await #expect(throws: AccountMutationError.negativeBalance) {
            _ = try await service.create(name: "Savings", institutionName: nil, openingBalance: -1)
        }
        #expect(try store.context.fetch(FetchDescriptor<Account>()).count == 1)
        #expect(try store.context.fetch(FetchDescriptor<BalanceCheckpoint>()).count == 1)
        #expect(await refresher.refreshCount == 0)
    }

    @Test("Set balance creates a manual checkpoint at the supplied date")
    func setBalanceCreatesManualCheckpoint() async throws {
        let store = try makeStore()
        let refresher = CountingSnapshotRefresher()
        let service = makeService(store, refresher: refresher)
        let balanceDate = now.addingTimeInterval(-600)
        // Spend recorded after the new checkpoint still counts against it.
        store.context.insert(
            Transaction(
                account: store.account,
                amount: 40,
                direction: .debit,
                occurredAt: now.addingTimeInterval(-60),
                recordedAt: now.addingTimeInterval(-60),
                merchantRaw: "Cafe",
                merchantDisplay: "Cafe"
            )
        )
        try store.context.save()

        let checkpoint = try await service.setBalance(account: store.account, amount: 750, at: balanceDate)

        #expect(checkpoint.source == .manual)
        #expect(checkpoint.amount == 750)
        #expect(checkpoint.recordedAt == balanceDate)
        #expect(checkpoint.createdAt == now)
        #expect(checkpoint.account.id == store.account.id)
        #expect(store.account.checkpoints.count == 2)
        #expect(BalanceCalculator.combined(accounts: [store.account]) == 710)
        #expect(await refresher.refreshCount == 1)
    }

    @Test("Set balance refuses a negative amount, a future date, and a date before the latest checkpoint")
    func setBalanceValidates() async throws {
        let store = try makeStore()
        let refresher = CountingSnapshotRefresher()
        let service = makeService(store, refresher: refresher)

        await #expect(throws: AccountMutationError.negativeBalance) {
            _ = try await service.setBalance(account: store.account, amount: -5, at: now)
        }
        await #expect(throws: AccountMutationError.balanceDateInFuture) {
            _ = try await service.setBalance(account: store.account, amount: 5, at: now.addingTimeInterval(60))
        }
        // The opening checkpoint is an hour old, so a balance from two hours ago would never count.
        await #expect(throws: AccountMutationError.balanceDateBeforeLatestCheckpoint) {
            _ = try await service.setBalance(account: store.account, amount: 5, at: now.addingTimeInterval(-7_200))
        }
        #expect(store.account.checkpoints.count == 1)
        #expect(await refresher.refreshCount == 0)
    }

    @Test("Archiving excludes the account from the combined balance and the widget snapshot")
    func archiveExcludesFromBalanceAndSnapshot() async throws {
        let store = try makeStore()
        let url = FileManager.default.temporaryDirectory.appending(path: "zentri-archive-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let snapshotStore = FileWidgetSnapshotStore(fileURL: url)
        let refresher = LiveWidgetSnapshotRefresher(
            context: store.context,
            store: snapshotStore,
            settings: { .defaultValue },
            now: { now },
            calendar: Calendar(identifier: .gregorian)
        )
        let service = makeService(store, refresher: refresher)
        let savings = try await service.create(name: "Savings", institutionName: nil, openingBalance: 500)
        #expect(snapshotStore.read()?.balance == "1500")

        try await service.archive(savings)

        #expect(savings.archivedAt == now)
        let active = try store.context.fetch(FetchDescriptor<Account>()).filter { $0.archivedAt == nil }
        #expect(active.map(\.id) == [store.account.id])
        #expect(BalanceCalculator.combined(accounts: active) == 1_000)
        #expect(snapshotStore.read()?.balance == "1000")
        // Archiving hides the account; it keeps its history.
        #expect(savings.checkpoints.count == 1)
    }

    @Test("Unarchiving returns the account to the combined balance")
    func unarchiveRestoresAccount() async throws {
        let store = try makeStore()
        let refresher = CountingSnapshotRefresher()
        let service = makeService(store, refresher: refresher)
        try await service.archive(store.account)

        try await service.unarchive(store.account)

        #expect(store.account.archivedAt == nil)
        #expect(await refresher.refreshCount == 2)
    }

    @Test("Rename updates the name and institution, trimmed")
    func renameUpdatesAccount() async throws {
        let store = try makeStore()
        let refresher = CountingSnapshotRefresher()
        let service = makeService(store, refresher: refresher)

        try await service.rename(store.account, name: " Daily ", institutionName: " Metro Bank ")

        #expect(store.account.name == "Daily")
        #expect(store.account.institutionName == "Metro Bank")
        #expect(await refresher.refreshCount == 1)

        try await service.rename(store.account, name: "Daily", institutionName: "")
        #expect(store.account.institutionName == nil)
    }

    @Test("Rename refuses a blank name and leaves the account alone")
    func renameValidates() async throws {
        let store = try makeStore()
        let service = makeService(store, refresher: CountingSnapshotRefresher())

        await #expect(throws: AccountMutationError.missingName) {
            try await service.rename(store.account, name: " ", institutionName: "Bank")
        }
        #expect(store.account.name == "Everyday")
        #expect(store.account.institutionName == nil)
    }

    @Test("A failed save rolls the change back and does not refresh")
    func failedSaveRollsBack() async throws {
        let store = try makeStore()
        let refresher = CountingSnapshotRefresher()
        let service = makeService(store, refresher: refresher)
        service.saveHandler = { _ in throw CocoaError(.fileWriteUnknown) }

        await #expect(throws: CocoaError.self) {
            _ = try await service.create(name: "Savings", institutionName: nil, openingBalance: 10)
        }
        await #expect(throws: CocoaError.self) {
            try await service.archive(store.account)
        }

        #expect(store.account.archivedAt == nil)
        #expect(try store.context.fetch(FetchDescriptor<Account>()).count == 1)
        #expect(try store.context.fetch(FetchDescriptor<BalanceCheckpoint>()).count == 1)
        #expect(await refresher.refreshCount == 0)
    }
}
