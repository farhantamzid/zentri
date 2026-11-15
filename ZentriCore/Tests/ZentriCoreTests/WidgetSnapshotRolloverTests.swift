import Foundation
import Testing
@testable import ZentriCore

private func rolloverCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return calendar
}

private func utc(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
    rolloverCalendar().date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
}

/// A snapshot generated mid-afternoon with a three-day trend ending on its own day.
private func makeRolloverSnapshot(generatedAt: Date) -> WidgetSnapshot {
    let calendar = rolloverCalendar()
    let today = calendar.startOfDay(for: generatedAt)
    let trend = (0..<3).map { offset in
        WidgetSnapshot.TrendPoint(
            date: calendar.date(byAdding: .day, value: offset - 2, to: today) ?? today,
            spend: String(offset + 1)
        )
    }
    return WidgetSnapshot(
        generatedAt: generatedAt,
        currencyCode: "USD",
        numberGrouping: .western,
        balance: "100",
        balanceAsOf: nil,
        todaySpend: "3",
        monthSpend: "40",
        monthIncome: "50",
        trend: trend,
        recentTransactions: [],
        topCategories: [WidgetSnapshot.TopCategory(name: "Dining", symbolName: "fork.knife", colorToken: "coral", amount: "40", share: "100")]
    )
}

@Test func theSameDayLeavesTheSnapshotUntouched() {
    let snapshot = makeRolloverSnapshot(generatedAt: utc(2026, 11, 18, hour: 15))

    #expect(snapshot.rolledOver(to: utc(2026, 11, 18, hour: 23), calendar: rolloverCalendar()) == snapshot)
}

@Test func aNewDayZeroesTodayAndExtendsTheTrendWithEmptyDays() {
    let snapshot = makeRolloverSnapshot(generatedAt: utc(2026, 11, 18, hour: 15))

    let rolled = snapshot.rolledOver(to: utc(2026, 11, 20, hour: 1), calendar: rolloverCalendar())

    #expect(rolled.todaySpend == "0")
    #expect(rolled.monthSpend == "40")
    #expect(rolled.topCategories == snapshot.topCategories)
    #expect(rolled.balance == "100")
    #expect(rolled.trend.map(\.spend) == ["1", "2", "3", "0", "0"])
    #expect(rolled.trend.last?.date == utc(2026, 11, 20))
}

@Test func theTrendNeverGrowsPastThirtyDays() {
    let calendar = rolloverCalendar()
    var snapshot = makeRolloverSnapshot(generatedAt: utc(2026, 11, 18, hour: 15))
    let today = utc(2026, 11, 18)
    snapshot.trend = (0..<30).map { offset in
        WidgetSnapshot.TrendPoint(date: calendar.date(byAdding: .day, value: offset - 29, to: today) ?? today, spend: "1")
    }

    let rolled = snapshot.rolledOver(to: utc(2026, 11, 19, hour: 0), calendar: calendar)

    #expect(rolled.trend.count == 30)
    #expect(rolled.trend.last?.spend == "0")
    #expect(rolled.trend.first?.date == calendar.date(byAdding: .day, value: -28, to: today))
}

@Test func aNewMonthAlsoZeroesTheMonthAndItsCategories() {
    let snapshot = makeRolloverSnapshot(generatedAt: utc(2026, 11, 30, hour: 22))

    let rolled = snapshot.rolledOver(to: utc(2026, 12, 1, hour: 0), calendar: rolloverCalendar())

    #expect(rolled.todaySpend == "0")
    #expect(rolled.monthSpend == "0")
    #expect(rolled.monthIncome == "0")
    #expect(rolled.topCategories.isEmpty)
}

@Test func anEarlierInstantNeverRollsBackwards() {
    let snapshot = makeRolloverSnapshot(generatedAt: utc(2026, 11, 18, hour: 15))

    #expect(snapshot.rolledOver(to: utc(2026, 11, 17, hour: 9), calendar: rolloverCalendar()) == snapshot)
}

@Test func timelineDatesAreNowTheNextHourAndMidnightInOrder() {
    let calendar = rolloverCalendar()
    let afternoon = utc(2026, 11, 18, hour: 15)
    let schedule = WidgetTimelineSchedule(now: afternoon, calendar: calendar)
    #expect(schedule.entryDates == [afternoon, afternoon.addingTimeInterval(3600), utc(2026, 11, 19)])
    #expect(schedule.reloadDate == afternoon.addingTimeInterval(3600))

    let lateEvening = utc(2026, 11, 18, hour: 23).addingTimeInterval(30 * 60)
    let late = WidgetTimelineSchedule(now: lateEvening, calendar: calendar)
    #expect(late.entryDates == [lateEvening, utc(2026, 11, 19), lateEvening.addingTimeInterval(3600)])
    #expect(late.reloadDate == lateEvening.addingTimeInterval(3600))
}
