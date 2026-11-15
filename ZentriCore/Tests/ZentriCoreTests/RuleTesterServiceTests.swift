import Foundation
import SwiftData
import Testing
@testable import ZentriCore

/// 2026-11-18 11:06:40 UTC.
private let testerNow = Date(timeIntervalSince1970: 1_795_000_000)

private let sampleText = "MYBANK: RM12.50 spent at KFC Avl Bal RM1,234.50"

private let debitPattern = #"RM(?<amount>[\d.,]+) spent at (?<merchant>.+?) Avl Bal RM(?<balance>[\d.,]+)"#

private func debitRule(id: UUID = UUID(), accountID: UUID? = nil, priority: Int = 0) -> ParsingRuleSpec {
    ParsingRuleSpec(id: id, accountID: accountID, direction: .debit, pattern: debitPattern, priority: priority)
}

private func modelOutput() -> ModelTransactionOutput {
    ModelTransactionOutput(isTransaction: true, direction: "debit", amount: "12.50", merchant: "KFC", balance: "1,234.50")
}

@MainActor
private func makeTester(_ client: StubModelClient) -> RuleTesterService {
    RuleTesterService(parserBuilder: ParserFactory(modelClient: client), now: { testerNow })
}

private func draft(_ result: ParseResult?) -> TransactionDraft? {
    if case .transaction(let draft) = result { return draft }
    return nil
}

private func codes(_ result: ParseResult?) -> [ParseDiagnostic.Code] {
    if case .failure(let diagnostics) = result { return diagnostics.map(\.code) }
    return []
}

@MainActor
@Test func hybridComparisonReturnsBothResultsWithTimings() async throws {
    let rule = debitRule()
    let tester = makeTester(StubModelClient(result: .success(modelOutput())))

    let comparison = await tester.test(text: sampleText, accountID: nil, rules: [rule], mode: .hybrid)

    let ruleDraft = try #require(draft(comparison.ruleResult))
    #expect(ruleDraft.amount == Decimal(string: "12.50"))
    #expect(ruleDraft.merchant == "KFC")
    #expect(ruleDraft.balanceAfter == Decimal(string: "1234.50"))
    #expect(ruleDraft.matchedRuleID == rule.id)
    let modelDraft = try #require(draft(comparison.modelResult))
    #expect(modelDraft.amount == Decimal(string: "12.50"))
    #expect(modelDraft.matchedRuleID == nil)
    #expect(comparison.modelAvailable == true)
    #expect(try #require(comparison.ruleMilliseconds) >= 0)
    #expect(try #require(comparison.modelMilliseconds) >= 0)
    #expect(comparison.matchingRuleIDs == [rule.id])
}

@MainActor
@Test func unavailableModelIsReportedWithoutFailingTheRules() async throws {
    let client = StubModelClient(
        availabilityValue: .unavailable("Apple Intelligence is turned off in Settings."),
        result: .success(modelOutput())
    )
    let tester = makeTester(client)

    let comparison = await tester.test(text: sampleText, accountID: nil, rules: [debitRule()], mode: .hybrid)

    #expect(comparison.modelAvailable == false)
    #expect(codes(comparison.modelResult) == [.modelUnavailable])
    #expect(draft(comparison.ruleResult) != nil)
    #expect(comparison.modelMilliseconds != nil)
}

@MainActor
@Test func rulesModeNeverAsksTheModel() async {
    let counter = CallCounter()
    let tester = makeTester(StubModelClient(result: .success(modelOutput()), counter: counter))

    let comparison = await tester.test(text: sampleText, accountID: nil, rules: [debitRule()], mode: .rules)

    #expect(draft(comparison.ruleResult) != nil)
    #expect(comparison.modelResult == nil)
    #expect(comparison.modelAvailable == nil)
    #expect(comparison.modelMilliseconds == nil)
    #expect(await counter.parseCalls == 0)
}

@MainActor
@Test func foundationModelsModeRunsOnlyTheModel() async {
    let tester = makeTester(StubModelClient(result: .success(modelOutput())))

    let comparison = await tester.test(text: sampleText, accountID: nil, rules: [debitRule()], mode: .foundationModels)

    #expect(comparison.ruleResult == nil)
    #expect(comparison.ruleMilliseconds == nil)
    #expect(draft(comparison.modelResult) != nil)
    #expect(comparison.modelAvailable == true)
}

@MainActor
@Test func competingMatchesAreListedInEvaluationOrder() async {
    let first = debitRule(priority: 0)
    let second = debitRule(priority: 5)
    let broken = ParsingRuleSpec(direction: .credit, pattern: #"never (?<amount>\d+)"#, priority: 1)
    let tester = makeTester(StubModelClient(result: .success(modelOutput())))

    let comparison = await tester.test(text: sampleText, accountID: nil, rules: [second, broken, first], mode: .rules)

    #expect(draft(comparison.ruleResult)?.matchedRuleID == first.id)
    #expect(comparison.matchingRuleIDs == [first.id, second.id])
}

@MainActor
@Test func accountScopesTheRules() async {
    let account = UUID()
    let otherAccountRule = debitRule(accountID: UUID())
    let tester = makeTester(StubModelClient(result: .success(modelOutput())))

    let comparison = await tester.test(text: sampleText, accountID: account, rules: [otherAccountRule], mode: .rules)

    #expect(comparison.ruleResult == .notTransaction)
    #expect(comparison.matchingRuleIDs.isEmpty)
}

@MainActor
@Test func testingNeverWritesToTheStore() async throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = container.mainContext
    let account = Account(name: "Everyday", sortOrder: 0, createdAt: testerNow)
    context.insert(account)
    context.insert(ParsingRule(
        account: account, name: "Debit", direction: .debit, pattern: debitPattern, priority: 0, isEnabled: true
    ))
    try context.save()
    let rules = try StoredParsingRules.specs(in: context)
    let tester = makeTester(StubModelClient(result: .success(modelOutput())))

    let comparison = await tester.test(text: sampleText, accountID: account.id, rules: rules, mode: .hybrid)
    _ = await tester.preview(rule: rules[0], text: sampleText)

    #expect(draft(comparison.ruleResult) != nil)
    #expect(!context.hasChanges)
    #expect(try context.fetchCount(FetchDescriptor<RawMessage>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<ZentriCore.Transaction>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<BalanceCheckpoint>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<ParsingRule>()) == 1)
}

@MainActor
@Test func previewReportsCapturesWithTheirPositions() async throws {
    let tester = makeTester(StubModelClient(result: .success(modelOutput())))

    let preview = await tester.preview(rule: debitRule(), text: sampleText)

    let names = preview.captures.map(\.name)
    #expect(names == ["amount", "merchant", "balance"])
    let amount = try #require(preview.captures.first { $0.name == "amount" })
    #expect(amount.value == "12.50")
    let characters = Array(sampleText)
    #expect(String(characters[amount.range]) == "12.50")
    #expect(draft(preview.result)?.merchant == "KFC")
}

@MainActor
@Test func previewOfAMatchThatFailsValidationKeepsTheDiagnostics() async {
    let rule = ParsingRuleSpec(direction: .debit, pattern: #"RM(?<amount>[\d.,]+) spent"#)
    let tester = makeTester(StubModelClient(result: .success(modelOutput())))

    let preview = await tester.preview(rule: rule, text: "RM0.00 spent")

    #expect(preview.captures.map(\.name) == ["amount"])
    #expect(codes(preview.result) == [.amountNotPositive])
}

@MainActor
@Test func previewIgnoresTheRuleSwitchAndAccount() async {
    // The editor previews the rule being edited even while it is off or belongs to another account.
    let rule = ParsingRuleSpec(accountID: UUID(), direction: .debit, pattern: debitPattern, isEnabled: false)
    let tester = makeTester(StubModelClient(result: .success(modelOutput())))

    let preview = await tester.preview(rule: rule, text: sampleText)

    #expect(draft(preview.result)?.amount == Decimal(string: "12.50"))
}

@MainActor
@Test func previewOfAnInvalidPatternHasNoCaptures() async {
    let rule = ParsingRuleSpec(direction: .debit, pattern: #"RM(?<amount>\d+"#)
    let tester = makeTester(StubModelClient(result: .success(modelOutput())))

    let preview = await tester.preview(rule: rule, text: sampleText)

    #expect(preview.captures.isEmpty)
    #expect(codes(preview.result) == [.invalidPattern])
}
