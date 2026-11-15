import Foundation
import SwiftData
import Testing
import ZentriCore
@testable import ZentriApp

/// A fixed calendar so the tests' days and months never depend on the machine running them.
private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

/// The instant every test treats as now: midday on 15 March 2026, in the middle of a month.
private let now = date(2026, 3, 15, hour: 12)

/// A date in the calendar the tests and the model share.
private func date(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    hour: Int = 0,
    minute: Int = 0,
    second: Int = 0
) -> Date {
    calendar.date(
        from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
    )!
}

/// Holds the in-memory container for as long as a test uses its context.
@MainActor
private struct Store {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
}

@MainActor
private func makeStore() throws -> Store {
    Store(container: try ZentriContainer.make(inMemory: true))
}

@MainActor
@discardableResult
private func addAccount(in context: ModelContext, name: String = "Everyday", archived: Bool = false) -> Account {
    let account = Account(name: name, sortOrder: 0, createdAt: now, archivedAt: archived ? now : nil)
    context.insert(account)
    return account
}

/// Adds a transaction, creating the category it names when one does not exist yet.
@MainActor
@discardableResult
private func addTransaction(
    in context: ModelContext,
    account: Account,
    amount: Decimal,
    direction: Direction = .debit,
    occurredAt: Date,
    merchant: String,
    categoryName: String? = nil,
    isTransfer: Bool = false
) -> ZentriCore.Transaction {
    let transaction = ZentriCore.Transaction(
        account: account,
        amount: amount,
        direction: direction,
        occurredAt: occurredAt,
        recordedAt: occurredAt,
        merchantRaw: merchant,
        merchantDisplay: merchant,
        category: categoryName.map { category(named: $0, in: context) },
        categorySource: categoryName == nil ? nil : .rule,
        isTransfer: isTransfer
    )
    context.insert(transaction)
    return transaction
}

@MainActor
private func category(named name: String, in context: ModelContext) -> ZentriCore.Category {
    let existing = try? context.fetch(FetchDescriptor<ZentriCore.Category>())
    if let match = existing?.first(where: { $0.name == name }) {
        return match
    }
    let category = ZentriCore.Category(name: name, symbolName: "tag", colorToken: "slate", sortOrder: 0)
    context.insert(category)
    return category
}

@MainActor
private func makeModel(in context: ModelContext) -> InsightsModel {
    InsightsModel(context: context, now: { now }, calendar: calendar)
}

/// The failure a substituted read throws, standing in for a store a healthy test container cannot
/// produce.
private struct ReadFailure: Error {}

/// An account read that throws until it is told the store answers again.
@MainActor
private final class FlakyAccounts {
    var isFailing = true
    private let real: @MainActor () throws -> [Account]

    init(real: @escaping @MainActor () throws -> [Account]) {
        self.real = real
    }

    func accounts() throws -> [Account] {
        guard !isFailing else { throw ReadFailure() }
        return try real()
    }
}

// MARK: - Months

@MainActor
@Test func theModelStartsOnTheExactCalendarMonthContainingNow() throws {
    let store = try makeStore()
    addAccount(in: store.context)
    try store.context.save()

    let model = makeModel(in: store.context)
    model.refresh()

    #expect(model.loadState == .loaded)
    #expect(model.selectedMonth == date(2026, 3, 1))
    #expect(model.isShowingThisMonth)
    let period = try #require(model.summary).period
    // The whole month, ending at its last instant rather than at the next month's first, which is
    // the shape the calculator needs to compare with the previous month.
    #expect(period.start == date(2026, 3, 1))
    #expect(period.end == date(2026, 3, 31, hour: 23, minute: 59, second: 59))
}

@MainActor
@Test func theSummaryCoversOnlyTheSelectedMonthAndComparesItWithThePreviousOne() throws {
    let store = try makeStore()
    let context = store.context
    let account = addAccount(in: context)
    addTransaction(in: context, account: account, amount: 120, occurredAt: date(2026, 3, 1), merchant: "Cafe", categoryName: "Dining")
    addTransaction(in: context, account: account, amount: 80, occurredAt: date(2026, 3, 31, hour: 23, minute: 59, second: 59), merchant: "Cafe", categoryName: "Dining")
    addTransaction(in: context, account: account, amount: 400, occurredAt: date(2026, 2, 28, hour: 23, minute: 59, second: 59), merchant: "Cafe", categoryName: "Dining")
    addTransaction(in: context, account: account, amount: 999, occurredAt: date(2026, 4, 1), merchant: "Next month", categoryName: "Dining")
    try context.save()

    let model = makeModel(in: context)
    model.refresh()

    let summary = try #require(model.summary)
    #expect(summary.totalSpend == 200)
    let dining = try #require(summary.categoryTotals.first)
    #expect(dining.previousAmount == 400)
    #expect(dining.changePercent == -50)
}

@MainActor
@Test func previousAndNextMonthMoveTheSummaryAndStopAtThisMonth() throws {
    let store = try makeStore()
    let context = store.context
    let account = addAccount(in: context)
    addTransaction(in: context, account: account, amount: 100, occurredAt: date(2026, 3, 2), merchant: "March")
    addTransaction(in: context, account: account, amount: 40, occurredAt: date(2026, 2, 10), merchant: "February")
    addTransaction(in: context, account: account, amount: 7, occurredAt: date(2025, 12, 31, hour: 22), merchant: "December")
    try context.save()

    let model = makeModel(in: context)
    model.refresh()

    model.previousMonth()
    #expect(model.selectedMonth == date(2026, 2, 1))
    #expect(!model.isShowingThisMonth)
    #expect(try #require(model.summary).totalSpend == 40)
    #expect(try #require(model.summary).period.end == date(2026, 2, 28, hour: 23, minute: 59, second: 59))

    // Across the year boundary.
    model.previousMonth()
    model.previousMonth()
    #expect(model.selectedMonth == date(2025, 12, 1))
    #expect(try #require(model.summary).totalSpend == 7)

    model.nextMonth()
    #expect(model.selectedMonth == date(2026, 1, 1))
    #expect(try #require(model.summary).totalSpend == 0)

    model.thisMonth()
    #expect(model.selectedMonth == date(2026, 3, 1))
    #expect(model.isShowingThisMonth)
    #expect(try #require(model.summary).totalSpend == 100)

    // A month that has not started has nothing to show, so the selection stops at this month.
    model.nextMonth()
    #expect(model.selectedMonth == date(2026, 3, 1))
    #expect(try #require(model.summary).totalSpend == 100)
}

// MARK: - Store reads

@MainActor
@Test func aFailedReadIsAFailureAndNotAnEmptyMonth() throws {
    let store = try makeStore()
    let context = store.context
    let account = addAccount(in: context)
    addTransaction(in: context, account: account, amount: 100, occurredAt: date(2026, 3, 2), merchant: "Cafe")
    try context.save()
    let real = InsightsStoreReads(context: context)
    let flaky = FlakyAccounts(real: real.accounts)

    let model = InsightsModel(
        reads: InsightsStoreReads(accounts: flaky.accounts, categories: real.categories),
        now: { now },
        calendar: calendar
    )
    model.refresh()

    #expect(model.loadState == .failed)
    #expect(model.summary == nil)
    #expect(model.largestSpends.isEmpty)
    #expect(model.observations.isEmpty)

    flaky.isFailing = false
    model.refresh()

    #expect(model.loadState == .loaded)
    #expect(try #require(model.summary).totalSpend == 100)
}

@MainActor
@Test func aCatalogThatCannotBeReadStillShowsTheMonth() throws {
    let store = try makeStore()
    let context = store.context
    let account = addAccount(in: context)
    addTransaction(in: context, account: account, amount: 100, occurredAt: date(2026, 3, 2), merchant: "Cafe")
    try context.save()
    let real = InsightsStoreReads(context: context)

    let model = InsightsModel(
        reads: InsightsStoreReads(accounts: real.accounts, categories: { throw ReadFailure() }),
        now: { now },
        calendar: calendar
    )
    model.refresh()

    #expect(model.loadState == .loaded)
    let other = try #require(model.summary?.categoryTotals.first)
    #expect(other.categoryName == "Other")
    #expect(other.amount == 100)
}

@MainActor
@Test func refreshingTheInsightsPicksUpWhateverChangedInTheStore() throws {
    let store = try makeStore()
    let context = store.context
    let account = addAccount(in: context)
    addTransaction(in: context, account: account, amount: 100, occurredAt: date(2026, 3, 2), merchant: "Cafe")
    try context.save()

    let model = makeModel(in: context)
    model.refresh()
    #expect(try #require(model.summary).totalSpend == 100)

    addTransaction(in: context, account: account, amount: 50, occurredAt: date(2026, 3, 3), merchant: "Bakery")
    try context.save()
    model.refresh()

    #expect(try #require(model.summary).totalSpend == 150)
}

@MainActor
@Test func archivedAccountsAreLeftOutLikeOnTheOverview() throws {
    let store = try makeStore()
    let context = store.context
    let account = addAccount(in: context)
    let archived = addAccount(in: context, name: "Old", archived: true)
    addTransaction(in: context, account: account, amount: 100, occurredAt: date(2026, 3, 2), merchant: "Cafe")
    addTransaction(in: context, account: archived, amount: 700, occurredAt: date(2026, 3, 2), merchant: "Old Cafe")
    try context.save()

    let model = makeModel(in: context)
    model.refresh()

    #expect(try #require(model.summary).totalSpend == 100)
}

// MARK: - Lists and observations

@MainActor
@Test func theLargestSpendsLeaveOutIncome() throws {
    let store = try makeStore()
    let context = store.context
    let account = addAccount(in: context)
    addTransaction(in: context, account: account, amount: 5_000, direction: .credit, occurredAt: date(2026, 3, 1), merchant: "Employer")
    addTransaction(in: context, account: account, amount: 1_200, occurredAt: date(2026, 3, 2), merchant: "Rent")
    addTransaction(in: context, account: account, amount: 80, occurredAt: date(2026, 3, 3), merchant: "Market")
    try context.save()

    let model = makeModel(in: context)
    model.refresh()

    #expect(model.largestSpends.map(\.merchant) == ["Rent", "Market"])
}

@MainActor
@Test func theObservationsCompareCategoriesNameThePeakDayAndTheTopMerchant() throws {
    let store = try makeStore()
    let context = store.context
    let account = addAccount(in: context)
    // March so far: 15 days with 40 spent, an average of 2.67 a day, of which 30 was on the 2nd.
    addTransaction(in: context, account: account, amount: 30, occurredAt: date(2026, 3, 2, hour: 9), merchant: "Grab", categoryName: "Transport")
    addTransaction(in: context, account: account, amount: 10, occurredAt: date(2026, 3, 10), merchant: "Cafe", categoryName: "Dining")
    addTransaction(in: context, account: account, amount: 20, occurredAt: date(2026, 2, 10), merchant: "Cafe", categoryName: "Dining")
    addTransaction(in: context, account: account, amount: 20, occurredAt: date(2026, 2, 11), merchant: "Bus", categoryName: "Transport")
    try context.save()

    let model = makeModel(in: context)
    model.refresh()

    // The average only counts the days that have happened, so the peak is 11.3× it, not 23.3×.
    #expect(
        model.observations == [
            .categoryChange(categoryName: "Transport", wholePercent: 50),
            .categoryChange(categoryName: "Dining", wholePercent: -50),
            .peakDay(date: date(2026, 3, 2), ratio: Decimal(string: "11.3")!),
            .topMerchant(merchant: "Grab", transactionCount: 1),
        ]
    )
}

@Test func aPeakDayCloseToTheAverageIsNotWorthAnObservation() {
    let period = InsightsPeriod(start: date(2026, 3, 1), end: date(2026, 3, 31, hour: 23, minute: 59, second: 59))
    let summary = InsightsSummary.empty(period: period)
    let ordinary = PeakDaySpend(date: date(2026, 3, 2), amount: 19, averageDailySpend: 10, ratioToAverage: Decimal(string: "1.9")!)
    let notable = PeakDaySpend(date: date(2026, 3, 2), amount: 20, averageDailySpend: 10, ratioToAverage: 2)

    #expect(InsightsObservation.observations(summary: summary, peakDay: ordinary).isEmpty)
    #expect(InsightsObservation.observations(summary: summary, peakDay: notable) == [.peakDay(date: date(2026, 3, 2), ratio: 2)])
}

// MARK: - Drill-down

@MainActor
@Test func aCategoryOpensTheSelectedMonthsSpendInThatCategory() throws {
    let store = try makeStore()
    let context = store.context
    let account = addAccount(in: context)
    addTransaction(in: context, account: account, amount: 40, occurredAt: date(2026, 2, 10), merchant: "Cafe", categoryName: "Dining")
    try context.save()

    let model = makeModel(in: context)
    model.refresh()
    model.previousMonth()
    let dining = try #require(model.summary?.categoryTotals.first)

    let filter = try #require(model.transactionFilter(for: dining))

    #expect(filter.categoryID == category(named: "Dining", in: context).id)
    #expect(filter.direction == .debit)
    #expect(filter.dateRange == date(2026, 2, 1)...date(2026, 2, 28, hour: 23, minute: 59, second: 59))
    #expect(filter.searchText.isEmpty)
    #expect(filter.accountID == nil)
}

@MainActor
@Test func aMerchantOpensTheSelectedMonthsSpendSearchedByName() throws {
    let store = try makeStore()
    addAccount(in: store.context)
    try store.context.save()

    let model = makeModel(in: store.context)
    model.refresh()

    let filter = model.transactionFilter(forMerchant: "Grab")

    #expect(filter.searchText == "Grab")
    #expect(filter.categoryID == nil)
    #expect(filter.direction == .debit)
    #expect(filter.dateRange == date(2026, 3, 1)...date(2026, 3, 31, hour: 23, minute: 59, second: 59))
}
