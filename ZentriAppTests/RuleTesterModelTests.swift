import Foundation
import SwiftData
import Testing
import ZentriCore
@testable import ZentriApp

@MainActor
private func makeTester(_ store: ParsingTestStore) -> RuleTesterModel {
    RuleTesterModel(
        context: store.context,
        tester: RuleTesterService(parserBuilder: ParserFactory(modelClient: UnavailableModelClient()))
    )
}

@MainActor
@Test func testerShowsTheMatchedRuleAndItsFields() async throws {
    let store = try ParsingTestStore()
    let rule = try store.addRule("Card debit")
    let tester = makeTester(store)
    tester.refresh()
    tester.text = parsingTestMessage

    await tester.run()

    let comparison = try #require(tester.comparison)
    guard case .transaction(let draft) = comparison.ruleResult else {
        Issue.record("The rule did not parse the sample: \(String(describing: comparison.ruleResult))")
        return
    }
    #expect(draft.amount == Decimal(string: "42.75"))
    #expect(draft.merchant == "Fixture Cafe")
    #expect(tester.ruleName(for: draft.matchedRuleID) == rule.name)
    #expect(comparison.modelResult == nil)
}

@MainActor
@Test func comparingWithTheModelReportsItUnavailable() async throws {
    let store = try ParsingTestStore()
    try store.addRule("Card debit")
    let tester = makeTester(store)
    tester.refresh()
    tester.text = parsingTestMessage
    tester.comparesWithModel = true

    await tester.run()

    let comparison = try #require(tester.comparison)
    #expect(comparison.modelAvailable == false)
    #expect(comparison.ruleResult != nil)
}

@MainActor
@Test func testingWritesNothing() async throws {
    let store = try ParsingTestStore()
    try store.addRule("Card debit")
    let tester = makeTester(store)
    tester.refresh()
    tester.text = parsingTestMessage
    tester.comparesWithModel = true

    await tester.run()

    #expect(tester.comparison != nil)
    #expect(!store.context.hasChanges)
    #expect(try store.context.fetchCount(FetchDescriptor<RawMessage>()) == 0)
    #expect(try store.context.fetchCount(FetchDescriptor<ZentriCore.Transaction>()) == 0)
}

@MainActor
@Test func testerCannotRunWithoutTextOrRules() async throws {
    let store = try ParsingTestStore()
    let failing = RuleTesterModel(
        fetchRules: { throw ParsingReadFailure.unreadable },
        fetchAccounts: { [] },
        tester: RuleTesterService(parserBuilder: ParserFactory(modelClient: UnavailableModelClient()))
    )
    failing.refresh()
    failing.text = parsingTestMessage
    #expect(failing.loadState == .failed)
    #expect(!failing.canRun)

    let tester = makeTester(store)
    tester.refresh()
    tester.text = "   "
    #expect(!tester.canRun)
    await tester.run()
    #expect(tester.state == .idle)
}

@MainActor
@Test func testingAsAnotherAccountSkipsThisAccountsRules() async throws {
    let store = try ParsingTestStore()
    try store.addRule("Card debit")
    let savings = try store.addAccount("Savings", sortOrder: 1)
    let tester = makeTester(store)
    tester.refresh()
    tester.text = parsingTestMessage
    tester.accountID = savings.id

    await tester.run()

    #expect(tester.comparison?.ruleResult == .notTransaction)
}
