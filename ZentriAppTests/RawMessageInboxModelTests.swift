import Foundation
import SwiftData
import Testing
import ZentriCore
@testable import ZentriApp

@MainActor
private func makeInbox(
    _ store: ParsingTestStore,
    counter: ParsingMutationCounter = ParsingMutationCounter()
) -> RawMessageInboxModel {
    RawMessageInboxModel(
        context: store.context,
        archive: store.reprocessor(),
        reprocess: store.reprocess,
        reprocessFailures: { [] },
        onMutation: counter.record
    )
}

@MainActor
@Test func failedFilterShowsFailedAndPendingNewestFirst() throws {
    let store = try ParsingTestStore()
    let now = Date.now
    let older = try store.addMessage("Older failure", status: .failed, receivedAt: now.addingTimeInterval(-600))
    let pending = try store.addMessage("Pending", status: .processing, receivedAt: now.addingTimeInterval(-300))
    let newer = try store.addMessage("Newer failure", status: .failed, receivedAt: now.addingTimeInterval(-60))
    try store.addMessage("OTP", status: .ignored)
    try store.addMessage("Read", status: .parsed)
    try store.addMessage("Again", status: .duplicate)
    let inbox = makeInbox(store)

    inbox.refresh()

    #expect(inbox.loadState == .loaded)
    #expect(inbox.filter == .failed)
    #expect(inbox.rows.map(\.id) == [newer.id, pending.id, older.id])
    #expect(inbox.counts == [.failed: 3, .ignored: 1, .parsed: 1, .duplicate: 1])
    #expect(inbox.failedCount == 2)

    inbox.filter = .ignored
    #expect(inbox.rows.map(\.text) == ["OTP"])
    inbox.filter = .parsed
    #expect(inbox.rows.map(\.text) == ["Read"])
    inbox.filter = .duplicate
    #expect(inbox.rows.map(\.text) == ["Again"])
}

@MainActor
@Test func failedReadIsNotAnEmptyInbox() throws {
    let store = try ParsingTestStore()
    try store.addMessage(status: .failed)
    let inbox = RawMessageInboxModel(
        fetchMessages: { throw ParsingReadFailure.unreadable },
        fetchRules: { [] },
        fetchAccounts: { [] },
        fetchCategories: { [] },
        archive: store.reprocessor(),
        reprocess: store.reprocess,
        reprocessFailures: { [] },
        onMutation: {}
    )

    inbox.refresh()

    #expect(inbox.loadState == .failed)
    #expect(inbox.rows.isEmpty)
    #expect(!inbox.hasMessages)
}

@MainActor
@Test func reprocessingAFailedMessageMovesItToParsed() async throws {
    let store = try ParsingTestStore()
    let rule = try store.addRule("Card debit")
    let message = try store.addMessage(status: .failed)
    let counter = ParsingMutationCounter()
    let inbox = makeInbox(store, counter: counter)
    inbox.refresh()
    #expect(!inbox.needsAccountChoice(id: message.id))

    let outcome = await inbox.reprocess(id: message.id)

    #expect(outcome?.isTransaction == true)
    #expect(counter.count == 1)
    #expect(inbox.rows.isEmpty)
    inbox.filter = .parsed
    let row = try #require(inbox.rows.first)
    #expect(row.id == message.id)
    #expect(row.hasTransaction)
    #expect(row.matchedRuleName == rule.name)
    #expect(row.engine == .rules)
    #expect(inbox.transactionSelection(forMessage: message.id)?.transaction.merchantDisplay == "Fixture Cafe")
}

@MainActor
@Test func severalAccountsAskWhichOneAMessageBelongsTo() async throws {
    let store = try ParsingTestStore()
    let savings = try store.addAccount("Savings", sortOrder: 1)
    try store.addRule("Savings debit", account: savings)
    let message = try store.addMessage(status: .failed)
    let inbox = makeInbox(store)
    inbox.refresh()

    #expect(inbox.needsAccountChoice(id: message.id))
    let unchosen = await inbox.reprocess(id: message.id)
    #expect(unchosen?.needsAccountChoice == true)

    let chosen = await inbox.reprocess(id: message.id, accountID: savings.id)
    #expect(chosen?.isTransaction == true)
    #expect(message.transaction?.account.id == savings.id)
    // A message with a transaction takes its account from it.
    #expect(!inbox.needsAccountChoice(id: message.id))
}

@MainActor
@Test func deletingAndClearingKeepTransactions() async throws {
    let store = try ParsingTestStore()
    try store.addRule("Card debit")
    let parsed = try store.addMessage(status: .failed)
    _ = await store.reprocess(parsed, accountID: nil)
    try store.addMessage("Another", status: .failed)
    let counter = ParsingMutationCounter()
    let inbox = makeInbox(store, counter: counter)
    inbox.refresh()

    try inbox.delete(id: parsed.id)
    #expect(try store.context.fetchCount(FetchDescriptor<ZentriCore.Transaction>()) == 1)
    #expect(inbox.message(id: parsed.id) == nil)

    try inbox.clearArchive()
    #expect(!inbox.hasMessages)
    #expect(try store.context.fetchCount(FetchDescriptor<RawMessage>()) == 0)
    #expect(try store.context.fetchCount(FetchDescriptor<ZentriCore.Transaction>()) == 1)
    #expect(counter.count == 2)
}
