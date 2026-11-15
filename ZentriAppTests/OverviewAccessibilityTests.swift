import Accessibility
import Foundation
import Testing
import ZentriCore
@testable import ZentriApp

private let locale = Locale(identifier: "en_US")
private let usd = MoneyFormat(currencyCode: "USD", grouping: .western, locale: locale)

private func row(isTransfer: Bool, direction: Direction = .debit) -> OverviewTransaction {
    OverviewTransaction(
        id: UUID(),
        merchant: "Savings Move",
        categoryName: "Other",
        symbolName: "circle",
        colorToken: "slate",
        amount: 300,
        direction: direction,
        occurredAt: .now,
        isTransfer: isTransfer
    )
}

@Test func aRecentTransferSaysItIsATransfer() {
    #expect(row(isTransfer: true).spokenSummary(moneyFormat: usd) == "Savings Move, Other, transfer, spent $300.00")
    #expect(row(isTransfer: false).spokenSummary(moneyFormat: usd) == "Savings Move, Other, spent $300.00")
    #expect(
        row(isTransfer: false, direction: .credit).spokenSummary(moneyFormat: usd)
            == "Savings Move, Other, received $300.00"
    )
}

@Test func theWeekChartOffersATotalAndADataTableRowPerDay() throws {
    let start = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 12)))
    let days = (0..<7).map { offset in
        DailySpend(date: start.addingTimeInterval(Double(offset) * 86_400), amount: offset == 6 ? 250 : 0)
    }

    let data = SevenDayChartData(days: days, moneyFormat: usd, locale: locale)

    let lines = data.weekTable.components(separatedBy: "\n")
    #expect(lines.count == 8)
    #expect(lines[0] == "Total $250.00")
    #expect(lines[7] == "Sunday, Nov 15: $250.00")

    let descriptor = data.descriptor.makeChartDescriptor()
    #expect(descriptor.title == "Spending, last seven days")
    #expect(descriptor.summary == "Total $250.00")
    #expect(descriptor.series.count == 1)
    #expect(descriptor.series[0].dataPoints.count == 7)
    #expect(descriptor.series[0].dataPoints.last?.label == "$250.00")
}
