import Foundation
import Testing
@testable import ZentriCore

/// 2026-11-18 11:06:40 UTC, so every draft date below is in the past.
private let hybridReceivedAt = Date(timeIntervalSince1970: 1_795_000_000)

private func hybridInput() -> ParseInput {
    ParseInput(text: "MYBANK: RM12.50 spent at KFC", sender: "MYBANK", receivedAt: hybridReceivedAt)
}

private func hybridDraft(_ amount: Decimal, matchedRuleID: UUID? = nil) -> TransactionDraft {
    TransactionDraft(
        direction: .debit,
        amount: amount,
        merchant: "KFC",
        occurredAt: hybridReceivedAt,
        matchedRuleID: matchedRuleID
    )
}

private func hybridDiagnostic(_ code: ParseDiagnostic.Code, field: String = "amount") -> ParseDiagnostic {
    ParseDiagnostic(code: code, field: field, message: "test diagnostic for \(field)")
}

/// A scripted parser standing in for either engine the hybrid wraps.
private struct StubParser: TransactionParsing {
    var result: ParseResult
    var counter: CallCounter?

    func parse(_ input: ParseInput) async -> ParseResult {
        await counter?.recordParse()
        return result
    }
}

@Test func rulesTransactionWinsInHybrid() async {
    let ruleID = UUID()
    let counter = CallCounter()
    let engine = HybridParsingEngine(
        rules: StubParser(result: .transaction(hybridDraft(12.50, matchedRuleID: ruleID))),
        model: StubParser(result: .transaction(hybridDraft(99)), counter: counter)
    )

    let result = await engine.parse(hybridInput())

    #expect(result == .transaction(hybridDraft(12.50, matchedRuleID: ruleID)))
    #expect(await counter.parseCalls == 0)
}

@Test func hybridFallsBackToTheModelWhenRulesFail() async {
    let engine = HybridParsingEngine(
        rules: StubParser(result: .failure([hybridDiagnostic(.invalidAmount)])),
        model: StubParser(result: .transaction(hybridDraft(99)))
    )

    #expect(await engine.parse(hybridInput()) == .transaction(hybridDraft(99)))
}

@Test func hybridFallsBackToTheModelWhenRulesFindNoTransaction() async {
    let engine = HybridParsingEngine(
        rules: StubParser(result: .notTransaction),
        model: StubParser(result: .transaction(hybridDraft(99)))
    )

    #expect(await engine.parse(hybridInput()) == .transaction(hybridDraft(99)))
}

@Test func hybridReportsNotATransactionWhenBothEnginesAgree() async {
    let engine = HybridParsingEngine(
        rules: StubParser(result: .notTransaction),
        model: StubParser(result: .notTransaction)
    )

    #expect(await engine.parse(hybridInput()) == .notTransaction)
}

/// A positive answer from the model that the message is not a transaction is enough, even when a
/// rule matched and failed validation.
@Test func hybridReportsNotATransactionWhenTheModelSaysSoAfterARuleFailed() async {
    let rulesFailModelNone = HybridParsingEngine(
        rules: StubParser(result: .failure([hybridDiagnostic(.invalidAmount)])),
        model: StubParser(result: .notTransaction)
    )

    #expect(await rulesFailModelNone.parse(hybridInput()) == .notTransaction)
}

/// "No rule matched" is not evidence that the message is not a transaction, so a model that could
/// not answer leaves the message failed — retryable — rather than ignored.
@Test func hybridReportsTheModelsFailureWhenNoRuleMatched() async {
    for code in [ParseDiagnostic.Code.modelTimedOut, .modelFailed, .cancelled, .invalidAmount] {
        let modelDiagnostic = hybridDiagnostic(code, field: "model")
        let engine = HybridParsingEngine(
            rules: StubParser(result: .notTransaction),
            model: StubParser(result: .failure([modelDiagnostic]))
        )

        #expect(await engine.parse(hybridInput()) == .failure([modelDiagnostic]), "\(code)")
    }
}

/// With the model unavailable hybrid falls back to the rules (spec §10.3, §18), so the rules'
/// "not a transaction" stands.
@Test func hybridFallsBackToTheRulesWhenTheModelIsUnavailable() async {
    let engine = HybridParsingEngine(
        rules: StubParser(result: .notTransaction),
        model: StubParser(result: .failure([hybridDiagnostic(.modelUnavailable, field: "model")]))
    )

    #expect(await engine.parse(hybridInput()) == .notTransaction)
}

@Test func hybridCombinesFailuresWhenNeitherEngineFindsATransaction() async {
    let rulesDiagnostic = hybridDiagnostic(.invalidAmount)
    let modelDiagnostic = hybridDiagnostic(.modelFailed, field: "model")
    let engine = HybridParsingEngine(
        rules: StubParser(result: .failure([rulesDiagnostic])),
        model: StubParser(result: .failure([modelDiagnostic]))
    )

    #expect(await engine.parse(hybridInput()) == .failure([rulesDiagnostic, modelDiagnostic]))
}

@Test func hybridReportsADiagnosticBothEnginesShareOnlyOnce() async {
    let shared = ParseDiagnostic(
        code: .inputTooLong,
        field: "text",
        message: "The message is longer than 20000 characters and was not parsed."
    )
    let engine = HybridParsingEngine(
        rules: StubParser(result: .failure([shared])),
        model: StubParser(result: .failure([shared]))
    )

    #expect(await engine.parse(hybridInput()) == .failure([shared]))
}
