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

/// Wraps an in-memory container so the tests can hold it for as long as they use its context.
///
/// A context keeps its container alive only for the duration of `mainContext`'s caller, so a test
/// that returns the context alone would be left inserting into a deallocated store.
@MainActor
private struct Store {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
}

@MainActor
private func makeStore() throws -> Store {
    Store(container: try ZentriContainer.make(inMemory: true))
}

/// Adds an account, and an opening checkpoint when a balance is supplied.
@MainActor
@discardableResult
private func addAccount(
    in context: ModelContext,
    name: String = "Everyday",
    archived: Bool = false,
    openingBalance: Decimal? = nil,
    openingAt: Date? = nil
) -> Account {
    let account = Account(
        name: name,
        sortOrder: 0,
        createdAt: now,
        archivedAt: archived ? now : nil
    )
    context.insert(account)
    if let openingBalance, let openingAt {
        context.insert(
            BalanceCheckpoint(
                account: account,
                amount: openingBalance,
                recordedAt: openingAt,
                source: .opening,
                createdAt: openingAt
            )
        )
    }
    return account
}

/// Adds a transaction, creating the category it names when one does not exist yet.
@MainActor
@discardableResult
private func addTransaction(
    in context: ModelContext,
    account: Account,
    amount: Decimal,
    direction: Direction,
    occurredAt: Date,
    recordedAt: Date = now,
    merchant: String,
    categoryName: String? = nil,
    isTransfer: Bool = false
) -> ZentriCore.Transaction {
    let transaction = ZentriCore.Transaction(
        account: account,
        amount: amount,
        direction: direction,
        occurredAt: occurredAt,
        recordedAt: recordedAt,
        merchantRaw: merchant,
        merchantDisplay: merchant,
        category: categoryName.map { category(named: $0, in: context) },
        categorySource: categoryName == nil ? nil : .rule,
        isTransfer: isTransfer
    )
    context.insert(transaction)
    return transaction
}

/// The category with the supplied name, created on first use.
@MainActor
private func category(named name: String, in context: ModelContext) -> ZentriCore.Category {
    let existing = try? context.fetch(FetchDescriptor<ZentriCore.Category>())
    if let match = existing?.first(where: { $0.name == name }) {
        return match
    }
    let category = ZentriCore.Category(
        name: name,
        symbolName: "tag",
        colorToken: "slate",
        sortOrder: 0
    )
    context.insert(category)
    return category
}

@MainActor
private func addMessage(
    in context: ModelContext,
    receivedAt: Date,
    ingestedAt: Date,
    status: ParseStatus
) {
    context.insert(
        RawMessage(
            text: "A bank message",
            receivedAt: receivedAt,
            ingestedAt: ingestedAt,
            status: status,
            fingerprint: UUID().uuidString
        )
    )
}

@MainActor
private func makeModel(in context: ModelContext) -> OverviewModel {
    OverviewModel(context: context, now: { now }, calendar: calendar)
}

@MainActor
@Test func theBalanceAnchorsOnTheNewestCheckpointOfTheActiveAccounts() throws {
    let store = try makeStore()
    let context = store.context
    let account = addAccount(in: context, openingBalance: 1_000_000, openingAt: date(2026, 3, 10))
    addTransaction(in: context, account: account, amount: 250, direction: .debit, occurredAt: now, merchant: "Cafe")
    addTransaction(in: context, account: account, amount: 5_000, direction: .credit, occurredAt: now, merchant: "Employer")
    let archived = addAccount(in: context, name: "Old", archived: true, openingBalance: 900, openingAt: date(2026, 3, 10))
    addTransaction(in: context, account: archived, amount: 700, direction: .debit, occurredAt: now, merchant: "Old Cafe")
    try context.save()

    let model = makeModel(in: context)
    model.refresh()

    let summary = try #require(model.summary)
    #expect(summary.balance == 1_004_750)
    #expect(summary.asOf == date(2026, 3, 10))
}

@MainActor
@Test func theNewestCheckpointWinsAndOnlyLaterTransactionsApply() throws {
    let store = try makeStore()
    let context = store.context
    let account = addAccount(in: context, openingBalance: 1_000, openingAt: date(2026, 3, 1))
    // A balance read on the 10th supersedes the opening one, so the debit on the 5th is already
    // inside it and only the debit on the 12th moves the balance.
    context.insert(
        BalanceCheckpoint(
            account: account,
            amount: 20_000,
            recordedAt: date(2026, 3, 10),
            source: .sms,
            createdAt: date(2026, 3, 10)
        )
    )
    addTransaction(
        in: context, account: account, amount: 100, direction: .debit,
        occurredAt: date(2026, 3, 5), recordedAt: date(2026, 3, 5), merchant: "Before the checkpoint"
    )
    addTransaction(
        in: context, account: account, amount: 300, direction: .debit,
        occurredAt: date(2026, 3, 12), recordedAt: date(2026, 3, 12), merchant: "After the checkpoint"
    )
    try context.save()

    let model = makeModel(in: context)
    model.refresh()

    let summary = try #require(model.summary)
    #expect(summary.balance == 19_700)
    #expect(summary.asOf == date(2026, 3, 10))
}

@MainActor
@Test func refreshingAgainPicksUpWhateverChangedInTheStore() throws {
    let store = try makeStore()
    let context = store.context
    let account = addAccount(in: context, openingBalance: 1_000, openingAt: date(2026, 3, 1))
    addTransaction(in: context, account: account, amount: 100, direction: .debit, occurredAt: now, merchant: "Cafe")
    try context.save()

    let model = makeModel(in: context)
    model.refresh()
    #expect(try #require(model.summary).todaySpend == 100)

    addTransaction(in: context, account: account, amount: 50, direction: .debit, occurredAt: now, merchant: "Bakery")
    try context.save()
    model.refresh()

    #expect(try #require(model.summary).todaySpend == 150)
    #expect(try #require(model.summary).balance == 850)
}

@MainActor
@Test func withoutACheckpointTheBalanceIsZeroAndTheAsOfFallsBackToNow() throws {
    let store = try makeStore()
    let context = store.context
    let account = addAccount(in: context)
    addTransaction(in: context, account: account, amount: 250, direction: .debit, occurredAt: now, merchant: "Cafe")
    try context.save()

    let model = makeModel(in: context)
    model.refresh()

    let summary = try #require(model.summary)
    #expect(summary.balance == 0)
    #expect(summary.asOf == now)
}

@MainActor
@Test func todaySpendCountsOnlyTodaysNonTransferDebits() throws {
    let store = try makeStore()
    let context = store.context
    let account = addAccount(in: context, openingBalance: 1_000, openingAt: date(2026, 3, 1))
    addTransaction(in: context, account: account, amount: 100, direction: .debit, occurredAt: date(2026, 3, 15, hour: 9), merchant: "Cafe")
    addTransaction(in: context, account: account, amount: 40, direction: .debit, occurredAt: date(2026, 3, 14, hour: 20), merchant: "Yesterday")
    addTransaction(in: context, account: account, amount: 500, direction: .credit, occurredAt: date(2026, 3, 15, hour: 10), merchant: "Employer")
    addTransaction(in: context, account: account, amount: 999, direction: .debit, occurredAt: date(2026, 3, 15, hour: 11), merchant: "Savings", isTransfer: true)
    try context.save()

    let model = makeModel(in: context)
    model.refresh()

    #expect(try #require(model.summary).todaySpend == 100)
}

@MainActor
@Test func monthTotalsCoverTheExactCalendarMonth() throws {
    let store = try makeStore()
    let context = store.context
    let account = addAccount(in: context, openingBalance: 1_000, openingAt: date(2026, 3, 1))
    addTransaction(in: context, account: account, amount: 120, direction: .debit, occurredAt: date(2026, 3, 1), merchant: "First instant")
    addTransaction(in: context, account: account, amount: 80, direction: .debit, occurredAt: date(2026, 3, 31, hour: 23, minute: 59, second: 59), merchant: "Last instant")
    addTransaction(in: context, account: account, amount: 70, direction: .debit, occurredAt: date(2026, 2, 28, hour: 23, minute: 59, second: 59), merchant: "Previous month")
    addTransaction(in: context, account: account, amount: 500, direction: .credit, occurredAt: date(2026, 3, 5), merchant: "Employer")
    addTransaction(in: context, account: account, amount: 300, direction: .debit, occurredAt: date(2026, 3, 6), merchant: "Savings", isTransfer: true)
    try context.save()

    let model = makeModel(in: context)
    model.refresh()

    let summary = try #require(model.summary)
    #expect(summary.monthSpend == 200)
    #expect(summary.monthIncome == 500)
    #expect(summary.monthNet == 300)
}

@MainActor
@Test func theTopCategoriesAreTheMonthSummariesFirstThree() throws {
    let store = try makeStore()
    let context = store.context
    let account = addAccount(in: context, openingBalance: 1_000, openingAt: date(2026, 3, 1))
    addTransaction(in: context, account: account, amount: 100, direction: .debit, occurredAt: date(2026, 3, 2), merchant: "Cafe", categoryName: "Dining")
    addTransaction(in: context, account: account, amount: 120, direction: .debit, occurredAt: date(2026, 3, 3), merchant: "Market", categoryName: "Groceries")
    addTransaction(in: context, account: account, amount: 80, direction: .debit, occurredAt: date(2026, 3, 4), merchant: "Bus", categoryName: "Transport")
    addTransaction(in: context, account: account, amount: 60, direction: .debit, occurredAt: date(2026, 3, 5), merchant: "Shop", categoryName: "Shopping")
    try context.save()

    let model = makeModel(in: context)
    model.refresh()

    let categories = try #require(model.summary).topCategories
    #expect(categories.map(\.categoryName) == ["Groceries", "Dining", "Transport"])
    #expect(categories.map(\.amount) == [120, 100, 80])
}

@MainActor
@Test func theRecentListIsTheFiveNewestTransactionsAndKeepsTransfers() throws {
    let store = try makeStore()
    let context = store.context
    let account = addAccount(in: context, openingBalance: 1_000, openingAt: date(2026, 3, 1))
    for day in 1...5 {
        addTransaction(
            in: context,
            account: account,
            amount: Decimal(day * 10),
            direction: .debit,
            occurredAt: date(2026, 3, day),
            merchant: "Merchant \(day)"
        )
    }
    addTransaction(in: context, account: account, amount: 999, direction: .debit, occurredAt: date(2026, 3, 6), merchant: "Savings", isTransfer: true)
    let archived = addAccount(in: context, name: "Old", archived: true)
    addTransaction(in: context, account: archived, amount: 5, direction: .debit, occurredAt: date(2026, 3, 7), merchant: "Old Merchant")
    try context.save()

    let model = makeModel(in: context)
    model.refresh()

    let recent = try #require(model.summary).recentTransactions
    #expect(recent.map(\.merchant) == ["Savings", "Merchant 5", "Merchant 4", "Merchant 3", "Merchant 2"])
    let transfer = try #require(recent.first)
    #expect(transfer.isTransfer)
}

@MainActor
@Test func transactionsOccurringAtTheSameInstantAreOrderedByIdentity() throws {
    let store = try makeStore()
    let context = store.context
    let account = addAccount(in: context, openingBalance: 1_000, openingAt: date(2026, 3, 1))
    let first = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let second = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    for (id, merchant) in [(second, "Second"), (first, "First")] {
        context.insert(
            ZentriCore.Transaction(
                id: id,
                account: account,
                amount: 10,
                direction: .debit,
                occurredAt: date(2026, 3, 4),
                recordedAt: now,
                merchantRaw: merchant,
                merchantDisplay: merchant
            )
        )
    }
    try context.save()

    let model = makeModel(in: context)
    model.refresh()

    #expect(try #require(model.summary).recentTransactions.map(\.merchant) == ["First", "Second"])
}

@MainActor
@Test func theSevenDayWindowEndsToday() throws {
    let store = try makeStore()
    let context = store.context
    let account = addAccount(in: context, openingBalance: 1_000, openingAt: date(2026, 3, 1))
    addTransaction(in: context, account: account, amount: 100, direction: .debit, occurredAt: date(2026, 3, 15, hour: 9), merchant: "Today")
    addTransaction(in: context, account: account, amount: 40, direction: .debit, occurredAt: date(2026, 3, 9), merchant: "First day")
    addTransaction(in: context, account: account, amount: 20, direction: .debit, occurredAt: date(2026, 3, 8, hour: 23, minute: 59), merchant: "Before the window")
    try context.save()

    let model = makeModel(in: context)
    model.refresh()

    let days = try #require(model.summary).sevenDaySpend
    #expect(days.map(\.date) == (9...15).map { date(2026, 3, $0) })
    #expect(days.map(\.amount) == [40, 0, 0, 0, 0, 0, 100])
}

@MainActor
@Test func healthReportsTheNewestMessageTheNewestSuccessAndTheFailureCount() throws {
    let store = try makeStore()
    let context = store.context
    addAccount(in: context, openingBalance: 1_000, openingAt: date(2026, 3, 1))
    addMessage(in: context, receivedAt: date(2026, 3, 10, hour: 8), ingestedAt: date(2026, 3, 10, hour: 9), status: .parsed)
    addMessage(in: context, receivedAt: date(2026, 3, 12, hour: 8), ingestedAt: date(2026, 3, 12, hour: 9), status: .failed)
    addMessage(in: context, receivedAt: date(2026, 3, 14, hour: 8), ingestedAt: date(2026, 3, 14, hour: 9), status: .failed)
    addMessage(in: context, receivedAt: date(2026, 3, 13, hour: 8), ingestedAt: date(2026, 3, 13, hour: 9), status: .duplicate)
    addMessage(in: context, receivedAt: date(2026, 3, 11, hour: 8), ingestedAt: date(2026, 3, 11, hour: 9), status: .ignored)
    try context.save()

    let model = makeModel(in: context)
    model.refresh()

    let health = try #require(model.summary).health
    #expect(health.lastMessageAt == date(2026, 3, 14, hour: 8))
    #expect(health.lastSuccessAt == date(2026, 3, 10, hour: 9))
    #expect(health.failureCount == 2)
}

@MainActor
@Test func anUncategorizedTransactionIsCountedUnderTheLiveFallbackCategory() throws {
    let store = try makeStore()
    let context = store.context
    // Distinct from every `TransactionSnapshot` default, so the assertions below can only pass if
    // the model read this row from the catalog instead of falling back to the written-out values.
    let other = ZentriCore.Category(
        name: CategorizationService.fallbackCategoryName,
        symbolName: "dot.radiowaves.left.and.right",
        colorToken: "amber",
        sortOrder: 0,
        isSystem: true
    )
    context.insert(other)
    let account = addAccount(in: context, openingBalance: 1_000, openingAt: date(2026, 3, 1))
    addTransaction(in: context, account: account, amount: 75, direction: .debit, occurredAt: now, merchant: "Unknown")
    try context.save()

    let model = makeModel(in: context)
    model.refresh()

    let category = try #require(model.summary?.topCategories.first)
    #expect(category.categoryName == CategorizationService.fallbackCategoryName)
    #expect(category.categoryID == other.id)
    #expect(category.symbolName == "dot.radiowaves.left.and.right")
    #expect(category.colorToken == "amber")
    let recent = try #require(model.summary?.recentTransactions.first)
    #expect(recent.merchant == "Unknown")
    #expect(recent.categoryName == CategorizationService.fallbackCategoryName)
    #expect(recent.symbolName == "dot.radiowaves.left.and.right")
    #expect(recent.colorToken == "amber")
}

@MainActor
@Test func noActiveAccountLeavesTheSummaryEmpty() throws {
    let store = try makeStore()
    let context = store.context
    addAccount(in: context, name: "Old", archived: true, openingBalance: 900, openingAt: date(2026, 3, 1))
    try context.save()

    let model = makeModel(in: context)
    model.refresh()

    #expect(model.summary == nil)
}
