import Foundation
import SwiftData
import Testing
import ZentriCore
@testable import ZentriApp

@MainActor
private func parsedTransaction(_ store: ParsingTestStore) async throws -> ZentriCore.Transaction {
    try store.addRule("Card debit")
    let message = try store.addMessage(status: .failed)
    _ = await store.reprocess(message, accountID: nil)
    return try #require(message.transaction)
}

@MainActor
@Test func detailReprocessUpdatesTheSameTransaction() async throws {
    let store = try ParsingTestStore()
    let transaction = try await parsedTransaction(store)
    transaction.amount = 1
    transaction.note = "Kept"
    try store.context.save()
    let model = TransactionDetailModel(
        transaction: transaction,
        service: TransactionMutationService(context: store.context, snapshotRefresher: ParsingInertRefresher()),
        onMutation: {},
        onReprocess: store.reprocess
    )
    #expect(model.canReprocess)

    await model.reprocess()

    #expect(transaction.amount == Decimal(string: "42.75"))
    #expect(transaction.note == "Kept")
    #expect(model.changeCount == 1)
    #expect(model.reprocessMessage != nil)
    #expect(!model.isReprocessing)
    #expect(try store.context.fetchCount(FetchDescriptor<ZentriCore.Transaction>()) == 1)
}

@MainActor
@Test func detailReprocessThatFailsLeavesTheTransaction() async throws {
    let store = try ParsingTestStore()
    let transaction = try await parsedTransaction(store)
    for rule in try store.context.fetch(FetchDescriptor<ParsingRule>()) {
        rule.pattern = #"at (?<amount>[A-Za-z]+)"#
    }
    try store.context.save()
    let model = TransactionDetailModel(
        transaction: transaction,
        service: TransactionMutationService(context: store.context, snapshotRefresher: ParsingInertRefresher()),
        onMutation: {},
        onReprocess: store.reprocess
    )

    await model.reprocess()

    #expect(transaction.amount == Decimal(string: "42.75"))
    #expect(model.changeCount == 0)
    #expect(model.reprocessMessage != nil)
}

@MainActor
@Test func manualTransactionCannotBeReprocessed() throws {
    let store = try ParsingTestStore()
    let manual = ZentriCore.Transaction(
        account: store.account, amount: 5, direction: .debit, occurredAt: .now,
        merchantRaw: "Cash", merchantDisplay: "Cash", parseEngine: .manual
    )
    store.context.insert(manual)
    let model = TransactionDetailModel(
        transaction: manual,
        service: TransactionMutationService(context: store.context, snapshotRefresher: ParsingInertRefresher()),
        onMutation: {},
        onReprocess: store.reprocess
    )

    #expect(!model.canReprocess)
}
