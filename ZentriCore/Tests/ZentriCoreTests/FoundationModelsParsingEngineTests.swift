import Foundation
import Testing
@testable import ZentriCore

/// 2026-11-18 11:06:40 UTC, late enough that every date in these tests is in the past.
private let modelReceivedAt = Date(timeIntervalSince1970: 1_795_000_000)

private func utcDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
    return calendar.date(from: components) ?? .distantPast
}

/// The zone message dates are read in for these tests: UTC+8 all year, neither GMT nor a zone
/// a test machine is likely to run in, so a test cannot pass by reading dates in either.
private let testZone = TimeZone(identifier: "Asia/Kuala_Lumpur") ?? .gmt

/// A wall-clock time in ``testZone``.
private func localDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = testZone
    let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
    return calendar.date(from: components) ?? .distantPast
}

/// The model engine reading zone-less dates in ``testZone``.
private func modelEngine(client: any TransactionModelClient) -> FoundationModelsParsingEngine {
    FoundationModelsParsingEngine(client: client, timeZone: testZone)
}

private func modelInput(_ text: String = "MYBANK: RM12.50 spent at KFC") -> ParseInput {
    ParseInput(text: text, sender: "MYBANK", receivedAt: modelReceivedAt)
}

private func draft(from result: ParseResult) -> TransactionDraft? {
    if case .transaction(let draft) = result { return draft }
    return nil
}

private func firstDiagnostic(from result: ParseResult) -> ParseDiagnostic? {
    if case .failure(let diagnostics) = result { return diagnostics.first }
    return nil
}

/// Counts how often a stub client or parser was asked to parse.
///
/// Shared by the Foundation Models, hybrid, and factory tests so a test can prove an engine
/// was not consulted.
actor CallCounter {
    private(set) var parseCalls = 0

    func recordParse() {
        parseCalls += 1
    }
}

/// A scripted model client, so the engine can be tested without the on-device model.
struct StubModelClient: TransactionModelClient {
    var availabilityValue: ModelAvailability = .available
    var result: Result<ModelTransactionOutput, any Error & Sendable>
    var counter: CallCounter?

    func availability() async -> ModelAvailability {
        availabilityValue
    }

    func parse(text: String) async throws -> ModelTransactionOutput {
        await counter?.recordParse()
        return try result.get()
    }
}

/// A failure the model client does not define, standing in for a generation error.
enum ModelTestFailure: Error, Sendable, Equatable {
    case generationFailed
}

@Test func mapsValidModelOutput() async {
    let output = ModelTransactionOutput(
        isTransaction: true, direction: "debit", amount: "12.50",
        merchant: "KFC", balance: "1,234.50", date: nil, category: "Dining"
    )
    let engine = modelEngine(client: StubModelClient(result: .success(output)))
    let result = await engine.parse(modelInput("Paid 12.50 at KFC"))
    guard case .transaction(let draft) = result else { Issue.record("expected transaction"); return }
    #expect(draft.amount == Decimal(string: "12.50"))
    #expect(draft.categorySuggestion == "Dining")
}

@Test func mapsEveryValidatedField() async {
    let output = ModelTransactionOutput(
        isTransaction: true, direction: "credit", amount: "RM 1,234.50",
        merchant: "  ACME   Corp ", balance: "5,000.00",
        date: "2026-11-14T09:30:00Z", category: "  Salary "
    )
    let engine = modelEngine(client: StubModelClient(result: .success(output)))

    guard let draft = draft(from: await engine.parse(modelInput("MYBANK: RM1,234.50 received from ACME Corp. Bal RM5,000.00"))) else {
        Issue.record("expected a transaction")
        return
    }
    #expect(draft.direction == .credit)
    #expect(draft.amount == Decimal(1234.5))
    #expect(draft.balanceAfter == Decimal(5000))
    #expect(draft.merchant == "ACME Corp")
    #expect(draft.categorySuggestion == "Salary")
    #expect(draft.occurredAt == utcDate(2026, 11, 14, hour: 9, minute: 30))
    #expect(draft.reference == nil)
    #expect(draft.matchedRuleID == nil)
}

@Test func parsesAnISO8601DateWithoutTime() async {
    let output = ModelTransactionOutput(
        isTransaction: true, direction: "debit", amount: "12.50", merchant: "KFC", date: "2026-11-14"
    )
    let engine = modelEngine(client: StubModelClient(result: .success(output)))

    guard let draft = draft(from: await engine.parse(modelInput())) else {
        Issue.record("expected a transaction")
        return
    }
    #expect(draft.occurredAt == localDate(2026, 11, 14))
}

@Test func parsesAnISO8601TimestampWithoutAZone() async {
    let output = ModelTransactionOutput(
        isTransaction: true, direction: "debit", amount: "12.50", merchant: "KFC",
        date: "2026-11-14T09:30:00"
    )
    let engine = modelEngine(client: StubModelClient(result: .success(output)))

    guard let draft = draft(from: await engine.parse(modelInput())) else {
        Issue.record("expected a transaction")
        return
    }
    #expect(draft.occurredAt == localDate(2026, 11, 14, hour: 9, minute: 30))
}

@Test func parsesAnISO8601TimestampWithAColonOffset() async {
    // 09:30 at +08:00 is 01:30 UTC, so the offset must be applied rather than ignored.
    let output = ModelTransactionOutput(
        isTransaction: true, direction: "debit", amount: "12.50", merchant: "KFC",
        date: "2026-11-14T09:30:00+08:00"
    )
    let engine = modelEngine(client: StubModelClient(result: .success(output)))

    guard let draft = draft(from: await engine.parse(modelInput())) else {
        Issue.record("expected a transaction")
        return
    }
    #expect(draft.occurredAt == utcDate(2026, 11, 14, hour: 1, minute: 30))
}

@Test func parsesAnISO8601TimestampWithABasicOffset() async {
    // ISO-8601 also spells the same offset without a colon; it must not fall back to `receivedAt`.
    let output = ModelTransactionOutput(
        isTransaction: true, direction: "debit", amount: "12.50", merchant: "KFC",
        date: "2026-11-14T09:30:00+0800"
    )
    let engine = modelEngine(client: StubModelClient(result: .success(output)))

    guard let draft = draft(from: await engine.parse(modelInput())) else {
        Issue.record("expected a transaction")
        return
    }
    #expect(draft.occurredAt == utcDate(2026, 11, 14, hour: 1, minute: 30))
    #expect(draft.occurredAt != modelReceivedAt)
}

@Test func unreadableModelDatesFallBackToTheReceiptTime() async {
    for date in ["last Tuesday", "2026-13-45", ""] {
        let output = ModelTransactionOutput(
            isTransaction: true, direction: "debit", amount: "12.50", merchant: "KFC", date: date
        )
        let engine = modelEngine(client: StubModelClient(result: .success(output)))

        guard let draft = draft(from: await engine.parse(modelInput())) else {
            Issue.record("expected a transaction for '\(date)'")
            continue
        }
        #expect(draft.occurredAt == modelReceivedAt, "date '\(date)'")
    }
}

@Test func outOfWindowModelDatesFallBackToTheReceiptTime() async {
    for date in ["1999-11-14", "0032-11-14", "2100-01-01"] {
        let output = ModelTransactionOutput(
            isTransaction: true, direction: "debit", amount: "12.50", merchant: "KFC", date: date
        )
        let engine = modelEngine(client: StubModelClient(result: .success(output)))

        guard let draft = draft(from: await engine.parse(modelInput())) else {
            Issue.record("expected a transaction for '\(date)'")
            continue
        }
        #expect(draft.occurredAt == modelReceivedAt, "date '\(date)'")
    }
}

@Test func nonTransactionModelOutputIsNotATransaction() async {
    let output = ModelTransactionOutput(
        isTransaction: false, direction: "debit", amount: "12.50", merchant: "KFC",
        balance: "1,234.50", date: "2026-11-14", category: "Dining"
    )
    let engine = modelEngine(client: StubModelClient(result: .success(output)))

    #expect(await engine.parse(modelInput()) == .notTransaction)
}

@Test func missingModelAmountIsAFailure() async {
    let output = ModelTransactionOutput(isTransaction: true, direction: "debit", merchant: "KFC")
    let engine = modelEngine(client: StubModelClient(result: .success(output)))

    let diagnostic = firstDiagnostic(from: await engine.parse(modelInput()))
    #expect(diagnostic?.code == .missingField)
    #expect(diagnostic?.field == "amount")
}

@Test func invalidModelAmountIsAFailure() async {
    let output = ModelTransactionOutput(isTransaction: true, direction: "debit", amount: "12.5O", merchant: "KFC")
    let engine = modelEngine(client: StubModelClient(result: .success(output)))

    let diagnostic = firstDiagnostic(from: await engine.parse(modelInput()))
    #expect(diagnostic?.code == .invalidAmount)
    #expect(diagnostic?.field == "amount")
}

@Test func hallucinatedModelAmountIsNotAccepted() async {
    let output = ModelTransactionOutput(isTransaction: true, direction: "debit", amount: "999.99", merchant: "KFC")
    let engine = modelEngine(client: StubModelClient(result: .success(output)))

    let diagnostic = firstDiagnostic(from: await engine.parse(modelInput("Paid 12.50 at KFC")))
    #expect(diagnostic?.code == .invalidAmount)
    #expect(diagnostic?.field == "amount")
    #expect(diagnostic?.message == "The extracted amount does not appear in the message.")
}

@Test func modelAmountThatMatchesTheMessageIsAccepted() async {
    let output = ModelTransactionOutput(isTransaction: true, direction: "debit", amount: "12.50", merchant: "KFC")
    let engine = modelEngine(client: StubModelClient(result: .success(output)))

    guard let draft = draft(from: await engine.parse(modelInput("Paid 12.50 at KFC"))) else {
        Issue.record("expected a transaction")
        return
    }
    #expect(draft.amount == Decimal(string: "12.50"))
}

@Test func modelAmountMatchesAGroupedMessageAmount() async {
    let output = ModelTransactionOutput(isTransaction: true, direction: "debit", amount: "1234.50", merchant: "KFC")
    let engine = modelEngine(client: StubModelClient(result: .success(output)))

    guard let draft = draft(from: await engine.parse(modelInput("Paid RM 1,234.50"))) else {
        Issue.record("expected a transaction")
        return
    }
    #expect(draft.amount == Decimal(1234.5))
}

@Test func modelAmountWithoutAFractionMatchesAGroupedMessageAmount() async {
    let output = ModelTransactionOutput(isTransaction: true, direction: "debit", amount: "1250", merchant: "KFC")
    let engine = modelEngine(client: StubModelClient(result: .success(output)))

    guard let draft = draft(from: await engine.parse(modelInput("Paid 1,250"))) else {
        Issue.record("expected a transaction")
        return
    }
    #expect(draft.amount == Decimal(1250))
}

@Test func modelAmountIsComparedByValueNotByDigits() async {
    // "1,000" contains the digits of "100", but not its value.
    let output = ModelTransactionOutput(isTransaction: true, direction: "debit", amount: "100", merchant: "KFC")
    let engine = modelEngine(client: StubModelClient(result: .success(output)))

    let diagnostic = firstDiagnostic(from: await engine.parse(modelInput("Paid 1,000 at KFC")))
    #expect(diagnostic?.code == .invalidAmount)
}

@Test func nonPositiveModelAmountFailsValidation() async {
    let output = ModelTransactionOutput(isTransaction: true, direction: "debit", amount: "0.00", merchant: "KFC")
    let engine = modelEngine(client: StubModelClient(result: .success(output)))

    let diagnostic = firstDiagnostic(from: await engine.parse(modelInput("MYBANK: RM0.00 charge at KFC")))
    #expect(diagnostic?.code == .amountNotPositive)
    #expect(diagnostic?.field == "amount")
}

@Test func missingModelDirectionIsAFailure() async {
    let output = ModelTransactionOutput(isTransaction: true, amount: "12.50", merchant: "KFC")
    let engine = modelEngine(client: StubModelClient(result: .success(output)))

    let diagnostic = firstDiagnostic(from: await engine.parse(modelInput()))
    #expect(diagnostic?.code == .missingField)
    #expect(diagnostic?.field == "direction")
}

@Test func unknownModelDirectionIsAFailure() async {
    let output = ModelTransactionOutput(isTransaction: true, direction: "transfer", amount: "12.50", merchant: "KFC")
    let engine = modelEngine(client: StubModelClient(result: .success(output)))

    let diagnostic = firstDiagnostic(from: await engine.parse(modelInput()))
    #expect(diagnostic?.code == .missingField)
    #expect(diagnostic?.field == "direction")
}

@Test func blankModelMerchantFailsValidation() async {
    let output = ModelTransactionOutput(isTransaction: true, direction: "debit", amount: "12.50", merchant: "   ")
    let engine = modelEngine(client: StubModelClient(result: .success(output)))

    let diagnostic = firstDiagnostic(from: await engine.parse(modelInput()))
    #expect(diagnostic?.code == .missingMerchant)
    #expect(diagnostic?.field == "merchant")
}

@Test func overlongModelMerchantIsTruncated() async {
    let merchant = String(repeating: "M", count: 500)
    let output = ModelTransactionOutput(
        isTransaction: true, direction: "debit", amount: "12.50", merchant: merchant
    )
    let engine = modelEngine(client: StubModelClient(result: .success(output)))

    guard let draft = draft(from: await engine.parse(modelInput())) else {
        Issue.record("expected a transaction")
        return
    }
    #expect(draft.merchant.count == 120)
    #expect(draft.merchant == String(merchant.prefix(120)))
}

@Test func unreadableModelBalanceIsDropped() async {
    let output = ModelTransactionOutput(
        isTransaction: true, direction: "debit", amount: "12.50", merchant: "KFC", balance: "not a number"
    )
    let engine = modelEngine(client: StubModelClient(result: .success(output)))

    guard let draft = draft(from: await engine.parse(modelInput())) else {
        Issue.record("expected a transaction")
        return
    }
    #expect(draft.balanceAfter == nil)
    #expect(draft.amount == Decimal(12.5))
}

@Test func unavailableModelFailsWithoutParsing() async {
    let counter = CallCounter()
    let output = ModelTransactionOutput(isTransaction: true, direction: "debit", amount: "12.50", merchant: "KFC")
    let client = StubModelClient(
        availabilityValue: .unavailable("Apple Intelligence is turned off in Settings."),
        result: .success(output),
        counter: counter
    )
    let engine = modelEngine(client: client)

    let diagnostics: [ParseDiagnostic]
    if case .failure(let failures) = await engine.parse(modelInput()) {
        diagnostics = failures
    } else {
        Issue.record("expected a failure")
        return
    }
    #expect(diagnostics.map(\.code) == [.modelUnavailable])
    #expect(diagnostics.first?.message.contains("Apple Intelligence") == true)
    #expect(await counter.parseCalls == 0)
}

@Test func unavailableModelWithoutAReasonStillExplainsItself() async {
    let output = ModelTransactionOutput(isTransaction: true, direction: "debit", amount: "12.50", merchant: "KFC")
    let engine = modelEngine(
        client: StubModelClient(availabilityValue: .unavailable(""), result: .success(output))
    )

    let diagnostic = firstDiagnostic(from: await engine.parse(modelInput()))
    #expect(diagnostic?.code == .modelUnavailable)
    #expect(diagnostic?.message.isEmpty == false)
}

@Test func modelDateMoreThanADayAheadFailsValidation() async {
    // `modelReceivedAt` is 2026-11-18 11:06:40 UTC, so this date is 47 hours ahead.
    let output = ModelTransactionOutput(
        isTransaction: true, direction: "debit", amount: "12.50", merchant: "KFC",
        date: "2026-11-20T11:00:00Z"
    )
    let engine = modelEngine(client: StubModelClient(result: .success(output)))

    let diagnostic = firstDiagnostic(from: await engine.parse(modelInput()))
    #expect(diagnostic?.code == .dateTooFarInFuture)
    #expect(diagnostic?.field == "date")
}

@Test func thrownModelErrorIsAFailure() async {
    let client = StubModelClient(result: .failure(ModelTestFailure.generationFailed))
    let engine = modelEngine(client: client)

    let diagnostic = firstDiagnostic(from: await engine.parse(modelInput()))
    #expect(diagnostic?.code == .modelFailed)
    #expect(diagnostic?.message.isEmpty == false)
}

@Test func modelTimeoutIsAFailure() async {
    let client = StubModelClient(result: .failure(ModelClientError.timedOut))
    let engine = modelEngine(client: client)

    let diagnostic = firstDiagnostic(from: await engine.parse(modelInput()))
    #expect(diagnostic?.code == .modelTimedOut)
}

@Test func modelCancellationIsAFailure() async {
    let client = StubModelClient(result: .failure(CancellationError()))
    let engine = modelEngine(client: client)

    let diagnostic = firstDiagnostic(from: await engine.parse(modelInput()))
    #expect(diagnostic?.code == .cancelled)
    #expect(diagnostic?.message == "Parsing was cancelled.")
}

@Test func cancelledParsingFailsWithoutAskingTheModel() async {
    let counter = CallCounter()
    let output = ModelTransactionOutput(isTransaction: true, direction: "debit", amount: "12.50", merchant: "KFC")
    let engine = modelEngine(
        client: StubModelClient(result: .success(output), counter: counter)
    )

    let task = Task { () -> ParseResult in
        withUnsafeCurrentTask { $0?.cancel() }
        return await engine.parse(modelInput())
    }
    let result = await task.value

    guard case .failure(let diagnostics) = result else {
        Issue.record("expected a failure")
        return
    }
    #expect(diagnostics.map(\.code) == [.cancelled])
    #expect(await counter.parseCalls == 0)
}

@Test func oversizedModelMessageFailsWithoutParsing() async {
    let counter = CallCounter()
    let output = ModelTransactionOutput(isTransaction: true, direction: "debit", amount: "12.50", merchant: "KFC")
    let client = StubModelClient(result: .success(output), counter: counter)
    let engine = modelEngine(client: client)

    let diagnostic = firstDiagnostic(from: await engine.parse(modelInput(String(repeating: "a", count: 20_001))))
    #expect(diagnostic?.code == .inputTooLong)
    #expect(await counter.parseCalls == 0)
}
