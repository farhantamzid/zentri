import Foundation
import Testing
@testable import ZentriCore

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}()

private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) throws -> Date {
    try #require(
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)),
        "invalid test date \(year)-\(month)-\(day)"
    )
}

private func monthPeriod(_ year: Int, _ month: Int) throws -> InsightsPeriod {
    let start = try makeDate(year, month, 1, hour: 0)
    let nextMonth = try #require(calendar.date(byAdding: .month, value: 1, to: start))
    return InsightsPeriod(start: start, end: nextMonth.addingTimeInterval(-1))
}

/// Ten days of October 2026 starting on the 10th, with the supplied spend on each.
private func days(_ amounts: [Decimal]) throws -> [DailySpend] {
    try amounts.enumerated().map { offset, amount in
        DailySpend(date: try makeDate(2026, 10, 10 + offset, hour: 0), amount: amount)
    }
}

private func spend(
    _ amount: Decimal,
    _ direction: Direction = .debit,
    on occurredAt: Date,
    merchant: String = "Merchant",
    isTransfer: Bool = false
) -> TransactionSnapshot {
    TransactionSnapshot(
        id: UUID(),
        accountID: UUID(),
        amount: amount,
        direction: direction,
        occurredAt: occurredAt,
        merchant: merchant,
        isTransfer: isTransfer
    )
}

// MARK: - Peak day

@Test func thePeakDayIsComparedWithTheAverageDayOfThePeriod() throws {
    // 50 over ten days is an average of 5, so the 16 spent on the 12th is 3.2× the average.
    let daily = try days([4, 2, 16, 0, 8, 0, 6, 4, 5, 5])

    let peak = try #require(InsightsCalculator.peakDay(in: daily, through: try makeDate(2026, 10, 31)))

    #expect(peak.date == (try makeDate(2026, 10, 12, hour: 0)))
    #expect(peak.amount == 16)
    #expect(peak.averageDailySpend == 5)
    #expect(peak.ratioToAverage == Decimal(string: "3.2"))
}

@Test func daysAfterTheCutOffDoNotCountTowardsTheAverage() throws {
    // Only the first four days have happened: 20 over four days is an average of 5.
    let daily = try days([2, 10, 4, 4, 0, 0, 0, 0, 0, 0])

    let peak = try #require(InsightsCalculator.peakDay(in: daily, through: try makeDate(2026, 10, 13, hour: 18)))

    #expect(peak.date == (try makeDate(2026, 10, 11, hour: 0)))
    #expect(peak.averageDailySpend == 5)
    #expect(peak.ratioToAverage == 2)
}

@Test func theRatioIsRoundedToOneDecimal() throws {
    // 10 over three days: the peak of 6 is 1.8× the average of 3.333….
    let daily = try days([6, 3, 1])

    let peak = try #require(InsightsCalculator.peakDay(in: daily, through: try makeDate(2026, 10, 31)))

    #expect(peak.ratioToAverage == Decimal(string: "1.8"))
}

@Test func tiedPeakDaysResolveToTheEarliest() throws {
    let daily = try days([1, 9, 3, 9])

    let peak = try #require(InsightsCalculator.peakDay(in: daily, through: try makeDate(2026, 10, 31)))

    #expect(peak.date == (try makeDate(2026, 10, 11, hour: 0)))
}

@Test func aPeriodWithoutSpendHasNoPeakDay() throws {
    #expect(InsightsCalculator.peakDay(in: try days([0, 0, 0]), through: try makeDate(2026, 10, 31)) == nil)
    #expect(InsightsCalculator.peakDay(in: [], through: try makeDate(2026, 10, 31)) == nil)
    // Spend that has not happened yet by the cut-off is not a peak either.
    #expect(InsightsCalculator.peakDay(in: try days([0, 0, 7]), through: try makeDate(2026, 10, 11)) == nil)
}

// MARK: - Largest spends

@Test func largestSpendsLeaveOutIncomeAndTransfers() throws {
    let period = try monthPeriod(2026, 10)
    let rent = spend(1_200, on: try makeDate(2026, 10, 1), merchant: "Rent")
    let groceries = spend(80, on: try makeDate(2026, 10, 4), merchant: "Groceries")

    let largest = InsightsCalculator.largestSpends(
        transactions: [
            spend(5_000, .credit, on: try makeDate(2026, 10, 25), merchant: "Salary"),
            spend(3_000, on: try makeDate(2026, 10, 2), merchant: "Savings", isTransfer: true),
            groceries,
            rent,
        ],
        period: period
    )

    #expect(largest == [rent, groceries])
}

@Test func largestSpendsAreTheLimitsLargestInThePeriodLargestFirst() throws {
    let period = try monthPeriod(2026, 10)
    let inPeriod = try (1...7).map { index in
        spend(Decimal(index * 10), on: try makeDate(2026, 10, index), merchant: "Shop \(index)")
    }
    let lastMonth = spend(9_999, on: try makeDate(2026, 9, 30), merchant: "Last month")
    let nextMonth = spend(9_999, on: try makeDate(2026, 11, 1, hour: 0), merchant: "Next month")

    let largest = InsightsCalculator.largestSpends(
        transactions: inPeriod + [lastMonth, nextMonth],
        period: period
    )

    #expect(largest.count == InsightsCalculator.largestTransactionLimit)
    #expect(largest.map(\.amount) == [70, 60, 50, 40, 30])
}

@Test func equalSpendsListTheNewestFirst() throws {
    let period = try monthPeriod(2026, 10)
    let older = spend(50, on: try makeDate(2026, 10, 3), merchant: "Older")
    let newer = spend(50, on: try makeDate(2026, 10, 9), merchant: "Newer")

    let largest = InsightsCalculator.largestSpends(transactions: [older, newer], period: period)

    #expect(largest == [newer, older])
}
