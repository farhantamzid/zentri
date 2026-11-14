import Foundation
import Testing
@testable import ZentriCore

private let sampleText = "MYBANK: RM12.50 spent at KFC on 14/11/26. Avl Bal: RM1,234.50. Ref 12345"
private let sampleReceivedAt = Date(timeIntervalSince1970: 1_795_000_000)
private let debitPattern = #"RM(?<amount>[0-9,]+(?:\.[0-9]{2})?) spent at (?<merchant>.+?) on (?<date>\d{2}/\d{2}/\d{2})\. Avl Bal: RM(?<balance>[0-9,]+(?:\.[0-9]{2})?)"#

private func rule(
    id: UUID = UUID(),
    accountID: UUID? = nil,
    direction: Direction = .debit,
    pattern: String = debitPattern,
    dateFormat: String? = "dd/MM/yy",
    isCaseInsensitive: Bool = true,
    dotMatchesNewlines: Bool = false,
    priority: Int = 0,
    isEnabled: Bool = true
) -> ParsingRuleSpec {
    ParsingRuleSpec(
        id: id,
        accountID: accountID,
        direction: direction,
        pattern: pattern,
        dateFormat: dateFormat,
        isCaseInsensitive: isCaseInsensitive,
        dotMatchesNewlines: dotMatchesNewlines,
        priority: priority,
        isEnabled: isEnabled
    )
}

private func input(
    _ text: String = sampleText,
    accountID: UUID? = nil,
    receivedAt: Date = sampleReceivedAt
) -> ParseInput {
    ParseInput(text: text, accountID: accountID, sender: "MYBANK", receivedAt: receivedAt)
}

private func utcDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
    return calendar.date(from: components) ?? .distantPast
}

@Test func parsesDebitRule() async {
    let accountID = UUID()
    let rule = ParsingRuleSpec(
        id: UUID(), accountID: accountID, direction: .debit,
        pattern: #"RM(?<amount>[0-9,]+(?:\.[0-9]{2})?) spent at (?<merchant>.+?) on (?<date>\d{2}/\d{2}/\d{2})\. Avl Bal: RM(?<balance>[0-9,]+(?:\.[0-9]{2})?)"#,
        dateFormat: "dd/MM/yy", isCaseInsensitive: true, dotMatchesNewlines: false,
        priority: 0, isEnabled: true
    )
    let engine = RegexParsingEngine(rules: [rule])
    let result = await engine.parse(ParseInput(
        text: "MYBANK: RM12.50 spent at KFC on 14/11/26. Avl Bal: RM1,234.50. Ref 12345",
        accountID: accountID, sender: "MYBANK",
        receivedAt: Date(timeIntervalSince1970: 1_795_000_000)
    ))
    guard case .transaction(let draft) = result else { Issue.record("expected transaction"); return }
    #expect(draft.direction == .debit)
    #expect(draft.amount == Decimal(string: "12.50"))
    #expect(draft.merchant == "KFC")
    #expect(draft.balanceAfter == Decimal(string: "1234.50"))
}

@Test func parsesDateWithRuleFormat() async {
    let engine = RegexParsingEngine(rules: [rule()])
    let result = await engine.parse(input())
    guard case .transaction(let draft) = result else {
        Issue.record("expected transaction")
        return
    }
    #expect(draft.occurredAt == utcDate(2026, 11, 14))
    #expect(draft.reference == nil)
}

@Test func parsesCreditRule() async {
    let text = "MYBANK: RM500.00 credited to A/C 1234. Avl Bal: RM2,000.00"
    let creditPattern = #"RM(?<amount>[0-9,]+(?:\.[0-9]{2})?) credited to A/C (?<reference>\d+)\. Avl Bal: RM(?<balance>[0-9,]+(?:\.[0-9]{2})?)"#
    let engine = RegexParsingEngine(rules: [
        rule(direction: .credit, pattern: creditPattern, dateFormat: nil)
    ])
    let result = await engine.parse(input(text))
    guard case .transaction(let draft) = result else {
        Issue.record("expected transaction")
        return
    }
    #expect(draft.direction == .credit)
    #expect(draft.amount == Decimal(string: "500.00"))
    #expect(draft.balanceAfter == Decimal(string: "2000.00"))
    #expect(draft.reference == "1234")
    #expect(draft.merchant == "Unknown merchant")
    #expect(draft.occurredAt == sampleReceivedAt)
}

@Test func missingOptionalBalanceIsNil() async {
    let pattern = #"RM(?<amount>[0-9,]+(?:\.[0-9]{2})?) spent at (?<merchant>.+?) on"#
    let engine = RegexParsingEngine(rules: [rule(pattern: pattern)])
    let result = await engine.parse(input())
    guard case .transaction(let draft) = result else {
        Issue.record("expected transaction")
        return
    }
    #expect(draft.balanceAfter == nil)
    #expect(draft.merchant == "KFC")
}

@Test func invalidAmountFallsThroughToNextRule() async {
    let brokenID = UUID()
    let workingID = UUID()
    let engine = RegexParsingEngine(rules: [
        rule(id: brokenID, pattern: #"(?<amount>[A-Z]+):"#),
        rule(id: workingID)
    ])
    let result = await engine.parse(input())
    guard case .transaction(let draft) = result else {
        Issue.record("expected the second rule to produce a transaction")
        return
    }
    #expect(draft.matchedRuleID == workingID)
    #expect(draft.amount == Decimal(string: "12.50"))
}

@Test func lowerPriorityNumberWins() async {
    let balanceRuleID = UUID()
    let amountRuleID = UUID()
    let engine = RegexParsingEngine(rules: [
        rule(id: balanceRuleID, pattern: #"Avl Bal: RM(?<amount>[0-9,]+(?:\.[0-9]{2})?)"#, priority: 1),
        rule(id: amountRuleID, pattern: #"RM(?<amount>[0-9,]+(?:\.[0-9]{2})?) spent"#, priority: 0)
    ])
    let result = await engine.parse(input())
    guard case .transaction(let draft) = result else {
        Issue.record("expected transaction")
        return
    }
    #expect(draft.matchedRuleID == amountRuleID)
    #expect(draft.amount == Decimal(string: "12.50"))
}

@Test func equalPrioritiesKeepCreationOrder() async {
    let firstID = UUID()
    let secondID = UUID()
    let engine = RegexParsingEngine(rules: [
        rule(id: firstID, pattern: #"RM(?<amount>[0-9,]+(?:\.[0-9]{2})?) spent"#),
        rule(id: secondID, pattern: #"Avl Bal: RM(?<amount>[0-9,]+(?:\.[0-9]{2})?)"#)
    ])
    let result = await engine.parse(input())
    guard case .transaction(let draft) = result else {
        Issue.record("expected transaction")
        return
    }
    #expect(draft.matchedRuleID == firstID)
    #expect(draft.amount == Decimal(string: "12.50"))
}

@Test func caseInsensitiveMatching() async {
    let pattern = #"RM(?<amount>[0-9,]+(?:\.[0-9]{2})?) SPENT at (?<merchant>.+?) on"#
    let engine = RegexParsingEngine(rules: [rule(pattern: pattern, isCaseInsensitive: true)])
    let result = await engine.parse(input())
    guard case .transaction(let draft) = result else {
        Issue.record("expected a case-insensitive match")
        return
    }
    #expect(draft.merchant == "KFC")
}

@Test func caseSensitiveMatchingFails() async {
    let pattern = #"RM(?<amount>[0-9,]+(?:\.[0-9]{2})?) SPENT at (?<merchant>.+?) on"#
    let engine = RegexParsingEngine(rules: [rule(pattern: pattern, isCaseInsensitive: false)])
    let result = await engine.parse(input())
    guard case .notTransaction = result else {
        Issue.record("expected .notTransaction")
        return
    }
}

@Test func dotMatchesNewlinesMatchesAcrossLines() async {
    let text = "RM12.50 paid to KFC\nMalaysia done"
    let pattern = #"RM(?<amount>[0-9,]+(?:\.[0-9]{2})?) paid to (?<merchant>.*)done"#
    let engine = RegexParsingEngine(rules: [rule(pattern: pattern, dotMatchesNewlines: true)])
    let result = await engine.parse(input(text))
    guard case .transaction(let draft) = result else {
        Issue.record("expected the pattern to match across the newline")
        return
    }
    #expect(draft.merchant == "KFC Malaysia")
}

@Test func dotDoesNotMatchNewlinesByDefault() async {
    let text = "RM12.50 paid to KFC\nMalaysia done"
    let pattern = #"RM(?<amount>[0-9,]+(?:\.[0-9]{2})?) paid to (?<merchant>.*)done"#
    let engine = RegexParsingEngine(rules: [rule(pattern: pattern, dotMatchesNewlines: false)])
    let result = await engine.parse(input(text))
    guard case .notTransaction = result else {
        Issue.record("expected .notTransaction")
        return
    }
}

@Test func rulesAreFilteredByAccount() async {
    let accountA = UUID()
    let accountB = UUID()
    let engine = RegexParsingEngine(rules: [rule(accountID: accountA)])

    let matching = await engine.parse(input(accountID: accountA))
    guard case .transaction = matching else {
        Issue.record("expected the rule bound to account A to run")
        return
    }

    let other = await engine.parse(input(accountID: accountB))
    guard case .notTransaction = other else {
        Issue.record("expected account A's rule to be skipped for account B")
        return
    }

    let unbound = await engine.parse(input(accountID: nil))
    guard case .transaction = unbound else {
        Issue.record("expected all rules to run when no account is supplied")
        return
    }
}

@Test func ruleWithoutAccountOnlyRunsForAccountlessInput() async {
    let engine = RegexParsingEngine(rules: [rule(accountID: nil)])

    let accountless = await engine.parse(input(accountID: nil))
    guard case .transaction = accountless else {
        Issue.record("expected the accountless rule to run")
        return
    }

    let account = await engine.parse(input(accountID: UUID()))
    guard case .notTransaction = account else {
        Issue.record("expected the accountless rule to be skipped for a named account")
        return
    }
}

@Test func noMatchIsNotATransaction() async {
    let engine = RegexParsingEngine(rules: [rule()])
    let result = await engine.parse(input("Your OTP is 123456"))
    guard case .notTransaction = result else {
        Issue.record("expected .notTransaction")
        return
    }
}

@Test func missingAmountGroupIsAFailure() async {
    let ruleID = UUID()
    let pattern = #"spent at (?<merchant>.+?) on (?<date>\d{2}/\d{2}/\d{2})"#
    let engine = RegexParsingEngine(rules: [rule(id: ruleID, pattern: pattern)])
    let result = await engine.parse(input())
    guard case .failure(let diagnostics) = result else {
        Issue.record("expected .failure")
        return
    }
    #expect(diagnostics.contains {
        $0.code == .missingAmountGroup && $0.ruleID == ruleID && $0.field == "amount"
    })
}

@Test func optionalAmountGroupWithoutValueIsAFailure() async {
    let ruleID = UUID()
    let pattern = #"(?:RM(?<amount>[0-9,]+\.[0-9]{2}) )?spent at (?<merchant>.+?) on"#
    let engine = RegexParsingEngine(rules: [rule(id: ruleID, pattern: pattern)])
    let result = await engine.parse(input("spent at KFC on 14/11/26"))
    guard case .failure(let diagnostics) = result else {
        Issue.record("expected .failure")
        return
    }
    #expect(diagnostics.contains {
        $0.code == .missingField && $0.ruleID == ruleID && $0.field == "amount"
    })
}

@Test func invalidPatternIsAFailure() async {
    let ruleID = UUID()
    let engine = RegexParsingEngine(rules: [rule(id: ruleID, pattern: "(?<amount>[0-9]+")])
    let result = await engine.parse(input())
    guard case .failure(let diagnostics) = result else {
        Issue.record("expected .failure")
        return
    }
    #expect(diagnostics.contains { $0.code == .invalidPattern && $0.ruleID == ruleID })
    #expect(diagnostics.allSatisfy { !$0.message.isEmpty })
}

@Test func malformedPatternsFallThroughToTheNextRule() async {
    let brokenID = UUID()
    let workingID = UUID()
    let engine = RegexParsingEngine(rules: [
        rule(id: brokenID, pattern: "(?<amount>[0-9]"),
        rule(id: workingID)
    ])
    let result = await engine.parse(input())
    guard case .transaction(let draft) = result else {
        Issue.record("expected the valid rule to produce a transaction")
        return
    }
    #expect(draft.matchedRuleID == workingID)
}

@Test func emptyPatternIsAFailureNotACrash() async {
    let ruleID = UUID()
    let engine = RegexParsingEngine(rules: [rule(id: ruleID, pattern: "")])
    let result = await engine.parse(input())
    guard case .failure(let diagnostics) = result else {
        Issue.record("expected .failure")
        return
    }
    #expect(diagnostics.contains { $0.code == .missingAmountGroup && $0.ruleID == ruleID })
}

@Test func duplicateNamedGroupsAreAFailureNotACrash() async {
    let ruleID = UUID()
    let engine = RegexParsingEngine(rules: [
        rule(id: ruleID, pattern: #"(?<amount>[0-9]+)-(?<amount>[0-9]+)"#)
    ])
    let result = await engine.parse(input())
    guard case .failure(let diagnostics) = result else {
        Issue.record("expected .failure")
        return
    }
    #expect(diagnostics.contains { $0.code == .invalidPattern && $0.ruleID == ruleID })
}

@Test func messageLongerThanTheLimitIsAFailure() async {
    let engine = RegexParsingEngine(rules: [rule()])
    let result = await engine.parse(input(String(repeating: "A", count: 100_000)))
    guard case .failure(let diagnostics) = result else {
        Issue.record("expected .failure")
        return
    }
    #expect(diagnostics.contains {
        $0.code == .inputTooLong && $0.field == "text" && $0.ruleID == nil
    })
    #expect(diagnostics.contains { $0.message.contains("\(RegexParsingEngine.maximumTextLength)") })
}

@Test func messageAtTheLimitIsParsed() async {
    let text = String(repeating: "x", count: 20_000 - 7) + "RM12.50"
    #expect(text.count == 20_000)
    let engine = RegexParsingEngine(rules: [
        rule(pattern: #"RM(?<amount>[0-9]+\.[0-9]{2})"#, dateFormat: nil)
    ])
    let result = await engine.parse(input(text))
    guard case .transaction(let draft) = result else {
        Issue.record("expected a transaction at the 20,000-character limit")
        return
    }
    #expect(draft.amount == Decimal(string: "12.50"))
}

@Test func validationFailureFallsThroughToNextRule() async {
    let datedID = UUID()
    let fallbackID = UUID()
    let futureText = "MYBANK: RM12.50 spent at KFC on 20/11/26. Avl Bal: RM1,234.50. Ref 12345"
    // The first rule reads the date, which is in the future, so validation fails. The second
    // rule captures no date at all, so the receipt time keeps it valid.
    let undatedPattern = #"RM(?<amount>[0-9,]+(?:\.[0-9]{2})?) spent at (?<merchant>.+?) on"#
    let engine = RegexParsingEngine(rules: [
        rule(id: datedID, dateFormat: "dd/MM/yy"),
        rule(id: fallbackID, pattern: undatedPattern, dateFormat: nil, priority: 1)
    ])
    let result = await engine.parse(input(futureText))
    guard case .transaction(let draft) = result else {
        Issue.record("expected the fallback rule to produce a transaction")
        return
    }
    #expect(draft.matchedRuleID == fallbackID)
    #expect(draft.occurredAt == sampleReceivedAt)
}

@Test func noValidRuleReturnsFailureWithRuleDiagnostics() async {
    let ruleID = UUID()
    let zeroText = "MYBANK: RM0.00 spent at KFC on 14/11/26. Avl Bal: RM1,234.50. Ref 12345"
    let engine = RegexParsingEngine(rules: [rule(id: ruleID)])
    let result = await engine.parse(input(zeroText))
    guard case .failure(let diagnostics) = result else {
        Issue.record("expected .failure")
        return
    }
    #expect(diagnostics.contains {
        $0.code == .amountNotPositive && $0.ruleID == ruleID && $0.field == "amount"
    })
}

@Test func disabledRulesAreSkipped() async {
    let engine = RegexParsingEngine(rules: [rule(isEnabled: false)])
    let result = await engine.parse(input())
    guard case .notTransaction = result else {
        Issue.record("expected .notTransaction")
        return
    }
}

@Test func noRulesIsNotATransaction() async {
    let engine = RegexParsingEngine(rules: [])
    let result = await engine.parse(input())
    guard case .notTransaction = result else {
        Issue.record("expected .notTransaction")
        return
    }
}

@Test func missingDateFormatParsesCommonFormat() async {
    let engine = RegexParsingEngine(rules: [rule(dateFormat: nil)])
    let result = await engine.parse(input())
    guard case .transaction(let draft) = result else {
        Issue.record("expected transaction")
        return
    }
    #expect(draft.occurredAt == utcDate(2026, 11, 14))
}

@Test func missingDateFormatParsesISODate() async {
    let text = "RM12.50 spent at KFC on 2026-11-14. Avl Bal: RM1,234.50"
    let pattern = #"RM(?<amount>[0-9,]+(?:\.[0-9]{2})?) spent at (?<merchant>.+?) on (?<date>\d{4}-\d{2}-\d{2})\. Avl Bal: RM(?<balance>[0-9,]+(?:\.[0-9]{2})?)"#
    let engine = RegexParsingEngine(rules: [rule(pattern: pattern, dateFormat: nil)])
    let result = await engine.parse(input(text))
    guard case .transaction(let draft) = result else {
        Issue.record("expected transaction")
        return
    }
    #expect(draft.occurredAt == utcDate(2026, 11, 14))
}

@Test func commonFormatsCoverLongYearsAndMonthNames() async {
    let cases: [(dateText: String, dateGroup: String)] = [
        ("14/11/2026", #"(?<date>\d{2}/\d{2}/\d{4})"#),
        ("14-11-2026", #"(?<date>\d{2}-\d{2}-\d{4})"#),
        ("14 Nov 26", #"(?<date>\d{2} [A-Za-z]{3} \d{2})"#),
        ("14 Nov 2026", #"(?<date>\d{2} [A-Za-z]{3} \d{4})"#),
    ]
    for testCase in cases {
        let text = "RM12.50 paid on \(testCase.dateText)"
        let pattern = "RM(?<amount>[0-9]+\\.[0-9]{2}) paid on \(testCase.dateGroup)"
        let engine = RegexParsingEngine(rules: [rule(pattern: pattern, dateFormat: nil)])
        let result = await engine.parse(input(text))
        guard case .transaction(let draft) = result else {
            Issue.record("expected a transaction for \(testCase.dateText)")
            continue
        }
        #expect(draft.occurredAt == utcDate(2026, 11, 14), "\(testCase.dateText)")
    }
}

@Test func explicitDateFormatWinsOverCommonFormats() async {
    // 03/04/26 reads as 4 March with the rule's format and as 3 April with the common formats,
    // so the two paths are distinguishable.
    let text = "MYBANK: RM12.50 spent at KFC on 03/04/26. Avl Bal: RM1,234.50. Ref 12345"
    let explicit = RegexParsingEngine(rules: [rule(dateFormat: "MM/dd/yy")])
    let explicitResult = await explicit.parse(input(text))
    guard case .transaction(let explicitDraft) = explicitResult else {
        Issue.record("expected a transaction with an explicit date format")
        return
    }
    #expect(explicitDraft.occurredAt == utcDate(2026, 3, 4))

    let common = RegexParsingEngine(rules: [rule(dateFormat: nil)])
    let commonResult = await common.parse(input(text))
    guard case .transaction(let commonDraft) = commonResult else {
        Issue.record("expected a transaction with the common formats")
        return
    }
    #expect(commonDraft.occurredAt == utcDate(2026, 4, 3))
}

@Test func absentDateGroupUsesReceivedAt() async {
    // The message contains a date, but this rule does not capture it, so the receipt time stands.
    let pattern = #"RM(?<amount>[0-9,]+(?:\.[0-9]{2})?) spent at (?<merchant>.+?) on"#
    let engine = RegexParsingEngine(rules: [rule(pattern: pattern, dateFormat: nil)])
    let result = await engine.parse(input())
    guard case .transaction(let draft) = result else {
        Issue.record("expected transaction")
        return
    }
    #expect(draft.occurredAt == sampleReceivedAt)
}

@Test func unreadableDateWithoutFormatUsesReceivedAt() async {
    let text = "RM12.50 spent at KFC on NOTADATE. Avl Bal: RM1,234.50"
    let pattern = #"RM(?<amount>[0-9,]+(?:\.[0-9]{2})?) spent at (?<merchant>.+?) on (?<date>\S+)\. Avl Bal: RM(?<balance>[0-9,]+(?:\.[0-9]{2})?)"#
    let engine = RegexParsingEngine(rules: [rule(pattern: pattern, dateFormat: nil)])
    let result = await engine.parse(input(text))
    guard case .transaction(let draft) = result else {
        Issue.record("expected transaction")
        return
    }
    #expect(draft.occurredAt == sampleReceivedAt)
}

@Test func unreadableDateUsesReceivedAt() async {
    let text = "RM12.50 spent at KFC on NOTADATE. Avl Bal: RM1,234.50"
    let pattern = #"RM(?<amount>[0-9,]+(?:\.[0-9]{2})?) spent at (?<merchant>.+?) on (?<date>\S+)\. Avl Bal: RM(?<balance>[0-9,]+(?:\.[0-9]{2})?)"#
    let engine = RegexParsingEngine(rules: [rule(pattern: pattern)])
    let result = await engine.parse(input(text))
    guard case .transaction(let draft) = result else {
        Issue.record("expected transaction")
        return
    }
    #expect(draft.occurredAt == sampleReceivedAt)
}

@Test func parsesEnglishMonthNamesRegardlessOfDeviceLocale() async {
    let text = "RM12.50 paid on 14 Nov 26"
    let pattern = #"RM(?<amount>[0-9,]+(?:\.[0-9]{2})?) paid on (?<date>\d{2} [A-Za-z]{3} \d{2})"#
    let engine = RegexParsingEngine(rules: [rule(pattern: pattern, dateFormat: "dd MMM yy")])
    let result = await engine.parse(input(text))
    guard case .transaction(let draft) = result else {
        Issue.record("expected transaction")
        return
    }
    #expect(draft.occurredAt == utcDate(2026, 11, 14))
}

@Test func dateAndTimeGroupsCombine() async {
    let text = "14/11/26 09:30 RM75.00 paid"
    let pattern = #"(?<date>\d{2}/\d{2}/\d{2}) (?<time>\d{2}:\d{2}) RM(?<amount>[0-9.]+)"#
    let engine = RegexParsingEngine(rules: [rule(pattern: pattern, dateFormat: "dd/MM/yy HH:mm")])
    let result = await engine.parse(input(text))
    guard case .transaction(let draft) = result else {
        Issue.record("expected transaction")
        return
    }
    #expect(draft.occurredAt == utcDate(2026, 11, 14, hour: 9, minute: 30))
}

@Test func unreadableBalanceIsDropped() async {
    let text = "RM12.50 spent at KFC. Avl Bal: RMn/a"
    let pattern = #"RM(?<amount>[0-9,]+(?:\.[0-9]{2})?) spent at (?<merchant>.+?)\. Avl Bal: (?<balance>\S+)"#
    let engine = RegexParsingEngine(rules: [rule(pattern: pattern, dateFormat: nil)])
    let result = await engine.parse(input(text))
    guard case .transaction(let draft) = result else {
        Issue.record("expected transaction")
        return
    }
    #expect(draft.balanceAfter == nil)
    #expect(draft.amount == Decimal(string: "12.50"))
}
