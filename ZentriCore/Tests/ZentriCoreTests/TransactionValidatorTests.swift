import Foundation
import Testing
@testable import ZentriCore

private let validationReceivedAt = Date(timeIntervalSince1970: 1_795_000_000)

private func makeDraft(
    amount: Decimal = Decimal(string: "12.50") ?? 0,
    merchant: String = "KFC",
    balanceAfter: Decimal? = nil,
    occurredAt: Date? = nil,
    reference: String? = nil
) -> TransactionDraft {
    TransactionDraft(
        direction: .debit,
        amount: amount,
        merchant: merchant,
        balanceAfter: balanceAfter,
        occurredAt: occurredAt,
        reference: reference
    )
}

@Test func acceptsValidDraft() {
    let occurredAt = validationReceivedAt.addingTimeInterval(-3_600)
    let result = TransactionValidator.validate(
        makeDraft(balanceAfter: Decimal(string: "1234.50"), occurredAt: occurredAt),
        receivedAt: validationReceivedAt
    )
    guard case .success(let draft) = result else {
        Issue.record("expected a valid draft")
        return
    }
    #expect(draft.amount == Decimal(string: "12.50"))
    #expect(draft.merchant == "KFC")
    #expect(draft.balanceAfter == Decimal(string: "1234.50"))
    #expect(draft.occurredAt == occurredAt)
}

@Test func missingOccurredAtUsesReceivedAt() {
    let result = TransactionValidator.validate(makeDraft(), receivedAt: validationReceivedAt)
    guard case .success(let draft) = result else {
        Issue.record("expected a valid draft")
        return
    }
    #expect(draft.occurredAt == validationReceivedAt)
}

@Test func rejectsNonPositiveAmounts() {
    for amount in [Decimal.zero, Decimal(string: "-1.00") ?? 0, Decimal.nan] {
        let result = TransactionValidator.validate(makeDraft(amount: amount), receivedAt: validationReceivedAt)
        guard case .failure(let failure) = result else {
            Issue.record("expected a failure for amount \(amount)")
            continue
        }
        #expect(failure.diagnostics.contains { $0.code == .amountNotPositive })
        #expect(failure.diagnostics.contains { $0.field == "amount" })
    }
}

@Test func rejectsDateMoreThan24HoursInFuture() {
    let farFuture = validationReceivedAt.addingTimeInterval(24 * 60 * 60 + 1)
    let result = TransactionValidator.validate(
        makeDraft(occurredAt: farFuture),
        receivedAt: validationReceivedAt
    )
    guard case .failure(let failure) = result else {
        Issue.record("expected a failure")
        return
    }
    #expect(failure.diagnostics.contains { $0.code == .dateTooFarInFuture })
    #expect(failure.diagnostics.contains { $0.field == "date" })
}

@Test func acceptsDateExactly24HoursInFuture() {
    let limit = validationReceivedAt.addingTimeInterval(24 * 60 * 60)
    let result = TransactionValidator.validate(
        makeDraft(occurredAt: limit),
        receivedAt: validationReceivedAt
    )
    guard case .success = result else {
        Issue.record("a date exactly 24 hours ahead is allowed")
        return
    }
}

@Test func allowsOlderDates() {
    let old = validationReceivedAt.addingTimeInterval(-90 * 24 * 60 * 60)
    let result = TransactionValidator.validate(makeDraft(occurredAt: old), receivedAt: validationReceivedAt)
    guard case .success(let draft) = result else {
        Issue.record("older dates are allowed")
        return
    }
    #expect(draft.occurredAt == old)
}

@Test func rejectsBlankMerchant() {
    let result = TransactionValidator.validate(makeDraft(merchant: " \n\t "), receivedAt: validationReceivedAt)
    guard case .failure(let failure) = result else {
        Issue.record("expected a failure")
        return
    }
    #expect(failure.diagnostics.contains { $0.code == .missingMerchant })
    #expect(failure.diagnostics.contains { $0.field == "merchant" })
}

@Test func collapsesMerchantWhitespace() {
    let result = TransactionValidator.validate(
        makeDraft(merchant: "  KFC \n  Malaysia\tSdn  Bhd "),
        receivedAt: validationReceivedAt
    )
    guard case .success(let draft) = result else {
        Issue.record("expected a valid draft")
        return
    }
    #expect(draft.merchant == "KFC Malaysia Sdn Bhd")
}

@Test func reportsEveryFailureAtOnce() {
    let result = TransactionValidator.validate(
        makeDraft(
            amount: Decimal.zero,
            merchant: "",
            occurredAt: validationReceivedAt.addingTimeInterval(48 * 60 * 60)
        ),
        receivedAt: validationReceivedAt
    )
    guard case .failure(let failure) = result else {
        Issue.record("expected a failure")
        return
    }
    #expect(failure.diagnostics.map(\.code) == [.amountNotPositive, .dateTooFarInFuture, .missingMerchant])
    #expect(failure.diagnostics.allSatisfy { $0.ruleID == nil })
    #expect(failure.diagnostics.allSatisfy { !$0.message.isEmpty })
}
