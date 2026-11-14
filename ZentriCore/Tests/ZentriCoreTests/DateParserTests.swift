import Foundation
import Testing
@testable import ZentriCore

private let receivedAt = Date(timeIntervalSince1970: 1_795_000_000)

private func utcDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
}

/// Every supported spelling must still be read when the rule names no format.
@Test func commonFormatsParseSupportedDates() {
    let cases: [(raw: String, expected: Date)] = [
        ("14/11/26", utcDate(2026, 11, 14)),
        ("14/11/2026", utcDate(2026, 11, 14)),
        ("14-11-2026", utcDate(2026, 11, 14)),
        ("14 Nov 26", utcDate(2026, 11, 14)),
        ("14 Nov 2026", utcDate(2026, 11, 14)),
        ("2026-11-14", utcDate(2026, 11, 14)),
        ("2026/11/14", utcDate(2026, 11, 14)),
        ("1/2/26", utcDate(2026, 2, 1)),
        ("31/12/26", utcDate(2026, 12, 31)),
    ]
    for testCase in cases {
        let parsed = DateParser.date(from: testCase.raw, format: nil, receivedAt: receivedAt)
        #expect(parsed == testCase.expected, "\(testCase.raw)")
    }
}

/// A day that does not exist must not be reread as a year: Foundation's lenient retry turns
/// `32/11/26` into year 32, which no bank message can carry.
@Test func impossibleDatesFallBackToTheReceiptTime() {
    for raw in ["32/11/26", "31/04/26", "29/02/26", "30/02/26", "31/06/26"] {
        let parsed = DateParser.date(from: raw, format: nil, receivedAt: receivedAt)
        #expect(parsed == receivedAt, "\(raw)")
    }
}

/// The explicit format reads `yyyy-MM-dd`, so a day-first value can only be a stray year.
@Test func explicitFormatRejectsAnOutOfWindowYear() {
    #expect(DateParser.parse("32/11/26", format: "yyyy-MM-dd") == nil)
    #expect(DateParser.date(from: "32/11/26", format: "yyyy-MM-dd", receivedAt: receivedAt) == receivedAt)
}

@Test func explicitFormatStillParsesAnInWindowDate() {
    let parsed = DateParser.date(from: "2026-11-14", format: "yyyy-MM-dd", receivedAt: receivedAt)
    #expect(parsed == utcDate(2026, 11, 14))
}

/// The window is 2000–2099, inclusive, matching the two-digit-year window.
@Test func yearsOutsideTheWindowAreRejected() {
    let inWindow: [(raw: String, expected: Date)] = [
        ("14/11/2000", utcDate(2000, 11, 14)),
        ("14/11/2099", utcDate(2099, 11, 14)),
    ]
    for testCase in inWindow {
        let parsed = DateParser.date(from: testCase.raw, format: "dd/MM/yyyy", receivedAt: receivedAt)
        #expect(parsed == testCase.expected, "\(testCase.raw)")
    }

    for raw in ["14/11/1999", "14/11/2100"] {
        let parsed = DateParser.date(from: raw, format: "dd/MM/yyyy", receivedAt: receivedAt)
        #expect(parsed == receivedAt, "\(raw)")
    }
}

@Test func missingOrUnreadableValueUsesTheReceiptTime() {
    #expect(DateParser.date(from: nil, format: nil, receivedAt: receivedAt) == receivedAt)
    #expect(DateParser.date(from: "   ", format: nil, receivedAt: receivedAt) == receivedAt)
    #expect(DateParser.date(from: "NOTADATE", format: nil, receivedAt: receivedAt) == receivedAt)
    #expect(DateParser.date(from: "NOTADATE", format: "dd/MM/yy", receivedAt: receivedAt) == receivedAt)
}
