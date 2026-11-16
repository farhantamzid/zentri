import Foundation
import Testing
@testable import ZentriCore

// Bangladeshi bank messages state amounts as "TK 77,941.71". The account and wallet numbers in
// these samples are made up.

private let receivedAt = Date(timeIntervalSince1970: 1_795_000_000)

private let cardMessage = "TK 2,500.00 transacted at PATHAOPAY DHAKA BD on 15-11-26 @08:55 AM using card#***1234. Balance TK 77,941.71. Query: 16221"
private let creditMessage = "TK 19,000.00 credited to A/C#10000**0001 on 14-11-26 @12:24 AM from OTHER BANK. Balance TK 80,491.71. BRAC Bank."
private let transferMessage = "Tk 3,000.00 has been transferred from your BBL A/C: 1**0001 to BKASH wallet: 01700000000. Available balance is Tk 61,491.71. Queries: call 16221"

private func modelDraft(_ text: String, amount: String, balance: String?) async -> TransactionDraft? {
    let output = ModelTransactionOutput(isTransaction: true, direction: "debit", amount: amount, merchant: "PATHAOPAY", balance: balance)
    let engine = FoundationModelsParsingEngine(client: StubModelClient(result: .success(output)))
    if case .transaction(let draft) = await engine.parse(ParseInput(text: text, sender: "BRAC-BANK", receivedAt: receivedAt)) {
        return draft
    }
    return nil
}

@Test func aBalanceTheModelWroteWithoutSeparatorsIsReadAsTheMessageStatesIt() async throws {
    let draft = try #require(await modelDraft(cardMessage, amount: "2,500.00", balance: "7794171"))
    #expect(draft.balanceAfter == Decimal(string: "77941.71"))
}

@Test func aBalanceWithSwappedSeparatorsIsReadAsTheMessageStatesIt() async throws {
    let draft = try #require(await modelDraft(cardMessage, amount: "2500.00", balance: "77.941,71"))
    #expect(draft.amount == 2_500)
    #expect(draft.balanceAfter == Decimal(string: "77941.71"))
}

@Test func aBalanceRegroupedByTheModelIsReadAsTheMessageStatesIt() async throws {
    let draft = try #require(await modelDraft(cardMessage, amount: "2,500.00", balance: "7,794,171"))
    #expect(draft.balanceAfter == Decimal(string: "77941.71"))
}

@Test func aBalanceTheMessageDoesNotStateIsDropped() async throws {
    let draft = try #require(await modelDraft(cardMessage, amount: "2,500.00", balance: "99,999.00"))
    #expect(draft.balanceAfter == nil)
}

@Test func anAmountTheModelWroteWithoutSeparatorsIsStillAccepted() async throws {
    let draft = try #require(await modelDraft(cardMessage, amount: "250000", balance: "77,941.71"))
    #expect(draft.amount == 2_500)
}

// MARK: - Rules for BRAC Bank's message formats

private let bracRules = [
    ParsingRuleSpec(
        direction: .debit,
        pattern: #"TK (?<amount>[\d,]+\.\d{2}) transacted at (?<merchant>.+?) on (?<date>\d{2}-\d{2}-\d{2}) @(?<time>\d{1,2}:\d{2} [AP]M).*?Balance TK (?<balance>[\d,]+\.\d{2})"#,
        dateFormat: "dd-MM-yy hh:mm a"
    ),
    ParsingRuleSpec(
        direction: .credit,
        pattern: #"TK (?<amount>[\d,]+\.\d{2}) credited to .+? on (?<date>\d{2}-\d{2}-\d{2}) @(?<time>\d{1,2}:\d{2} [AP]M) from (?<merchant>.+?)\. Balance TK (?<balance>[\d,]+\.\d{2})"#,
        dateFormat: "dd-MM-yy hh:mm a"
    ),
    ParsingRuleSpec(
        direction: .debit,
        pattern: #"TK (?<amount>[\d,]+\.\d{2}) has been transferred from .+? to (?<merchant>.+?): \S+\. Available balance is TK (?<balance>[\d,]+\.\d{2})"#
    ),
]

private func ruleDraft(_ text: String) async -> TransactionDraft? {
    let engine = RegexParsingEngine(rules: bracRules, timeZone: TimeZone(identifier: "Asia/Dhaka")!)
    if case .transaction(let draft) = await engine.parse(ParseInput(text: text, sender: "BRAC-BANK", receivedAt: receivedAt)) {
        return draft
    }
    return nil
}

@Test func theCardRuleReadsACardPayment() async throws {
    let draft = try #require(await ruleDraft(cardMessage))
    #expect(draft.direction == .debit)
    #expect(draft.amount == 2_500)
    #expect(draft.merchant == "PATHAOPAY DHAKA BD")
    #expect(draft.balanceAfter == Decimal(string: "77941.71"))
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Dhaka")!
    let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: try #require(draft.occurredAt))
    #expect(parts == DateComponents(year: 2026, month: 11, day: 15, hour: 8, minute: 55))
}

@Test func theCreditRuleReadsMoneyArriving() async throws {
    let draft = try #require(await ruleDraft(creditMessage))
    #expect(draft.direction == .credit)
    #expect(draft.amount == 19_000)
    #expect(draft.merchant == "OTHER BANK")
    #expect(draft.balanceAfter == Decimal(string: "80491.71"))
}

@Test func theTransferRuleReadsAWalletTopUp() async throws {
    let draft = try #require(await ruleDraft(transferMessage))
    #expect(draft.direction == .debit)
    #expect(draft.amount == 3_000)
    #expect(draft.merchant == "BKASH wallet")
    #expect(draft.balanceAfter == Decimal(string: "61491.71"))
}
