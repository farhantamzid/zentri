import Foundation
import SwiftData
import Testing
import ZentriCore
@testable import ZentriApp

@MainActor
private func makeModel(
    _ store: ParsingTestStore,
    accountID: UUID? = nil,
    counter: ParsingMutationCounter = ParsingMutationCounter(),
    reprocessFailures: @escaping @MainActor () async -> [IngestionOutcome] = { [] }
) -> ParsingRulesModel {
    ParsingRulesModel(
        accountID: accountID,
        context: store.context,
        service: ParsingRuleMutationService(context: store.context),
        reprocessFailures: reprocessFailures,
        onMutation: counter.record
    )
}

private func draft(accountID: UUID, pattern: String = parsingTestPattern) -> ParsingRuleDraft {
    ParsingRuleDraft(accountID: accountID, name: "New rule", direction: .debit, pattern: pattern)
}

@MainActor
@Test func rulesAreGroupedByAccountAndDirectionInEvaluationOrder() throws {
    let store = try ParsingTestStore()
    let savings = try store.addAccount("Savings", sortOrder: 1)
    let start = Date.now
    try store.addRule("Late", priority: 1, createdAt: start.addingTimeInterval(10))
    try store.addRule("Early", priority: 1, createdAt: start)
    try store.addRule("First", priority: 0, createdAt: start.addingTimeInterval(20))
    try store.addRule("Salary", direction: .credit)
    try store.addRule("Savings debit", account: savings)
    let model = makeModel(store)

    model.refresh()

    #expect(model.loadState == .loaded)
    #expect(model.sections.map(\.accountName) == ["Everyday", "Everyday", "Savings"])
    #expect(model.sections.map(\.direction) == [.debit, .credit, .debit])
    #expect(model.sections[0].rules.map(\.name) == ["First", "Early", "Late"])
    #expect(model.sections[1].rules.map(\.name) == ["Salary"])
    #expect(model.accounts.map(\.name) == ["Everyday", "Savings"])
}

@MainActor
@Test func oneAccountsListShowsOnlyItsRules() throws {
    let store = try ParsingTestStore()
    let savings = try store.addAccount("Savings", sortOrder: 1)
    try store.addRule("Everyday debit")
    try store.addRule("Savings debit", account: savings)
    let model = makeModel(store, accountID: savings.id)

    model.refresh()

    #expect(model.sections.flatMap(\.rules).map(\.name) == ["Savings debit"])
    #expect(model.defaultAccountID == savings.id)
}

@MainActor
@Test func failedReadIsNotAnEmptyList() throws {
    let store = try ParsingTestStore()
    let model = ParsingRulesModel(
        accountID: nil,
        fetchRules: { throw ParsingReadFailure.unreadable },
        fetchAccounts: { [store] in try store.context.fetch(FetchDescriptor<Account>()) },
        fetchMessages: { [] },
        service: ParsingRuleMutationService(context: store.context),
        reprocessFailures: { [] },
        onMutation: {}
    )

    model.refresh()

    #expect(model.loadState == .failed)
    #expect(model.sections.isEmpty)
}

@MainActor
@Test func savingABrokenPatternIsRefusedAndChangesNothing() throws {
    let store = try ParsingTestStore()
    let counter = ParsingMutationCounter()
    let model = makeModel(store, counter: counter)
    model.refresh()

    #expect(throws: ParsingRuleMutationError.invalidPattern(.missingAmountGroup)) {
        try model.create(draft(accountID: store.account.id, pattern: #"at (?<merchant>.+)"#))
    }
    #expect(counter.count == 0)
    #expect(!model.hasChangedRules)
    #expect(model.sections.isEmpty)
}

@MainActor
@Test func aRuleChangeOffersToReprocessFailures() async throws {
    let store = try ParsingTestStore()
    try store.addMessage(status: .failed)
    let counter = ParsingMutationCounter()
    let reprocessCalls = ParsingMutationCounter()
    let model = makeModel(store, counter: counter) {
        reprocessCalls.record()
        return [.transaction(UUID()), .failed([])]
    }
    model.refresh()
    #expect(!model.offersReprocessFailures)

    try model.create(draft(accountID: store.account.id))

    #expect(counter.count == 1)
    #expect(model.sections.flatMap(\.rules).map(\.name) == ["New rule"])
    #expect(model.failedMessageCount == 1)
    #expect(model.offersReprocessFailures)

    let summary = await model.reprocessFailures()

    #expect(reprocessCalls.count == 1)
    #expect(summary == ReprocessSummary(outcomes: [.transaction(UUID()), .failed([])]))
    #expect(summary.parsed == 1)
    #expect(summary.stillFailed == 1)
    #expect(!model.offersReprocessFailures)
}

@MainActor
@Test func noFailuresMeansNoOffer() throws {
    let store = try ParsingTestStore()
    let model = makeModel(store)
    model.refresh()

    try model.create(draft(accountID: store.account.id))

    #expect(model.hasChangedRules)
    #expect(!model.offersReprocessFailures)
}

@MainActor
@Test func rulesCanBeSwitchedEditedAndDeleted() throws {
    let store = try ParsingTestStore()
    let rule = try store.addRule("Card debit")
    let counter = ParsingMutationCounter()
    let model = makeModel(store, counter: counter)
    model.refresh()

    try model.setEnabled(false, id: rule.id)
    #expect(model.sections.first?.rules.first?.isEnabled == false)

    var edit = draft(accountID: store.account.id)
    edit.name = "Renamed"
    try model.update(id: rule.id, with: edit)
    #expect(model.sections.first?.rules.first?.name == "Renamed")

    try model.delete(id: rule.id)
    #expect(model.sections.isEmpty)
    #expect(counter.count == 3)
}

@MainActor
@Test func aBrokenStoredPatternIsFlagged() throws {
    let store = try ParsingTestStore()
    try store.addRule("Imported", pattern: "RM(")
    let model = makeModel(store)

    model.refresh()

    #expect(model.sections.first?.rules.first?.isPatternValid == false)
}
