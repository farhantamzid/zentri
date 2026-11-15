import Accessibility
import Foundation
import Testing
import ZentriCore
@testable import ZentriApp

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private let locale = Locale(identifier: "en_US")
private let usd = MoneyFormat(currencyCode: "USD", grouping: .western, locale: locale)

private func day(_ day: Int, month: Int = 11, hour: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
}

private func category(_ name: String, amount: Decimal, share: Decimal) -> CategoryTotal {
    CategoryTotal(
        categoryID: UUID(), categoryName: name, symbolName: "tag", colorToken: "slate",
        amount: amount, share: share, transactionCount: 1, previousAmount: 0, changePercent: nil
    )
}

// MARK: - Selection

@Test func aTouchSelectsWhatItIsOverAndLiftingKeepsIt() {
    #expect(ChartSelectionRule.selection(current: nil as String?, touched: "Dining") == "Dining")
    #expect(ChartSelectionRule.selection(current: "Dining", touched: "Transport") == "Transport")
    // Lifting the finger keeps the selection.
    #expect(ChartSelectionRule.selection(current: "Transport", touched: nil) == "Transport")
    // Touching the selected value again keeps it, so a press and the tap that ends it agree.
    #expect(ChartSelectionRule.selection(current: "Dining", touched: "Dining") == "Dining")
}

// MARK: - Daily spending

@Test func theDailyChartFormatsEveryDayOnceAndFindsADayFromAnyInstantInIt() throws {
    let data = DailySpendingChartData(
        days: [
            DailySpend(date: day(1), amount: 0),
            DailySpend(date: day(2), amount: 750),
            DailySpend(date: day(3), amount: 250),
        ],
        total: 1_000,
        moneyFormat: usd,
        locale: locale,
        calendar: calendar
    )

    #expect(data.points.map(\.amountText) == ["$0.00", "$750.00", "$250.00"])
    #expect(data.points[1].dayText == "Monday, Nov 2")
    #expect(data.point(containing: day(3, hour: 17))?.date == day(3))
    #expect(data.point(containing: day(4, hour: 1)) == nil)
    #expect(data.summary == "Total $1,000.00. Highest: $750.00 on Monday, Nov 2.")

    let series = try #require(data.descriptor.series.first)
    #expect(data.descriptor.series.count == 1)
    #expect(series.points.map(\.value) == [0, 750, 250])
    #expect(series.points.map(\.valueText) == ["$0.00", "$750.00", "$250.00"])
    #expect(data.descriptor.categories == data.points.map(\.dayText))
}

@Test func theAudioGraphCarriesTheTitleSummaryAndEveryPoint() {
    let data = DailySpendingChartData(
        days: [DailySpend(date: day(1), amount: 40), DailySpend(date: day(2), amount: 10)],
        total: 50,
        moneyFormat: usd,
        locale: locale,
        calendar: calendar
    )

    let descriptor = data.descriptor.makeChartDescriptor()

    #expect(descriptor.title == "Daily spending")
    #expect(descriptor.summary == data.summary)
    #expect(descriptor.series.count == 1)
    #expect(descriptor.series[0].dataPoints.map(\.label) == ["$40.00", "$10.00"])
    #expect(descriptor.series[0].dataPoints.count == 2)
}

// MARK: - Categories

@Test func theDonutMapsEachSelectedAngleToTheSliceThatCoversIt() throws {
    let data = CategoryDonutChartData(
        categories: [
            category("Transport", amount: 750, share: 75),
            category("Dining", amount: 250, share: 25),
        ],
        moneyFormat: usd
    )

    #expect(data.slice(at: 10)?.id == "Transport")
    #expect(data.slice(at: 750)?.id == "Transport")
    #expect(data.slice(at: 751)?.id == "Dining")
    #expect(data.slice(at: 1_001) == nil)
    #expect(data.slice(named: "Dining")?.figuresText == "$250.00, 25%")
    #expect(data.summary == "Largest: Transport, 75% of spending.")

    let series = try #require(data.descriptor.series.first)
    #expect(data.descriptor.categories == ["Transport", "Dining"])
    #expect(series.points.map(\.value) == [750, 250])
    #expect(series.points.map(\.valueText) == ["$750.00, 75%", "$250.00, 25%"])
}

// MARK: - Income and spending

@Test func theSixMonthChartHasAReceivedAndASpentSeriesAndSummarizesTheNewestMonth() {
    let data = IncomeExpenseChartData(
        months: [
            MonthlyIncomeExpense(month: day(1, month: 10), income: 0, spend: 800),
            MonthlyIncomeExpense(month: day(1, month: 11), income: 5_000, spend: 1_000),
        ],
        moneyFormat: usd,
        locale: locale
    )

    #expect(data.summary == "November 2026: received $5,000.00, spent $1,000.00")
    #expect(data.descriptor.categories == ["October 2026", "November 2026"])
    #expect(data.descriptor.series.map(\.name) == ["Received", "Spent"])
    #expect(data.descriptor.series[0].points.map(\.value) == [0, 5_000])
    #expect(data.descriptor.series[1].points.map(\.value) == [800, 1_000])

    let descriptor = data.descriptor.makeChartDescriptor()
    #expect(descriptor.series.count == 2)
    #expect(descriptor.series.allSatisfy { $0.dataPoints.count == 2 })
}

@Test func aTapOnTheRingFindsItsSliceClockwiseFromTwelveOClock() {
    let data = CategoryDonutChartData(
        categories: [
            category("Transport", amount: 750, share: 75),
            category("Dining", amount: 250, share: 25),
        ],
        moneyFormat: usd
    )
    let size = CGSize(width: 300, height: 200)

    // An eighth of the way round, up and to the right of the centre: Transport's first quarter.
    let upRight = data.angleValue(at: CGPoint(x: 150 + 60, y: 100 - 60), in: size, innerRadiusRatio: 0.6)
    #expect(abs((upRight ?? 0) - 125) < 0.001)
    #expect(upRight.flatMap(data.slice(at:))?.id == "Transport")

    // Seven eighths of the way round, up and to the left: Dining's quarter.
    let upLeft = data.angleValue(at: CGPoint(x: 150 - 60, y: 100 - 60), in: size, innerRadiusRatio: 0.6)
    #expect(abs((upLeft ?? 0) - 875) < 0.001)
    #expect(upLeft.flatMap(data.slice(at:))?.id == "Dining")

    // The hole and the space beside the donut are not slices.
    #expect(data.angleValue(at: CGPoint(x: 150, y: 100), in: size, innerRadiusRatio: 0.6) == nil)
    #expect(data.angleValue(at: CGPoint(x: 10, y: 100), in: size, innerRadiusRatio: 0.6) == nil)
}

@Test func anAudioGraphVoiceOverAlreadyHoldsIsRewrittenForANewMonth() {
    let october = IncomeExpenseChartData(
        months: [MonthlyIncomeExpense(month: day(1, month: 10), income: 0, spend: 800)],
        moneyFormat: usd,
        locale: locale
    )
    let november = DailySpendingChartData(
        days: [DailySpend(date: day(1), amount: 30), DailySpend(date: day(2), amount: 0), DailySpend(date: day(3), amount: 5)],
        total: 35,
        moneyFormat: usd,
        locale: locale,
        calendar: calendar
    )
    let held = october.descriptor.makeChartDescriptor()

    november.descriptor.updateChartDescriptor(held)

    #expect(held.title == "Daily spending")
    #expect(held.summary == november.summary)
    #expect(held.series.map(\.name) == ["Spent"])
    #expect(held.series[0].dataPoints.map(\.label) == ["$30.00", "$0.00", "$5.00"])
    #expect((held.xAxis as? AXCategoricalDataAxisDescriptor)?.categoryOrder == november.points.map(\.dayText))
}
