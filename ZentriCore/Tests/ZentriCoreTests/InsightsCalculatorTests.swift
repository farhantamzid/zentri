import Foundation
import Testing
@testable import ZentriCore

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}()

private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) throws -> Date {
    try #require(
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)),
        "invalid test date \(year)-\(month)-\(day)"
    )
}

private func monthPeriod(_ year: Int, _ month: Int) throws -> InsightsPeriod {
    let start = try makeDate(year, month, 1, hour: 0)
    let nextMonth = try #require(calendar.date(byAdding: .month, value: 1, to: start))
    return InsightsPeriod(start: start, end: nextMonth.addingTimeInterval(-1))
}

private func money(_ text: String) -> Decimal {
    Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) ?? 0
}

private func transaction(
    _ amount: Decimal,
    _ direction: Direction = .debit,
    _ occurredAt: Date,
    merchant: String = "Merchant",
    category: String = "Other",
    symbolName: String = "ellipsis",
    colorToken: String = "slate",
    isTransfer: Bool = false,
    id: UUID = UUID()
) -> TransactionSnapshot {
    TransactionSnapshot(
        id: id,
        accountID: UUID(),
        amount: amount,
        direction: direction,
        occurredAt: occurredAt,
        merchant: merchant,
        categoryName: category,
        symbolName: symbolName,
        colorToken: colorToken,
        isTransfer: isTransfer
    )
}

@Test func spendAndIncomeExcludeTransfersAndCredits() throws {
    let summary = InsightsCalculator.summary(
        transactions: [
            transaction(money("25.00"), .debit, try makeDate(2026, 10, 3), merchant: "Kopitiam", category: "Dining"),
            transaction(money("15.00"), .debit, try makeDate(2026, 10, 12), merchant: "Toast Box", category: "Dining"),
            transaction(money("10.00"), .debit, try makeDate(2026, 10, 20), merchant: "Grab", category: "Transport"),
            transaction(
                money("1000.00"), .credit, try makeDate(2026, 10, 25, hour: 9),
                merchant: "Acme Payroll", category: "Income"
            ),
            transaction(
                money("500.00"), .debit, try makeDate(2026, 10, 26),
                merchant: "Savings Transfer", category: "Transfers", isTransfer: true
            ),
        ],
        period: try monthPeriod(2026, 10),
        calendar: calendar
    )

    #expect(summary.totalSpend == money("50.00"))
    #expect(summary.totalIncome == money("1000.00"))
    #expect(summary.transactionCount == 4)
    #expect(summary.categoryTotals.map(\.categoryName) == ["Dining", "Transport"])
    #expect(summary.categoryTotals.map(\.amount) == [money("40.00"), money("10.00")])
    #expect(summary.categoryTotals.map(\.share) == [money("80.00"), money("20.00")])
    #expect(summary.merchantTotals.map(\.merchant) == ["Kopitiam", "Toast Box", "Grab"])
    #expect(
        summary.largestTransactions.map(\.merchant) == ["Acme Payroll", "Kopitiam", "Toast Box", "Grab"]
    )
    #expect(summary.dailySpend.count == 31)
    #expect(summary.dailySpend.reduce(Decimal.zero) { $0 + $1.amount } == money("50.00"))
    #expect(!summary.observations.contains { $0.contains("Savings Transfer") })
}

@Test func categorySharesSumToTheSpendTotal() throws {
    let summary = InsightsCalculator.summary(
        transactions: [
            transaction(10, .debit, try makeDate(2026, 10, 2), merchant: "A", category: "Transport"),
            transaction(10, .debit, try makeDate(2026, 10, 3), merchant: "B", category: "Groceries"),
            transaction(10, .debit, try makeDate(2026, 10, 4), merchant: "C", category: "Dining"),
        ],
        period: try monthPeriod(2026, 10),
        calendar: calendar
    )

    #expect(summary.totalSpend == 30)
    #expect(summary.categoryTotals.reduce(Decimal.zero) { $0 + $1.amount } == summary.totalSpend)
    #expect(summary.categoryTotals.reduce(Decimal.zero) { $0 + $1.share } == 100)
    #expect(summary.categoryTotals.map(\.categoryName) == ["Dining", "Groceries", "Transport"])
    // The rounding remainder is assigned to the largest category so shares always add up to 100.
    #expect(summary.categoryTotals.map(\.share) == [money("33.34"), money("33.33"), money("33.33")])
    #expect(summary.categoryTotals.map(\.transactionCount) == [1, 1, 1])
}

@Test func topMerchantsAreOrderedByAmountThenCount() throws {
    let summary = InsightsCalculator.summary(
        transactions: [
            transaction(10, .debit, try makeDate(2026, 10, 1), merchant: "Grab", category: "Transport"),
            transaction(10, .debit, try makeDate(2026, 10, 2), merchant: "grab ", category: "Transport"),
            transaction(10, .debit, try makeDate(2026, 10, 3), merchant: " GRAB", category: "Transport"),
            transaction(10, .debit, try makeDate(2026, 10, 4), merchant: "Blue Bottle", category: "Dining"),
            transaction(10, .debit, try makeDate(2026, 10, 5), merchant: "Blue Bottle", category: "Dining"),
            transaction(20, .debit, try makeDate(2026, 10, 6), merchant: "Toast Box", category: "Dining"),
            transaction(5, .debit, try makeDate(2026, 10, 7), merchant: "   ", category: "Other"),
        ],
        period: try monthPeriod(2026, 10),
        calendar: calendar
    )

    #expect(
        summary.merchantTotals.map(\.merchant)
            == ["Grab", "Blue Bottle", "Toast Box", "Unknown merchant"]
    )
    #expect(summary.merchantTotals.map(\.amount) == [30, 20, 20, 5])
    #expect(summary.merchantTotals.map(\.transactionCount) == [3, 2, 1, 1])
}

@Test func dailySpendCoversEveryDayAcrossMonthBoundaries() throws {
    let period = InsightsPeriod(
        start: try makeDate(2026, 10, 30, hour: 0),
        end: try makeDate(2026, 11, 2, hour: 23, minute: 59)
    )
    let summary = InsightsCalculator.summary(
        transactions: [
            transaction(5, .debit, try makeDate(2026, 10, 30, hour: 8), merchant: "A", category: "Dining"),
            transaction(3, .debit, try makeDate(2026, 11, 1, hour: 9), merchant: "B", category: "Dining"),
            transaction(2, .debit, try makeDate(2026, 11, 1, hour: 21), merchant: "C", category: "Dining"),
            transaction(9, .credit, try makeDate(2026, 11, 1, hour: 10), merchant: "Pay", category: "Income"),
        ],
        period: period,
        calendar: calendar
    )

    #expect(
        summary.dailySpend.map(\.date) == [
            try makeDate(2026, 10, 30, hour: 0),
            try makeDate(2026, 10, 31, hour: 0),
            try makeDate(2026, 11, 1, hour: 0),
            try makeDate(2026, 11, 2, hour: 0),
        ]
    )
    #expect(summary.dailySpend.map(\.amount) == [5, 0, 5, 0])
    #expect(summary.totalSpend == 10)
    #expect(summary.totalIncome == 9)
}

@Test func largestTransactionsExcludeTransfersAndPreferTheNewestOnTies() throws {
    let summary = InsightsCalculator.summary(
        transactions: [
            transaction(10, .debit, try makeDate(2026, 10, 5), merchant: "Older", category: "Dining"),
            transaction(10, .debit, try makeDate(2026, 10, 10), merchant: "Newer", category: "Dining"),
            transaction(30, .debit, try makeDate(2026, 10, 1), merchant: "Largest", category: "Shopping"),
            transaction(
                30, .debit, try makeDate(2026, 10, 2),
                merchant: "Transfer", category: "Transfers", isTransfer: true
            ),
        ],
        period: try monthPeriod(2026, 10),
        calendar: calendar
    )

    #expect(summary.largestTransactions.map(\.merchant) == ["Largest", "Newer", "Older"])
}

@Test func categoryChangeObservationNeedsBothMonths() throws {
    let septemberDining = transaction(
        100, .debit, try makeDate(2026, 9, 12), merchant: "Kopitiam", category: "Dining"
    )
    let octoberDining = transaction(
        76, .debit, try makeDate(2026, 10, 12), merchant: "Kopitiam", category: "Dining"
    )

    let withBothMonths = InsightsCalculator.summary(
        transactions: [septemberDining, octoberDining],
        period: try monthPeriod(2026, 10),
        calendar: calendar
    )
    let dining = try #require(withBothMonths.categoryTotals.first)
    #expect(dining.amount == 76)
    #expect(dining.previousAmount == 100)
    #expect(dining.changePercent == -24)
    #expect(withBothMonths.observations.contains("Dining is 24% lower than last month."))

    let withOneMonth = InsightsCalculator.summary(
        transactions: [octoberDining],
        period: try monthPeriod(2026, 10),
        calendar: calendar
    )
    let uncomparable = try #require(withOneMonth.categoryTotals.first)
    #expect(uncomparable.previousAmount == 0)
    #expect(uncomparable.changePercent == nil)
    #expect(!withOneMonth.observations.contains { $0.contains("than last month") })
}

@Test func categoryIncreaseIsReported() throws {
    let summary = InsightsCalculator.summary(
        transactions: [
            transaction(100, .debit, try makeDate(2026, 9, 12), merchant: "Kopitiam", category: "Dining"),
            transaction(150, .debit, try makeDate(2026, 10, 12), merchant: "Kopitiam", category: "Dining"),
        ],
        period: try monthPeriod(2026, 10),
        calendar: calendar
    )

    let dining = try #require(summary.categoryTotals.first)
    #expect(dining.changePercent == 50)
    #expect(summary.observations.contains("Dining is 50% higher than last month."))
}

@Test func unchangedCategorySpendIsReportedAsUnchanged() throws {
    let summary = InsightsCalculator.summary(
        transactions: [
            transaction(100, .debit, try makeDate(2026, 9, 12), merchant: "Kopitiam", category: "Dining"),
            transaction(100, .debit, try makeDate(2026, 10, 12), merchant: "Kopitiam", category: "Dining"),
        ],
        period: try monthPeriod(2026, 10),
        calendar: calendar
    )

    let dining = try #require(summary.categoryTotals.first)
    #expect(dining.changePercent == 0)
    #expect(summary.observations.contains("Dining is unchanged from last month."))
}

@Test func sixMonthSeriesEndsWithTheSelectedMonth() throws {
    let summary = InsightsCalculator.summary(
        transactions: [
            transaction(100, .credit, try makeDate(2026, 4, 1), merchant: "April Pay", category: "Income"),
            transaction(5, .debit, try makeDate(2026, 9, 5), merchant: "September Shop", category: "Groceries"),
            transaction(1000, .credit, try makeDate(2026, 10, 1), merchant: "Pay", category: "Income"),
            transaction(20, .debit, try makeDate(2026, 10, 2), merchant: "October Shop", category: "Groceries"),
            transaction(99, .debit, try makeDate(2026, 11, 1), merchant: "November Shop", category: "Groceries"),
        ],
        period: try monthPeriod(2026, 10),
        calendar: calendar
    )

    #expect(summary.monthlyIncomeExpense.count == 6)
    #expect(
        summary.monthlyIncomeExpense.map(\.month) == [
            try makeDate(2026, 5, 1, hour: 0),
            try makeDate(2026, 6, 1, hour: 0),
            try makeDate(2026, 7, 1, hour: 0),
            try makeDate(2026, 8, 1, hour: 0),
            try makeDate(2026, 9, 1, hour: 0),
            try makeDate(2026, 10, 1, hour: 0),
        ]
    )
    #expect(summary.monthlyIncomeExpense.map(\.spend) == [0, 0, 0, 0, 5, 20])
    #expect(summary.monthlyIncomeExpense.map(\.income) == [0, 0, 0, 0, 0, 1000])
    // April and November fall outside the six-month window that ends with the selected month.
    #expect(summary.totalSpend == 20)
    #expect(summary.totalIncome == 1000)
}

@Test func aSingleTransactionStillProducesAFullSummary() throws {
    let summary = InsightsCalculator.summary(
        transactions: [
            transaction(money("12.50"), .debit, try makeDate(2026, 10, 7), merchant: "Kopitiam", category: "Dining"),
        ],
        period: try monthPeriod(2026, 10),
        calendar: calendar
    )

    #expect(summary.totalSpend == money("12.50"))
    #expect(summary.totalIncome == 0)
    #expect(summary.transactionCount == 1)
    let dining = try #require(summary.categoryTotals.first)
    #expect(dining.categoryName == "Dining")
    #expect(dining.amount == money("12.50"))
    #expect(dining.share == 100)
    #expect(summary.merchantTotals.count == 1)
    #expect(summary.merchantTotals.first?.amount == money("12.50"))
    #expect(summary.largestTransactions.count == 1)
    #expect(summary.dailySpend.count == 31)
    #expect(summary.dailySpend.reduce(Decimal.zero) { $0 + $1.amount } == money("12.50"))
    #expect(summary.observations == ["Kopitiam is your top merchant with 1 transaction."])
}

@Test func noTransactionsProducesEmptyBreakdowns() throws {
    let summary = InsightsCalculator.summary(
        transactions: [], period: try monthPeriod(2026, 10), calendar: calendar
    )

    #expect(summary.totalSpend == 0)
    #expect(summary.totalIncome == 0)
    #expect(summary.transactionCount == 0)
    #expect(summary.categoryTotals.isEmpty)
    #expect(summary.merchantTotals.isEmpty)
    #expect(summary.largestTransactions.isEmpty)
    #expect(summary.observations.isEmpty)
    #expect(summary.dailySpend.count == 31)
    #expect(summary.dailySpend.allSatisfy { $0.amount == 0 })
    #expect(summary.monthlyIncomeExpense.count == 6)
    #expect(summary.monthlyIncomeExpense.allSatisfy { $0.income == 0 && $0.spend == 0 })
}

@Test func transfersProduceNoSpendIncomeOrObservations() throws {
    let summary = InsightsCalculator.summary(
        transactions: [
            transaction(
                500, .debit, try makeDate(2026, 10, 3),
                merchant: "Savings Transfer", category: "Transfers", isTransfer: true
            ),
            transaction(
                500, .credit, try makeDate(2026, 10, 3),
                merchant: "Current Transfer", category: "Transfers", isTransfer: true
            ),
        ],
        period: try monthPeriod(2026, 10),
        calendar: calendar
    )

    #expect(summary.totalSpend == 0)
    #expect(summary.totalIncome == 0)
    #expect(summary.transactionCount == 0)
    #expect(summary.categoryTotals.isEmpty)
    #expect(summary.merchantTotals.isEmpty)
    #expect(summary.largestTransactions.isEmpty)
    #expect(summary.observations.isEmpty)
}

@Test func zeroAmountDebitsProduceNoBreakdowns() throws {
    let summary = InsightsCalculator.summary(
        transactions: [
            transaction(0, .debit, try makeDate(2026, 10, 3), merchant: "Kopitiam", category: "Dining"),
        ],
        period: try monthPeriod(2026, 10),
        calendar: calendar
    )

    #expect(summary.totalSpend == 0)
    #expect(summary.transactionCount == 1)
    #expect(summary.categoryTotals.isEmpty)
    #expect(summary.merchantTotals.isEmpty)
    #expect(summary.observations.isEmpty)
}

@Test func resultsDoNotDependOnInputOrder() throws {
    let transactions = [
        transaction(10, .debit, try makeDate(2026, 10, 5), merchant: "Grab", category: "Transport"),
        transaction(10, .debit, try makeDate(2026, 10, 5), merchant: "Grab", category: "Transport"),
        transaction(10, .debit, try makeDate(2026, 10, 5), merchant: "Grab", category: "Transport"),
        transaction(85, .credit, try makeDate(2026, 10, 6), merchant: "Pay", category: "Income"),
        transaction(10, .debit, try makeDate(2026, 9, 5), merchant: "Kopitiam", category: "Dining"),
        transaction(25, .debit, try makeDate(2026, 10, 9), merchant: "Kopitiam", category: "Dining"),
        transaction(25, .debit, try makeDate(2026, 10, 9), merchant: "Kopitiam", category: "Dining"),
        transaction(400, .debit, try makeDate(2026, 10, 10), merchant: "Transfer", category: "Transfers", isTransfer: true),
    ]
    let period = try monthPeriod(2026, 10)
    let forward = InsightsCalculator.summary(transactions: transactions, period: period, calendar: calendar)
    let reversed = InsightsCalculator.summary(
        transactions: Array(transactions.reversed()), period: period, calendar: calendar
    )

    #expect(forward == reversed)
    #expect(forward.dailySpend == reversed.dailySpend)
    #expect(forward.categoryTotals == reversed.categoryTotals)
    #expect(forward.largestTransactions == reversed.largestTransactions)
}

@Test func periodBoundariesAreInclusive() throws {
    let period = try monthPeriod(2026, 10)
    let summary = InsightsCalculator.summary(
        transactions: [
            transaction(1, .debit, period.start, merchant: "At Start", category: "Groceries"),
            transaction(2, .debit, period.end, merchant: "At End", category: "Groceries"),
            transaction(
                4, .debit, period.start.addingTimeInterval(-1),
                merchant: "Before", category: "Groceries"
            ),
            transaction(
                8, .debit, period.end.addingTimeInterval(1),
                merchant: "After", category: "Groceries"
            ),
        ],
        period: period,
        calendar: calendar
    )

    #expect(summary.totalSpend == 3)
    #expect(summary.transactionCount == 2)
    #expect(summary.merchantTotals.map(\.merchant) == ["At End", "At Start"])
}

@Test func reversedPeriodProducesAnEmptySummary() throws {
    let summary = InsightsCalculator.summary(
        transactions: [
            transaction(10, .debit, try makeDate(2026, 10, 5), merchant: "Grab", category: "Transport"),
        ],
        period: InsightsPeriod(start: try makeDate(2026, 10, 31), end: try makeDate(2026, 10, 1)),
        calendar: calendar
    )

    #expect(summary.totalSpend == 0)
    #expect(summary.transactionCount == 0)
    #expect(summary.categoryTotals.isEmpty)
    #expect(summary.merchantTotals.isEmpty)
    #expect(summary.largestTransactions.isEmpty)
    #expect(summary.dailySpend.isEmpty)
    #expect(summary.monthlyIncomeExpense.isEmpty)
    #expect(summary.observations.isEmpty)
}
