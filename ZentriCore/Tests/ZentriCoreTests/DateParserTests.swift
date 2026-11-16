import Foundation
import Testing
@testable import ZentriCore

private let receivedAt = Date(timeIntervalSince1970: 1_795_000_000)

/// The zone message dates are read in for these tests: UTC+8 all year, neither GMT nor a zone
/// a test machine is likely to run in, so a test cannot pass by reading dates in either.
private let testZone = TimeZone(identifier: "Asia/Kuala_Lumpur") ?? .gmt

/// Midnight on a day in ``testZone``.
private func localDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = testZone
    return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
}

/// Every supported spelling must still be read when the rule names no format.
@Test func commonFormatsParseSupportedDates() {
    let cases: [(raw: String, expected: Date)] = [
        ("14/11/26", localDate(2026, 11, 14)),
        ("14/11/2026", localDate(2026, 11, 14)),
        ("14-11-2026", localDate(2026, 11, 14)),
        ("14 Nov 26", localDate(2026, 11, 14)),
        ("14 Nov 2026", localDate(2026, 11, 14)),
        ("2026-11-14", localDate(2026, 11, 14)),
        ("2026/11/14", localDate(2026, 11, 14)),
        ("1/2/26", localDate(2026, 2, 1)),
        ("31/12/26", localDate(2026, 12, 31)),
    ]
    for testCase in cases {
        let parsed = DateParser.date(from: testCase.raw, format: nil, receivedAt: receivedAt, timeZone: testZone)
        #expect(parsed == testCase.expected, "\(testCase.raw)")
    }
}

/// A day that does not exist must not be reread as a year: Foundation's lenient retry turns
/// `32/11/26` into year 32, which no bank message can carry.
@Test func impossibleDatesFallBackToTheReceiptTime() {
    for raw in ["32/11/26", "31/04/26", "29/02/26", "30/02/26", "31/06/26"] {
        let parsed = DateParser.date(from: raw, format: nil, receivedAt: receivedAt, timeZone: testZone)
        #expect(parsed == receivedAt, "\(raw)")
    }
}

/// The explicit format reads `yyyy-MM-dd`, so a day-first value can only be a stray year.
@Test func explicitFormatRejectsAnOutOfWindowYear() {
    #expect(DateParser.parse("32/11/26", format: "yyyy-MM-dd", timeZone: testZone) == nil)
    #expect(DateParser.date(from: "32/11/26", format: "yyyy-MM-dd", receivedAt: receivedAt, timeZone: testZone) == receivedAt)
}

@Test func explicitFormatStillParsesAnInWindowDate() {
    let parsed = DateParser.date(from: "2026-11-14", format: "yyyy-MM-dd", receivedAt: receivedAt, timeZone: testZone)
    #expect(parsed == localDate(2026, 11, 14))
}

/// The window is 2000–2099, inclusive, matching the two-digit-year window.
@Test func yearsOutsideTheWindowAreRejected() {
    let inWindow: [(raw: String, expected: Date)] = [
        ("14/11/2000", localDate(2000, 11, 14)),
        ("14/11/2099", localDate(2099, 11, 14)),
    ]
    for testCase in inWindow {
        let parsed = DateParser.date(from: testCase.raw, format: "dd/MM/yyyy", receivedAt: receivedAt, timeZone: testZone)
        #expect(parsed == testCase.expected, "\(testCase.raw)")
    }

    for raw in ["14/11/1999", "14/11/2100"] {
        let parsed = DateParser.date(from: raw, format: "dd/MM/yyyy", receivedAt: receivedAt, timeZone: testZone)
        #expect(parsed == receivedAt, "\(raw)")
    }
}

@Test func missingOrUnreadableValueUsesTheReceiptTime() {
    #expect(DateParser.date(from: nil, format: nil, receivedAt: receivedAt, timeZone: testZone) == receivedAt)
    #expect(DateParser.date(from: "   ", format: nil, receivedAt: receivedAt, timeZone: testZone) == receivedAt)
    #expect(DateParser.date(from: "NOTADATE", format: nil, receivedAt: receivedAt, timeZone: testZone) == receivedAt)
    #expect(DateParser.date(from: "NOTADATE", format: "dd/MM/yy", receivedAt: receivedAt, timeZone: testZone) == receivedAt)
}

// MARK: - Local time (I2)

/// A bank message states local time: 20:15 on 14 Nov in UTC+8 is 12:15 UTC the same day, not
/// 04:15 the next morning as a GMT reading would make it.
@Test func aDateAndTimeIsReadAsLocalWallClockTime() throws {
    let parsed = try #require(DateParser.parse("14/11/26 20:15", format: "dd/MM/yy HH:mm", timeZone: testZone))
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = .gmt
    #expect(parsed == utc.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 12, minute: 15)))
    var local = Calendar(identifier: .gregorian)
    local.timeZone = testZone
    #expect(local.component(.day, from: parsed) == 14)
    #expect(local.component(.hour, from: parsed) == 20)
}

/// West of Greenwich a GMT midnight is the previous local evening, so a date-only value must be
/// read as the local day.
@Test func aDateOnlyValueStaysOnItsLocalDayWestOfGreenwich() throws {
    let newYork = try #require(TimeZone(identifier: "America/New_York"))
    let parsed = try #require(DateParser.date(from: "14/11/26", format: nil, receivedAt: receivedAt, timeZone: newYork))
    var local = Calendar(identifier: .gregorian)
    local.timeZone = newYork
    #expect(local.dateComponents([.year, .month, .day], from: parsed) == DateComponents(year: 2026, month: 11, day: 14))
}

/// An explicit offset in the value wins over the zone the caller passes.
@Test func anExplicitOffsetIsKept() throws {
    let parsed = try #require(DateParser.parse(
        "2026-11-14T09:30:00+05:30", format: "yyyy-MM-dd'T'HH:mm:ssZZZZZ", timeZone: testZone
    ))
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = .gmt
    #expect(parsed == utc.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 4, minute: 0)))
}

/// Without a zone argument the device's own zone is used.
@Test func theDefaultZoneIsTheDevicesZone() throws {
    let parsed = try #require(DateParser.parse("14/11/26 20:15", format: "dd/MM/yy HH:mm"))
    var local = Calendar(identifier: .gregorian)
    local.timeZone = .current
    #expect(parsed == local.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 20, minute: 15)))
}

/// A date-only value naming the receipt's own day has no better time than the receipt, which keeps
/// one day's messages in the order they arrived.
@Test func aDateOnlyValueOnTheReceiptDayUsesTheReceiptTime() {
    // `receivedAt` is 2026-11-18 19:06:40 in UTC+8.
    #expect(DateParser.date(from: "18/11/26", format: nil, receivedAt: receivedAt, timeZone: testZone) == receivedAt)
    #expect(DateParser.date(from: "18/11/26", format: "dd/MM/yy", receivedAt: receivedAt, timeZone: testZone) == receivedAt)
    // A format with a time keeps the stated time.
    let timed = DateParser.date(from: "18/11/26 08:00", format: "dd/MM/yy HH:mm", receivedAt: receivedAt, timeZone: testZone)
    #expect(timed != receivedAt)
}
