import Foundation
import SwiftData
import Testing
@testable import ZentriCore

/// Counts snapshot refreshes so a test can prove every mutation refreshed the widgets.
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
    let dining: ZentriCore.Category
    let transport: ZentriCore.Category
    var context: ModelContext { container.mainContext }
}

@MainActor
private func makeStore() throws -> Store {
    let container = try ZentriContainer.make(inMemory: true)
    let context = container.mainContext
    let account = Account(name: "Everyday", sortOrder: 0, createdAt: now)
    let dining = ZentriCore.Category(name: "Dining", symbolName: "fork.knife", colorToken: "coral", sortOrder: 0)
    let transport = ZentriCore.Category(name: "Transport", symbolName: "car", colorToken: "teal", sortOrder: 1)
    context.insert(account)
    context.insert(dining)
    context.insert(transport)
    try context.save()
    return Store(container: container, account: account, dining: dining, transport: transport)
}

@MainActor
private func makeService(
    _ store: Store,
    refresher: CountingSnapshotRefresher
) -> TransactionMutationService {
    TransactionMutationService(context: store.context, snapshotRefresher: refresher, now: { now })
}

/// A message-sourced transaction linked to its raw SMS, the way ingestion stores one.
@MainActor
private func addIngested(_ store: Store) throws -> ZentriCore.Transaction {
    let message = RawMessage(
        text: "Paid 120.00 to GRAB*RIDE",
        receivedAt: now.addingTimeInterval(-60),
        status: .parsed,
        engine: .rules,
        fingerprint: "grab"
    )
    let transaction = ZentriCore.Transaction(
        account: store.account,
        amount: 120,
        direction: .debit,
        occurredAt: now.addingTimeInterval(-60),
        recordedAt: now.addingTimeInterval(-60),
        merchantRaw: "GRAB*RIDE",
        merchantDisplay: "Grab",
        category: store.transport,
        categorySource: .rule,
        rawMessage: message,
        parseEngine: .rules
    )
    store.context.insert(message)
    store.context.insert(transaction)
    try store.context.save()
    return transaction
}

private func edit(
    accountID: UUID,
    amount: Decimal = 25,
    direction: Direction = .debit,
    occurredAt: Date = now,
    merchant: String = "Missed payment",
    categoryID: UUID? = nil,
    note: String? = nil,
    isTransfer: Bool = false
) -> TransactionEdit {
    TransactionEdit(
        accountID: accountID,
        amount: amount,
        direction: direction,
        occurredAt: occurredAt,
        merchant: merchant,
        categoryID: categoryID,
        note: note,
        isTransfer: isTransfer
    )
}

@MainActor
@Suite("TransactionMutationService")
struct TransactionMutationServiceTests {
    @Test("A manual add is marked manual and refreshes the snapshot")
    func manualAdd() async throws {
        let store = try makeStore()
        let refresher = CountingSnapshotRefresher()
        let service = makeService(store, refresher: refresher)

        let saved = try await service.save(
            edit(accountID: store.account.id, categoryID: store.dining.id, note: "Cash"),
            existing: nil
        )

        let stored = try store.context.fetch(FetchDescriptor<ZentriCore.Transaction>())
        #expect(stored.count == 1)
        #expect(stored.first?.id == saved.id)
        #expect(saved.parseEngine == .manual)
        #expect(saved.categorySource == .manual)
        #expect(saved.category?.id == store.dining.id)
        #expect(saved.amount == 25)
        #expect(saved.merchantDisplay == "Missed payment")
        #expect(saved.merchantRaw == "Missed payment")
        #expect(saved.note == "Cash")
        #expect(saved.rawMessage == nil)
        // A missed transaction counts toward the balance from when it happened.
        #expect(saved.recordedAt == now)
        #expect(saved.createdAt == now)
        #expect(await refresher.refreshCount == 1)
    }

    @Test("A blank note is stored as no note")
    func blankNote() async throws {
        let store = try makeStore()
        let service = makeService(store, refresher: CountingSnapshotRefresher())

        let saved = try await service.save(edit(accountID: store.account.id, note: "   "), existing: nil)

        #expect(saved.note == nil)
    }

    @Test("An edit updates every field, keeps the raw message, and refreshes the snapshot")
    func editExisting() async throws {
        let store = try makeStore()
        let refresher = CountingSnapshotRefresher()
        let service = makeService(store, refresher: refresher)
        let transaction = try addIngested(store)
        let message = try #require(transaction.rawMessage)
        let other = Account(name: "Savings", sortOrder: 1, createdAt: now)
        store.context.insert(other)
        let occurredAt = now.addingTimeInterval(-3_600)

        try await service.save(
            edit(
                accountID: other.id,
                amount: 130,
                direction: .credit,
                occurredAt: occurredAt,
                merchant: "Grab Food",
                categoryID: store.dining.id,
                note: "Lunch",
                isTransfer: true
            ),
            existing: transaction
        )

        #expect(transaction.account.id == other.id)
        #expect(transaction.amount == 130)
        #expect(transaction.direction == .credit)
        #expect(transaction.occurredAt == occurredAt)
        #expect(transaction.merchantDisplay == "Grab Food")
        #expect(transaction.merchantRaw == "GRAB*RIDE")
        #expect(transaction.category?.id == store.dining.id)
        #expect(transaction.categorySource == .manual)
        #expect(transaction.note == "Lunch")
        #expect(transaction.isTransfer)
        #expect(transaction.updatedAt == now)
        #expect(transaction.rawMessage?.id == message.id)
        #expect(transaction.parseEngine == .rules)
        // The message's arrival still anchors a message-sourced transaction in the balance.
        #expect(transaction.recordedAt == now.addingTimeInterval(-60))
        #expect(message.transaction?.id == transaction.id)
        #expect(await refresher.refreshCount == 1)
    }

    @Test("An edit that keeps the category keeps its source")
    func editKeepsCategorySource() async throws {
        let store = try makeStore()
        let service = makeService(store, refresher: CountingSnapshotRefresher())
        let transaction = try addIngested(store)

        try await service.save(
            edit(accountID: store.account.id, amount: 99, merchant: "Grab", categoryID: store.transport.id),
            existing: transaction
        )

        #expect(transaction.categorySource == .rule)
        #expect(transaction.amount == 99)
    }

    @Test("Editing a manual transaction's date moves it in the balance too")
    func editManualDate() async throws {
        let store = try makeStore()
        let service = makeService(store, refresher: CountingSnapshotRefresher())
        let saved = try await service.save(edit(accountID: store.account.id), existing: nil)
        let earlier = now.addingTimeInterval(-86_400)

        try await service.save(edit(accountID: store.account.id, occurredAt: earlier), existing: saved)

        #expect(saved.occurredAt == earlier)
        #expect(saved.recordedAt == earlier)
        #expect(saved.parseEngine == .manual)
    }

    @Test("An edit built from a transaction describes it unchanged")
    func editFromTransaction() async throws {
        let store = try makeStore()
        let transaction = try addIngested(store)
        transaction.note = "Ride home"

        let current = TransactionEdit(transaction)

        #expect(current == TransactionEdit(
            accountID: store.account.id,
            amount: 120,
            direction: .debit,
            occurredAt: now.addingTimeInterval(-60),
            merchant: "Grab",
            categoryID: store.transport.id,
            note: "Ride home",
            isTransfer: false
        ))
    }

    @Test("Delete removes the transaction, keeps its raw message, and refreshes the snapshot")
    func delete() async throws {
        let store = try makeStore()
        let refresher = CountingSnapshotRefresher()
        let service = makeService(store, refresher: refresher)
        let transaction = try addIngested(store)

        try await service.delete(transaction)

        #expect(try store.context.fetch(FetchDescriptor<ZentriCore.Transaction>()).isEmpty)
        let messages = try store.context.fetch(FetchDescriptor<RawMessage>())
        #expect(messages.count == 1)
        #expect(messages.first?.transaction == nil)
        #expect(await refresher.refreshCount == 1)
    }

    @Test("Setting the transfer flag updates it and refreshes the snapshot")
    func setTransfer() async throws {
        let store = try makeStore()
        let refresher = CountingSnapshotRefresher()
        let service = makeService(store, refresher: refresher)
        let transaction = try addIngested(store)

        try await service.setTransfer(transaction, isTransfer: true)

        #expect(transaction.isTransfer)
        #expect(transaction.updatedAt == now)
        #expect(await refresher.refreshCount == 1)
    }

    @Test("A category change is marked manual")
    func setCategory() async throws {
        let store = try makeStore()
        let refresher = CountingSnapshotRefresher()
        let service = makeService(store, refresher: refresher)
        let transaction = try addIngested(store)

        try await service.setCategory(transaction, categoryID: store.dining.id)

        #expect(transaction.category?.id == store.dining.id)
        #expect(transaction.categorySource == .manual)
        #expect(await refresher.refreshCount == 1)
    }

    @Test("Always categorizing a merchant creates a rule that wins over existing ones")
    func alwaysCategorize() async throws {
        let store = try makeStore()
        store.context.insert(CategorizationRule(keyword: "grab", category: store.transport, priority: 0, isEnabled: true))
        try store.context.save()
        let refresher = CountingSnapshotRefresher()
        let service = makeService(store, refresher: refresher)

        try await service.alwaysCategorize(merchant: "  Grab Food ", categoryID: store.dining.id)

        let rules = try store.context.fetch(FetchDescriptor<CategorizationRule>())
        let rule = try #require(rules.first { $0.keyword == "grab food" })
        #expect(rule.category.id == store.dining.id)
        #expect(rule.isEnabled)
        #expect(rule.priority < 0)
        let specs = rules.map {
            CategorizationRuleSpec(
                keyword: $0.keyword,
                categoryName: $0.category.name,
                priority: $0.priority,
                isEnabled: $0.isEnabled
            )
        }
        #expect(CategorizationService.match(merchant: "Grab Food", rules: specs, suggestion: nil).categoryName == "Dining")
        #expect(await refresher.refreshCount == 0)
    }

    @Test("Always categorizing a merchant that already has a rule updates that rule")
    func alwaysCategorizeExistingKeyword() async throws {
        let store = try makeStore()
        store.context.insert(CategorizationRule(keyword: "grab", category: store.transport, priority: 3, isEnabled: false))
        try store.context.save()
        let service = makeService(store, refresher: CountingSnapshotRefresher())

        try await service.alwaysCategorize(merchant: "GRAB", categoryID: store.dining.id)

        let rules = try store.context.fetch(FetchDescriptor<CategorizationRule>())
        #expect(rules.count == 1)
        #expect(rules.first?.category.id == store.dining.id)
        #expect(rules.first?.isEnabled == true)
    }

    @Test("Invalid amounts are rejected without saving or refreshing", arguments: [Decimal(0), Decimal(-5)])
    func invalidAmount(amount: Decimal) async throws {
        let store = try makeStore()
        let refresher = CountingSnapshotRefresher()
        let service = makeService(store, refresher: refresher)

        await #expect(throws: TransactionMutationError.invalidAmount) {
            _ = try await service.save(edit(accountID: store.account.id, amount: amount), existing: nil)
        }
        #expect(try store.context.fetch(FetchDescriptor<ZentriCore.Transaction>()).isEmpty)
        #expect(await refresher.refreshCount == 0)
    }

    @Test("An edit with an invalid amount leaves the transaction unchanged")
    func invalidAmountOnEdit() async throws {
        let store = try makeStore()
        let service = makeService(store, refresher: CountingSnapshotRefresher())
        let transaction = try addIngested(store)

        await #expect(throws: TransactionMutationError.invalidAmount) {
            _ = try await service.save(edit(accountID: store.account.id, amount: 0, merchant: "Changed"), existing: transaction)
        }
        #expect(transaction.amount == 120)
        #expect(transaction.merchantDisplay == "Grab")
    }

    @Test("A missing account is rejected")
    func missingAccount() async throws {
        let store = try makeStore()
        let service = makeService(store, refresher: CountingSnapshotRefresher())

        await #expect(throws: TransactionMutationError.missingAccount) {
            _ = try await service.save(edit(accountID: UUID()), existing: nil)
        }
        #expect(try store.context.fetch(FetchDescriptor<ZentriCore.Transaction>()).isEmpty)
    }

    @Test("A blank merchant is rejected")
    func blankMerchant() async throws {
        let store = try makeStore()
        let service = makeService(store, refresher: CountingSnapshotRefresher())

        await #expect(throws: TransactionMutationError.missingMerchant) {
            _ = try await service.save(edit(accountID: store.account.id, merchant: "  "), existing: nil)
        }
    }

    @Test("A failed save rolls back the edit and does not refresh")
    func failedSave() async throws {
        let store = try makeStore()
        let refresher = CountingSnapshotRefresher()
        let service = makeService(store, refresher: refresher)
        let transaction = try addIngested(store)
        service.saveHandler = { _ in throw CocoaError(.fileWriteUnknown) }

        await #expect(throws: CocoaError.self) {
            try await service.setTransfer(transaction, isTransfer: true)
        }
        #expect(transaction.isTransfer == false)
        #expect(await refresher.refreshCount == 0)
    }

    @Test("Moving a message transaction to another account moves its SMS balance checkpoint with it")
    func moveCarriesTheSMSCheckpoint() async throws {
        let store = try makeStore()
        let savings = Account(name: "Savings", sortOrder: 1, createdAt: now)
        store.context.insert(savings)
        let transaction = try addIngested(store)
        let smsCheckpoint = BalanceCheckpoint(
            account: store.account,
            amount: 880,
            recordedAt: transaction.recordedAt,
            source: .sms,
            sourceTransactionID: transaction.id,
            createdAt: transaction.recordedAt
        )
        let opening = BalanceCheckpoint(
            account: store.account,
            amount: 1_000,
            recordedAt: now.addingTimeInterval(-3_600),
            source: .opening,
            createdAt: now.addingTimeInterval(-3_600)
        )
        store.context.insert(smsCheckpoint)
        store.context.insert(opening)
        try store.context.save()
        let service = makeService(store, refresher: CountingSnapshotRefresher())

        _ = try await service.save(
            edit(accountID: savings.id, amount: 120, occurredAt: transaction.occurredAt, merchant: "Grab"),
            existing: transaction
        )

        #expect(transaction.account.id == savings.id)
        #expect(smsCheckpoint.account.id == savings.id)
        #expect(smsCheckpoint.amount == 880)
        #expect(opening.account.id == store.account.id)
        #expect(store.account.checkpoints.allSatisfy { $0.sourceTransactionID != transaction.id })
    }
}
