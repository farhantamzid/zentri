import Foundation
import Testing
@testable import ZentriCore

/// 2026-11-18 11:06:40 UTC.
private let displayNow = Date(timeIntervalSince1970: 1_795_000_000)

private func displayCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return calendar
}

private func usd(_ grouping: NumberGrouping = .western) -> MoneyFormat {
    MoneyFormat(currencyCode: "USD", grouping: grouping, locale: Locale(identifier: "en_US"))
}

/// A snapshot with every list one longer than the widgets show, so the caps are exercised.
private func makeSnapshot(
    balance: String = "1000000",
    todaySpend: String = "82.4",
    trend: [String] = (1...30).map { String($0) },
    recentCount: Int = 7,
    categoryCount: Int = 5
) -> WidgetSnapshot {
    let calendar = displayCalendar()
    let today = calendar.startOfDay(for: displayNow)
    let points = trend.enumerated().map { offset, spend in
        WidgetSnapshot.TrendPoint(
            date: calendar.date(byAdding: .day, value: offset - (trend.count - 1), to: today) ?? today,
            spend: spend
        )
    }
    let recent = (0..<recentCount).map { index in
        WidgetSnapshot.RecentTransaction(
            id: UUID(),
            merchant: "Merchant \(index)",
            categoryName: "Dining",
            symbolName: "fork.knife",
            colorToken: "coral",
            amount: "12.5",
            direction: index == 1 ? .credit : .debit,
            occurredAt: displayNow.addingTimeInterval(TimeInterval(-index * 60))
        )
    }
    let categories = (0..<categoryCount).map { index in
        WidgetSnapshot.TopCategory(
            name: "Category \(index)",
            symbolName: "cart",
            colorToken: "green",
            amount: "1500",
            share: "20"
        )
    }
    return WidgetSnapshot(
        generatedAt: displayNow,
        currencyCode: "USD",
        numberGrouping: .western,
        balance: balance,
        balanceAsOf: displayNow,
        todaySpend: todaySpend,
        monthSpend: "1234.5",
        monthIncome: "5000",
        trend: points,
        recentTransactions: recent,
        topCategories: categories
    )
}

// MARK: - Amount text

@Test func snapshotAmountsParseInvariantlyAndRejectGarbage() {
    #expect(WidgetSnapshot.decimal(from: "-12.5") == Decimal(sign: .minus, exponent: -1, significand: 125))
    #expect(WidgetSnapshot.decimal(from: "1000000") == Decimal(1_000_000))
    #expect(WidgetSnapshot.decimal(from: "0") == Decimal.zero)
    #expect(WidgetSnapshot.decimal(from: "") == nil)
    #expect(WidgetSnapshot.decimal(from: "12abc") == nil)
    #expect(WidgetSnapshot.decimal(from: "1,000") == nil)
    #expect(WidgetSnapshot.decimal(from: "12,5") == nil)
}

// MARK: - Formatting

@Test func amountsCarryTheSnapshotsWesternGrouping() throws {
    let model = try #require(WidgetDisplayModel(snapshot: makeSnapshot(), hideAmounts: false, moneyFormat: usd()))

    #expect(model.balance == "$1,000,000.00")
    #expect(model.todaySpend == "$82.40")
    #expect(model.monthSpend == "$1,234.50")
    #expect(model.monthIncome == "$5,000.00")
    #expect(model.amountsHidden == false)
    #expect(model.isPlaceholder == false)
}

@Test func amountsCarryIndianGrouping() throws {
    let format = MoneyFormat(currencyCode: "BDT", grouping: .indian, locale: Locale(identifier: "en_US"))
    let model = try #require(WidgetDisplayModel(snapshot: makeSnapshot(), hideAmounts: false, moneyFormat: format))

    #expect(model.balance == "৳10,00,000.00")
}

@Test func loadFormatsWithTheSnapshotsOwnCurrencyAndGrouping() throws {
    var snapshot = makeSnapshot()
    snapshot.currencyCode = "INR"
    snapshot.numberGrouping = .indian
    let url = FileManager.default.temporaryDirectory.appending(path: "widget-display-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = FileWidgetSnapshotStore(fileURL: url)
    try store.write(snapshot)

    let model = try #require(WidgetDisplayModel.load(from: store, hideAmounts: false, locale: Locale(identifier: "en_US")))

    #expect(model.balance == "₹10,00,000.00")
}

@Test func negativeBalanceLeadsWithItsSign() throws {
    let model = try #require(
        WidgetDisplayModel(snapshot: makeSnapshot(balance: "-1234.5"), hideAmounts: false, moneyFormat: usd())
    )

    #expect(model.balance == "-$1,234.50")
    #expect(model.isBalanceNegative)
}

// MARK: - Hidden amounts

@Test func hidingAmountsRedactsEveryMonetaryStringButKeepsLabelsAndLayout() throws {
    let snapshot = makeSnapshot(balance: "-50")
    let shown = try #require(WidgetDisplayModel(snapshot: snapshot, hideAmounts: false, moneyFormat: usd()))
    let hidden = try #require(WidgetDisplayModel(snapshot: snapshot, hideAmounts: true, moneyFormat: usd()))
    let mask = WidgetDisplayModel.hiddenAmount

    #expect(hidden.amountsHidden)
    #expect(hidden.balance == mask)
    #expect(hidden.todaySpend == mask)
    #expect(hidden.monthSpend == mask)
    #expect(hidden.monthIncome == mask)
    // The sign is money too: a hidden balance must not turn red.
    #expect(hidden.isBalanceNegative == false)

    let shownTrend = shown.trend(days: 7)
    let hiddenTrend = hidden.trend(days: 7)
    #expect(hiddenTrend.total == mask)
    #expect(hiddenTrend.bars.allSatisfy { $0.amount == mask })
    #expect(hiddenTrend.bars.map(\.date) == shownTrend.bars.map(\.date))
    #expect(hiddenTrend.bars.map(\.spend) == shownTrend.bars.map(\.spend))

    #expect(hidden.recentRows.allSatisfy { $0.amount == mask && $0.spokenAmount == mask })
    #expect(hidden.recentRows.map(\.merchant) == shown.recentRows.map(\.merchant))
    #expect(hidden.recentRows.map(\.isCredit) == shown.recentRows.map(\.isCredit))

    #expect(hidden.categoryRows.allSatisfy { $0.amount == mask })
    #expect(hidden.categoryRows.map(\.name) == shown.categoryRows.map(\.name))
    #expect(hidden.categoryRows.map(\.share) == shown.categoryRows.map(\.share))
}

// MARK: - Lists

@Test func recentRowsKeepTheSnapshotOrderCapAtSixAndSignByDirection() throws {
    let snapshot = makeSnapshot(recentCount: 7)
    let model = try #require(WidgetDisplayModel(snapshot: snapshot, hideAmounts: false, moneyFormat: usd()))

    #expect(model.recentRows.count == 6)
    #expect(model.recentRows.map(\.id) == snapshot.recentTransactions.prefix(6).map(\.id))
    #expect(model.recentRows[0].amount == "-$12.50")
    #expect(model.recentRows[0].spokenAmount == "$12.50")
    #expect(model.recentRows[1].amount == "$12.50")
    #expect(model.recentRows[1].isCredit)
}

@Test func categoryRowsCapAtFourAndKeepUnnormalizedShares() throws {
    let model = try #require(
        WidgetDisplayModel(snapshot: makeSnapshot(categoryCount: 5), hideAmounts: false, moneyFormat: usd())
    )

    #expect(model.categoryRows.map(\.name) == ["Category 0", "Category 1", "Category 2", "Category 3"])
    #expect(model.categoryRows.allSatisfy { $0.share == 0.2 })
    #expect(model.categoryRows[0].amount == "$1,500.00")
}

@Test func emptyListsStayEmpty() throws {
    let model = try #require(WidgetDisplayModel(
        snapshot: makeSnapshot(balance: "0", todaySpend: "0", trend: [], recentCount: 0, categoryCount: 0),
        hideAmounts: false,
        moneyFormat: usd()
    ))

    #expect(model.balance == "$0.00")
    #expect(model.recentRows.isEmpty)
    #expect(model.categoryRows.isEmpty)
    let trend = model.trend(days: 7)
    #expect(trend.bars.isEmpty)
    #expect(trend.total == "$0.00")
    #expect(trend.hasSpend == false)
}

// MARK: - Trend

@Test func trendServesTheLastSevenOrThirtyDays() throws {
    let model = try #require(WidgetDisplayModel(snapshot: makeSnapshot(), hideAmounts: false, moneyFormat: usd()))

    let week = model.trend(days: 7)
    #expect(week.bars.map(\.spend) == [24, 25, 26, 27, 28, 29, 30])
    #expect(week.total == "$189.00")
    #expect(week.hasSpend)

    let month = model.trend(days: 30)
    #expect(month.bars.count == 30)
    #expect(month.total == "$465.00")
}

// MARK: - Missing, corrupt, and placeholder

@Test func missingOrCorruptSnapshotsLoadAsNil() throws {
    #expect(WidgetDisplayModel.load(from: FileWidgetSnapshotStore(fileURL: nil), hideAmounts: false) == nil)

    let url = FileManager.default.temporaryDirectory.appending(path: "widget-display-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = FileWidgetSnapshotStore(fileURL: url)
    #expect(WidgetDisplayModel.load(from: store, hideAmounts: false) == nil)

    try Data("not json".utf8).write(to: url)
    #expect(WidgetDisplayModel.load(from: store, hideAmounts: false) == nil)
}

@Test func aSnapshotWithAnUnreadableAmountIsTreatedAsCorrupt() {
    #expect(WidgetDisplayModel(snapshot: makeSnapshot(balance: "lots"), hideAmounts: false, moneyFormat: usd()) == nil)
}

@Test func placeholderIsMarkedAndFilledForRedaction() {
    let placeholder = WidgetDisplayModel.placeholder

    #expect(placeholder.isPlaceholder)
    #expect(placeholder.amountsHidden == false)
    #expect(placeholder.recentRows.isEmpty == false)
    #expect(placeholder.categoryRows.isEmpty == false)
    #expect(placeholder.trend(days: 7).bars.count == 7)
}
