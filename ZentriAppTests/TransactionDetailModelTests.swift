import Foundation
import SwiftData
import Testing
import ZentriCore
@testable import ZentriApp

/// A refresher with nothing to refresh; the service's own tests count refreshes.
private struct InertRefresher: WidgetSnapshotRefresher {
    func refresh() async {}
}

/// Counts how often the detail told the app the store changed.
@MainActor
private final class MutationCounter {
    var count = 0
    func record() { count += 1 }
}

@MainActor
private struct DetailFixture {
    let container: ModelContainer
    let transaction: ZentriCore.Transaction
    let message: RawMessage
    let dining: ZentriCore.Category
    let counter = MutationCounter()
    let model: TransactionDetailModel

    init() throws {
        container = try ZentriContainer.make(inMemory: true)
        let context = container.mainContext
        let account = Account(name: "Everyday", sortOrder: 0, createdAt: .now)
        dining = ZentriCore.Category(name: "Dining", symbolName: "fork.knife", colorToken: "coral", sortOrder: 0)
        message = RawMessage(text: "Paid 9.00 at Cafe", receivedAt: .now, status: .parsed, fingerprint: "cafe")
        transaction = ZentriCore.Transaction(
            account: account,
            amount: 9,
            direction: .debit,
            occurredAt: .now,
            merchantRaw: "CAFE",
            merchantDisplay: "Cafe",
            rawMessage: message,
            parseEngine: .rules
        )
        context.insert(account)
        context.insert(dining)
        context.insert(message)
        context.insert(transaction)
        try context.save()
        let counter = counter
        model = TransactionDetailModel(
            transaction: transaction,
            service: TransactionMutationService(context: context, snapshotRefresher: InertRefresher()),
            onMutation: { counter.record() }
        )
    }
}

@MainActor
@Suite("TransactionDetailModel")
struct TransactionDetailModelTests {
    @Test("Choosing a category marks it manual, tells the app, and offers the merchant rule")
    func chooseCategory() async throws {
        let fixture = try DetailFixture()

        await fixture.model.setCategory(fixture.dining.id)

        #expect(fixture.transaction.category?.id == fixture.dining.id)
        #expect(fixture.transaction.categorySource == .manual)
        #expect(fixture.model.offersCategoryRule)
        #expect(fixture.model.changeCount == 1)
        #expect(fixture.counter.count == 1)

        await fixture.model.alwaysCategorizeMerchant()
        #expect(fixture.model.hasCreatedRule)
        let rules = try fixture.container.mainContext.fetch(FetchDescriptor<CategorizationRule>())
        #expect(rules.map(\.keyword) == ["cafe"])
    }

    @Test("The transfer toggle saves through the service")
    func transfer() async throws {
        let fixture = try DetailFixture()

        await fixture.model.setTransfer(true)

        #expect(fixture.model.isTransfer)
        #expect(fixture.counter.count == 1)
    }

    @Test("A refused edit is rethrown and nothing is reported as changed")
    func refusedEdit() async throws {
        let fixture = try DetailFixture()
        var edit = fixture.model.currentEdit
        edit.amount = 0

        await #expect(throws: TransactionMutationError.invalidAmount) {
            try await fixture.model.save(edit)
        }
        #expect(fixture.counter.count == 0)
        #expect(fixture.transaction.amount == 9)
    }

    @Test("Delete removes the transaction, keeps its message, and tells the app")
    func delete() async throws {
        let fixture = try DetailFixture()

        let deleted = await fixture.model.delete()

        #expect(deleted)
        #expect(fixture.model.isDeleted)
        #expect(fixture.counter.count == 1)
        let context = fixture.container.mainContext
        #expect(try context.fetch(FetchDescriptor<ZentriCore.Transaction>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<RawMessage>()).count == 1)
    }
}
