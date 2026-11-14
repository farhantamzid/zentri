import Foundation
import Testing
@testable import ZentriCore

private let factoryText = "MYBANK: RM12.50 spent at KFC on 14/11/26. Avl Bal: RM1,234.50. Ref 12345"
private let factoryReceivedAt = Date(timeIntervalSince1970: 1_795_000_000)
private let factoryPattern = #"RM(?<amount>[0-9,]+(?:\.[0-9]{2})?) spent at (?<merchant>.+?) on (?<date>\d{2}/\d{2}/\d{2})"#

private func factoryRule() -> ParsingRuleSpec {
    ParsingRuleSpec(direction: .debit, pattern: factoryPattern)
}

private func factoryInput(_ text: String = factoryText) -> ParseInput {
    ParseInput(text: text, sender: "MYBANK", receivedAt: factoryReceivedAt)
}

private func modelOutput(amount: String) -> ModelTransactionOutput {
    ModelTransactionOutput(isTransaction: true, direction: "debit", amount: amount, merchant: "Model Merchant")
}

private func draft(from result: ParseResult) -> TransactionDraft? {
    if case .transaction(let draft) = result { return draft }
    return nil
}

private func firstDiagnostic(from result: ParseResult) -> ParseDiagnostic? {
    if case .failure(let diagnostics) = result { return diagnostics.first }
    return nil
}

@Test func factoryRulesModeReturnsTheRegexEngine() async {
    let factory = ParserFactory(modelClient: StubModelClient(result: .success(modelOutput(amount: "99.00"))))
    let parser = factory.makeParser(for: .rules, rules: [factoryRule()])

    #expect(parser is RegexParsingEngine)
    guard let parsed = draft(from: await parser.parse(factoryInput())) else {
        Issue.record("expected a transaction")
        return
    }
    #expect(parsed.amount == Decimal(12.5))
    #expect(parsed.merchant == "KFC")
}

@Test func factoryRulesModeNeverConsultsTheModel() async {
    let counter = CallCounter()
    let client = StubModelClient(result: .success(modelOutput(amount: "99.00")), counter: counter)
    let parser = ParserFactory(modelClient: client).makeParser(for: .rules, rules: [factoryRule()])

    _ = await parser.parse(factoryInput())

    #expect(await counter.parseCalls == 0)
}

@Test func factoryFoundationModelsModeReturnsTheModelEngine() async {
    let factory = ParserFactory(modelClient: StubModelClient(result: .success(modelOutput(amount: "99.00"))))
    let parser = factory.makeParser(for: .foundationModels, rules: [factoryRule()])

    #expect(parser is FoundationModelsParsingEngine)
    guard let parsed = draft(from: await parser.parse(factoryInput())) else {
        Issue.record("expected a transaction")
        return
    }
    #expect(parsed.amount == Decimal(99))
    #expect(parsed.merchant == "Model Merchant")
}

@Test func factoryFoundationModelsModeReportsAnUnavailableModel() async {
    let client = StubModelClient(
        availabilityValue: .unavailable("Apple Intelligence is turned off in Settings."),
        result: .success(modelOutput(amount: "99.00"))
    )
    let parser = ParserFactory(modelClient: client).makeParser(for: .foundationModels, rules: [])

    let diagnostic = firstDiagnostic(from: await parser.parse(factoryInput()))
    #expect(diagnostic?.code == .modelUnavailable)
    #expect(diagnostic?.message.contains("Apple Intelligence") == true)
}

@Test func factoryHybridModeReturnsTheHybridEngine() async {
    let factory = ParserFactory(modelClient: StubModelClient(result: .success(modelOutput(amount: "99.00"))))
    let parser = factory.makeParser(for: .hybrid, rules: [factoryRule()])

    #expect(parser is HybridParsingEngine)
    guard let parsed = draft(from: await parser.parse(factoryInput())) else {
        Issue.record("expected a transaction")
        return
    }
    #expect(parsed.amount == Decimal(12.5))
}

@Test func factoryHybridModePrefersRules() async {
    let counter = CallCounter()
    let client = StubModelClient(result: .success(modelOutput(amount: "99.00")), counter: counter)
    let parser = ParserFactory(modelClient: client).makeParser(for: .hybrid, rules: [factoryRule()])

    _ = await parser.parse(factoryInput())

    #expect(await counter.parseCalls == 0)
}

@Test func factoryHybridModeFallsBackToTheModel() async {
    let counter = CallCounter()
    let client = StubModelClient(result: .success(modelOutput(amount: "99.00")), counter: counter)
    let parser = ParserFactory(modelClient: client).makeParser(for: .hybrid, rules: [factoryRule()])

    guard let parsed = draft(from: await parser.parse(factoryInput("Your one-time password is 123456."))) else {
        Issue.record("expected a transaction")
        return
    }
    #expect(parsed.amount == Decimal(99))
    #expect(await counter.parseCalls == 1)
}
