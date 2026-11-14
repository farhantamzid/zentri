import Foundation
import Testing
@testable import ZentriCore

/// 2026-09-14 07:33:50 UTC, an instant whose minute boundary is easy to reason about.
private let dedupeBase = Date(timeIntervalSince1970: 1_790_000_030)
private let dedupeAccount = UUID()
private let otherAccount = UUID()

private let sampleText = "MYBANK: RM12.50 spent at KFC on 17/11/26"

@Test func fingerprintIsStableWithinMinute() {
    let date = Date(timeIntervalSince1970: 1_790_000_030)
    let a = Dedupe.fingerprint(text: "A  B", sender: "Bank", accountID: nil, receivedAt: date)
    let b = Dedupe.fingerprint(text: "A B", sender: "Bank", accountID: nil, receivedAt: date.addingTimeInterval(20))
    #expect(a == b)
    #expect(a.count == 64)
}

@Test func fingerprintChangesWithTheAmount() {
    let a = Dedupe.fingerprint(
        text: "RM12.50 spent at KFC", sender: "Bank", accountID: dedupeAccount, receivedAt: dedupeBase
    )
    let b = Dedupe.fingerprint(
        text: "RM12.60 spent at KFC", sender: "Bank", accountID: dedupeAccount, receivedAt: dedupeBase
    )
    #expect(a != b)
}

@Test func fingerprintChangesAcrossMinuteBoundaries() {
    let a = Dedupe.fingerprint(text: sampleText, sender: "Bank", accountID: nil, receivedAt: dedupeBase)
    let b = Dedupe.fingerprint(
        text: sampleText, sender: "Bank", accountID: nil, receivedAt: dedupeBase.addingTimeInterval(60)
    )
    #expect(a != b)
}

@Test func fingerprintChangesWithTheSender() {
    let a = Dedupe.fingerprint(text: sampleText, sender: "Bank", accountID: nil, receivedAt: dedupeBase)
    let b = Dedupe.fingerprint(text: sampleText, sender: "Other Bank", accountID: nil, receivedAt: dedupeBase)
    #expect(a != b)
}

@Test func fingerprintChangesWithTheAccount() {
    let a = Dedupe.fingerprint(text: sampleText, sender: nil, accountID: dedupeAccount, receivedAt: dedupeBase)
    let b = Dedupe.fingerprint(text: sampleText, sender: nil, accountID: otherAccount, receivedAt: dedupeBase)
    #expect(a != b)
}

@Test func fingerprintCollapsesWhitespaceAndLineEndings() {
    let a = Dedupe.fingerprint(
        text: "RM12.50\r\nspent at KFC", sender: "Bank", accountID: nil, receivedAt: dedupeBase
    )
    let b = Dedupe.fingerprint(
        text: "  RM12.50 spent \t at KFC  ", sender: "Bank", accountID: nil, receivedAt: dedupeBase
    )
    #expect(a == b)
}

@Test func fingerprintIgnoresSenderPadding() {
    let a = Dedupe.fingerprint(text: sampleText, sender: "  BANK ", accountID: nil, receivedAt: dedupeBase)
    let b = Dedupe.fingerprint(text: sampleText, sender: "BANK", accountID: nil, receivedAt: dedupeBase)
    #expect(a == b)
}

@Test func fingerprintIsLowercaseHex() {
    let fingerprint = Dedupe.fingerprint(
        text: sampleText, sender: "Bank", accountID: dedupeAccount, receivedAt: dedupeBase
    )
    #expect(fingerprint.allSatisfy { "0123456789abcdef".contains($0) })
}

@Test func recentDuplicateWindowIsTwoMinutes() {
    #expect(Dedupe.recentDuplicateWindow == 120)
}

@Test func identicalTextWithinTheWindowIsARecentDuplicate() {
    let existing = [DedupeCandidate(
        text: sampleText, sender: "Bank", accountID: nil, receivedAt: dedupeBase
    )]
    #expect(Dedupe.isRecentDuplicate(
        text: "MYBANK:  RM12.50 spent at KFC on 17/11/26",
        sender: "Bank",
        accountID: nil,
        receivedAt: dedupeBase.addingTimeInterval(30),
        existing: existing
    ))
    #expect(Dedupe.isRecentDuplicate(
        text: sampleText,
        sender: "Bank",
        accountID: nil,
        receivedAt: dedupeBase.addingTimeInterval(Dedupe.recentDuplicateWindow),
        existing: existing
    ))
}

@Test func identicalTextAfterTheWindowIsNotARecentDuplicate() {
    let existing = [DedupeCandidate(
        text: sampleText, sender: "Bank", accountID: nil, receivedAt: dedupeBase
    )]
    #expect(!Dedupe.isRecentDuplicate(
        text: sampleText,
        sender: "Bank",
        accountID: nil,
        receivedAt: dedupeBase.addingTimeInterval(Dedupe.recentDuplicateWindow + 1),
        existing: existing
    ))
}

@Test func recentDuplicateNeedsTheSameSender() {
    let existing = [DedupeCandidate(
        text: sampleText, sender: "Bank", accountID: dedupeAccount, receivedAt: dedupeBase
    )]
    #expect(!Dedupe.isRecentDuplicate(
        text: sampleText,
        sender: "Other Bank",
        accountID: dedupeAccount,
        receivedAt: dedupeBase.addingTimeInterval(30),
        existing: existing
    ))
}

@Test func recentDuplicateComparesSendersIgnoringCaseAndPadding() {
    let existing = [DedupeCandidate(
        text: sampleText, sender: " MYBANK ", accountID: nil, receivedAt: dedupeBase
    )]
    #expect(Dedupe.isRecentDuplicate(
        text: sampleText,
        sender: "mybank",
        accountID: nil,
        receivedAt: dedupeBase.addingTimeInterval(30),
        existing: existing
    ))
}

@Test func recentDuplicateFallsBackToTheAccountWhenTheSenderIsMissing() {
    let existing = [DedupeCandidate(
        text: sampleText, sender: nil, accountID: dedupeAccount, receivedAt: dedupeBase
    )]
    #expect(Dedupe.isRecentDuplicate(
        text: sampleText,
        sender: nil,
        accountID: dedupeAccount,
        receivedAt: dedupeBase.addingTimeInterval(30),
        existing: existing
    ))
    #expect(!Dedupe.isRecentDuplicate(
        text: sampleText,
        sender: nil,
        accountID: otherAccount,
        receivedAt: dedupeBase.addingTimeInterval(30),
        existing: existing
    ))
}

@Test func recentDuplicateWithNeitherSenderNorAccountStillMatchesItself() {
    let existing = [DedupeCandidate(text: sampleText, sender: nil, accountID: nil, receivedAt: dedupeBase)]
    #expect(Dedupe.isRecentDuplicate(
        text: sampleText,
        sender: nil,
        accountID: nil,
        receivedAt: dedupeBase.addingTimeInterval(30),
        existing: existing
    ))
}

@Test func recentDuplicateWithoutAnArchiveIsNotADuplicate() {
    #expect(!Dedupe.isRecentDuplicate(
        text: sampleText,
        sender: "Bank",
        accountID: nil,
        receivedAt: dedupeBase,
        existing: []
    ))
}
