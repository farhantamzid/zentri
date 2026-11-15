import Foundation
import SwiftData
import Testing
@testable import ZentriCore

/// 2026-11-18 11:06:40 UTC.
private let snapshotNow = Date(timeIntervalSince1970: 1_795_000_000)

private func snapshotCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return calendar
}

private func utcDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
    snapshotCalendar().date(
        from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
    ) ?? .distantPast
}

/// A money value built exactly from cents, so no test depends on locale or decimal text parsing.
private func cents(_ value: Int) -> Decimal {
    Decimal(sign: value < 0 ? .minus : .plus, exponent: -2, significand: Decimal(abs(value)))
}

private let accountA = UUID()
private let accountB = UUID()
private let archivedAccount = UUID()

private let groceries = CategorySnapshot(id: UUID(), name: "Groceries", symbolName: "cart", colorToken: "green")
private let dining = CategorySnapshot(id: UUID(), name: "Dining", symbolName: "fork.knife", colorToken: "coral")
private let transport = CategorySnapshot(id: UUID(), name: "Transport", symbolName: "car", colorToken: "teal")
private let shopping = CategorySnapshot(id: UUID(), name: "Shopping", symbolName: "bag", colorToken: "violet")
private let health = CategorySnapshot(id: UUID(), name: "Health", symbolName: "heart", colorToken: "cyan")
private let income = CategorySnapshot(id: UUID(), name: "Income", symbolName: "arrow.up.right", colorToken: "green")
private let transfers = CategorySnapshot(
    id: UUID(), name: "Transfers", symbolName: "arrow.left.arrow.right", colorToken: "indigo"
)

private struct SnapshotFixture {
    let accounts: [WidgetSnapshotBuilder.AccountInput]
    let transactions: [WidgetSnapshotBuilder.TransactionInput]
    let categories: [CategorySnapshot]
    let settings: AppSettings
}

/// Two active accounts, one archived account, and transactions spread across today, this month,
/// the 30-day trend window, and before it.
private func makeFixture() -> SnapshotFixture {
    let checkpointDate = utcDate(2026, 11, 1)
    let accounts = [
        WidgetSnapshotBuilder.AccountInput(
            id: accountA,
            checkpoints: [CheckpointValue(
                accountID: accountA, amount: cents(100_000), recordedAt: checkpointDate, createdAt: checkpointDate
            )]
        ),
        WidgetSnapshotBuilder.AccountInput(
            id: accountB,
            checkpoints: [CheckpointValue(
                accountID: accountB, amount: cents(50_000), recordedAt: checkpointDate, createdAt: checkpointDate
            )]
        ),
        WidgetSnapshotBuilder.AccountInput(
            id: archivedAccount,
            isArchived: true,
            checkpoints: [CheckpointValue(
                accountID: archivedAccount,
                amount: cents(999_900),
                recordedAt: utcDate(2026, 11, 15),
                createdAt: utcDate(2026, 11, 15)
            )]
        ),
    ]

    let transactions = [
        WidgetSnapshotBuilder.TransactionInput(
            accountID: accountA, amount: cents(2500), direction: .debit,
            occurredAt: utcDate(2026, 11, 18, hour: 9), recordedAt: utcDate(2026, 11, 18, hour: 9, minute: 5),
            merchant: "Market", categoryID: groceries.id, categoryName: "Groceries",
            symbolName: "cart", colorToken: "green"
        ),
        WidgetSnapshotBuilder.TransactionInput(
            accountID: accountA, amount: cents(4000), direction: .debit,
            occurredAt: utcDate(2026, 11, 17, hour: 18), recordedAt: utcDate(2026, 11, 17, hour: 18, minute: 5),
            merchant: "Grab", categoryID: transport.id, categoryName: "Transport",
            symbolName: "car", colorToken: "teal"
        ),
        WidgetSnapshotBuilder.TransactionInput(
            accountID: accountA, amount: cents(500), direction: .debit,
            occurredAt: utcDate(2026, 10, 1, hour: 12), recordedAt: utcDate(2026, 10, 1, hour: 12, minute: 5),
            merchant: "Old Shop", categoryID: shopping.id, categoryName: "Shopping",
            symbolName: "bag", colorToken: "violet"
        ),
        WidgetSnapshotBuilder.TransactionInput(
            accountID: accountA, amount: cents(10_000), direction: .debit,
            occurredAt: utcDate(2026, 11, 18, hour: 11), recordedAt: utcDate(2026, 11, 18, hour: 11, minute: 1),
            merchant: "Savings", categoryID: transfers.id, categoryName: "Transfers",
            symbolName: "arrow.left.arrow.right", colorToken: "indigo", isTransfer: true
        ),
        WidgetSnapshotBuilder.TransactionInput(
            accountID: accountA, amount: cents(1000), direction: .credit,
            occurredAt: utcDate(2026, 11, 18, hour: 8), recordedAt: utcDate(2026, 11, 18, hour: 8, minute: 1),
            merchant: "Refund", categoryID: shopping.id, categoryName: "Shopping",
            symbolName: "bag", colorToken: "violet"
        ),
        WidgetSnapshotBuilder.TransactionInput(
            accountID: accountB, amount: cents(1500), direction: .debit,
            occurredAt: utcDate(2026, 11, 18, hour: 10), recordedAt: utcDate(2026, 11, 18, hour: 10, minute: 1),
            merchant: "Cafe", categoryID: dining.id, categoryName: "Dining",
            symbolName: "fork.knife", colorToken: "coral"
        ),
        WidgetSnapshotBuilder.TransactionInput(
            accountID: accountB, amount: cents(200_000), direction: .credit,
            occurredAt: utcDate(2026, 11, 10, hour: 9), recordedAt: utcDate(2026, 11, 10, hour: 9, minute: 1),
            merchant: "Salary", categoryID: income.id, categoryName: "Income",
            symbolName: "arrow.up.right", colorToken: "green"
        ),
        WidgetSnapshotBuilder.TransactionInput(
            accountID: accountB, amount: cents(700), direction: .debit,
            occurredAt: utcDate(2026, 11, 5, hour: 12), recordedAt: utcDate(2026, 11, 5, hour: 12, minute: 1),
            merchant: "Books", categoryID: shopping.id, categoryName: "Shopping",
            symbolName: "bag", colorToken: "violet"
        ),
        WidgetSnapshotBuilder.TransactionInput(
            accountID: accountB, amount: cents(400), direction: .debit,
            occurredAt: utcDate(2026, 11, 16, hour: 9), recordedAt: utcDate(2026, 11, 16, hour: 9, minute: 1),
            merchant: "Pharmacy", categoryID: health.id, categoryName: "Health",
            symbolName: "heart", colorToken: "cyan"
        ),
        WidgetSnapshotBuilder.TransactionInput(
            accountID: archivedAccount, amount: cents(5000), direction: .debit,
            occurredAt: utcDate(2026, 11, 18, hour: 7), recordedAt: utcDate(2026, 11, 18, hour: 7, minute: 1),
            merchant: "Secret", categoryID: groceries.id, categoryName: "Groceries",
            symbolName: "cart", colorToken: "green"
        ),
    ]

    var settings = AppSettings.defaultValue
    settings.currencyCode = "BDT"
    settings.numberGrouping = .indian

    return SnapshotFixture(
        accounts: accounts,
        transactions: transactions,
        categories: [groceries, dining, transport, shopping, health, income, transfers],
        settings: settings
    )
}

private func buildFixtureSnapshot() -> WidgetSnapshot {
    let fixture = makeFixture()
    return WidgetSnapshotBuilder().build(
        accounts: fixture.accounts,
        transactions: fixture.transactions,
        categories: fixture.categories,
        settings: fixture.settings,
        now: snapshotNow,
        calendar: snapshotCalendar()
    )
}

private func temporarySnapshotURL() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "widget-snapshot-\(UUID().uuidString).json")
}

/// The money a snapshot field carries, read back without any locale.
private func decimal(_ text: String) -> Decimal {
    Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) ?? .nan
}

// MARK: - Building

@Test func buildsBalanceAndSpendFromTheActiveAccounts() {
    let snapshot = buildFixtureSnapshot()

    #expect(snapshot.schemaVersion == WidgetSnapshot.currentSchemaVersion)
    #expect(snapshot.generatedAt == snapshotNow)
    #expect(snapshot.currencyCode == "BDT")
    #expect(snapshot.numberGrouping == .indian)
    // A: 1000 - 25 - 40 - 100 + 10 = 845, B: 500 - 15 + 2000 - 7 - 4 = 2474. The 1 October
    // transaction was recorded before the checkpoint, so its balance already includes it.
    #expect(snapshot.balance == "3319")
    #expect(snapshot.balanceAsOf == utcDate(2026, 11, 1))
    #expect(snapshot.todaySpend == "40")
    #expect(snapshot.monthSpend == "91")
    #expect(snapshot.monthIncome == "2010")
}

@Test func excludesArchivedAccountsEverywhere() {
    let snapshot = buildFixtureSnapshot()

    // The archived account holds a 9,999 balance, a 50 spend and the latest checkpoint.
    #expect(snapshot.balance == "3319")
    #expect(snapshot.balanceAsOf == utcDate(2026, 11, 1))
    #expect(snapshot.todaySpend == "40")
    #expect(!snapshot.recentTransactions.contains { $0.merchant == "Secret" })
    #expect(snapshot.topCategories.first { $0.name == "Groceries" }?.amount == "25")
}

@Test func buildsThirtyDayTrendWithOnePointPerDay() {
    let snapshot = buildFixtureSnapshot()
    let calendar = snapshotCalendar()
    let start = utcDate(2026, 10, 20)

    #expect(snapshot.trend.count == 30)
    #expect(snapshot.trend.first?.date == start)
    #expect(snapshot.trend.last?.date == utcDate(2026, 11, 18))
    for (offset, point) in snapshot.trend.enumerated() {
        #expect(point.date == calendar.date(byAdding: .day, value: offset, to: start))
    }
    // A day without spend still has a point, so the trend never has holes.
    #expect(snapshot.trend.first?.spend == "0")
    #expect(snapshot.trend.last?.spend == "40")
    // Only 5, 16, 17, and 18 November have spend inside the window.
    #expect(snapshot.trend.filter { $0.spend == "0" }.count == 26)
}

@Test func capsRecentTransactionsAtSixNewestFirst() {
    let snapshot = buildFixtureSnapshot()

    #expect(snapshot.recentTransactions.count == 6)
    let order = snapshot.recentTransactions.map(\.occurredAt)
    #expect(order == order.sorted(by: >))
    #expect(snapshot.recentTransactions.first?.merchant == "Savings")
    #expect(snapshot.recentTransactions.map(\.merchant) == [
        "Savings", "Cafe", "Market", "Refund", "Grab", "Pharmacy",
    ])
    #expect(snapshot.recentTransactions.first?.categoryName == "Transfers")
    #expect(snapshot.recentTransactions.first?.symbolName == "arrow.left.arrow.right")
    #expect(snapshot.recentTransactions.first?.colorToken == "indigo")
    #expect(snapshot.recentTransactions.first?.direction == .debit)
    #expect(snapshot.recentTransactions.first?.amount == "100")
    #expect(!snapshot.recentTransactions.contains { $0.merchant == "Salary" })
}

@Test func capsTopCategoriesAtFourWithAmountsAndShares() {
    let snapshot = buildFixtureSnapshot()

    #expect(snapshot.topCategories.map(\.name) == ["Transport", "Groceries", "Dining", "Shopping"])
    #expect(snapshot.topCategories.map(\.amount) == ["40", "25", "15", "7"])
    #expect(snapshot.topCategories.first?.symbolName == "car")
    #expect(snapshot.topCategories.first?.colorToken == "teal")
    let shares = snapshot.topCategories.map { decimal($0.share) }
    #expect(shares.allSatisfy { $0 > 0 })
    #expect(shares == shares.sorted(by: >))
    // A fifth category ("Health", 4) is left out by the cap, so the kept shares cannot add up to 100.
    #expect(shares.reduce(Decimal.zero, +) < 100)
}

@Test func computesSharesThatAddUpToOneHundred() {
    let account = UUID()
    let spends = [("Groceries", 5000), ("Dining", 3000), ("Transport", 2000)].map { name, amount in
        WidgetSnapshotBuilder.TransactionInput(
            accountID: account,
            amount: cents(amount),
            direction: .debit,
            occurredAt: utcDate(2026, 11, 18, hour: 9),
            recordedAt: utcDate(2026, 11, 18, hour: 9, minute: 1),
            merchant: name,
            categoryName: name
        )
    }

    let snapshot = WidgetSnapshotBuilder().build(
        accounts: [WidgetSnapshotBuilder.AccountInput(id: account)],
        transactions: spends,
        categories: [],
        settings: .defaultValue,
        now: snapshotNow,
        calendar: snapshotCalendar()
    )

    #expect(snapshot.topCategories.map(\.name) == ["Groceries", "Dining", "Transport"])
    #expect(snapshot.topCategories.map { decimal($0.share) } == [50, 30, 20])
    #expect(snapshot.topCategories.map { decimal($0.share) }.reduce(Decimal.zero, +) == 100)
}

@Test func fillsUncategorizedTransactionsFromTheLiveCatalog() {
    let account = UUID()
    let transaction = WidgetSnapshotBuilder.TransactionInput(
        accountID: account,
        amount: cents(900),
        direction: .debit,
        occurredAt: utcDate(2026, 11, 18, hour: 9),
        recordedAt: utcDate(2026, 11, 18, hour: 9, minute: 1),
        merchant: "Corner Shop"
    )
    let other = CategorySnapshot(id: UUID(), name: "Other", symbolName: "ellipsis", colorToken: "slate")

    let snapshot = WidgetSnapshotBuilder().build(
        accounts: [WidgetSnapshotBuilder.AccountInput(id: account)],
        transactions: [transaction],
        categories: [other],
        settings: .defaultValue,
        now: snapshotNow,
        calendar: snapshotCalendar()
    )

    #expect(snapshot.recentTransactions.first?.categoryName == "Other")
    #expect(snapshot.recentTransactions.first?.symbolName == "ellipsis")
    #expect(snapshot.recentTransactions.first?.colorToken == "slate")
    #expect(snapshot.topCategories.first?.name == "Other")
}

@Test func emptyStoreProducesAZeroSnapshot() {
    let snapshot = WidgetSnapshotBuilder().build(
        accounts: [],
        transactions: [],
        categories: [],
        settings: .defaultValue,
        now: snapshotNow,
        calendar: snapshotCalendar()
    )

    #expect(snapshot.balance == "0")
    #expect(snapshot.balanceAsOf == nil)
    #expect(snapshot.todaySpend == "0")
    #expect(snapshot.monthSpend == "0")
    #expect(snapshot.monthIncome == "0")
    #expect(snapshot.trend.count == 30)
    #expect(snapshot.trend.allSatisfy { $0.spend == "0" })
    #expect(snapshot.recentTransactions.isEmpty)
    #expect(snapshot.topCategories.isEmpty)
}

@Test func encodesEveryAmountAsAString() throws {
    let snapshot = buildFixtureSnapshot()
    let data = try JSONEncoder().encode(snapshot)
    let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(object["balance"] is String)
    #expect(object["todaySpend"] is String)
    #expect(object["monthSpend"] is String)
    #expect(object["monthIncome"] is String)

    let trend = try #require(object["trend"] as? [[String: Any]])
    #expect(trend.allSatisfy { $0["spend"] is String })

    let recent = try #require(object["recentTransactions"] as? [[String: Any]])
    #expect(recent.allSatisfy { $0["amount"] is String })

    let categories = try #require(object["topCategories"] as? [[String: Any]])
    #expect(categories.allSatisfy { $0["amount"] is String && $0["share"] is String })
}

// MARK: - File store

@Test func snapshotRoundTripsThroughTheFileStore() throws {
    let url = temporarySnapshotURL()
    defer { try? FileManager.default.removeItem(at: url) }
    let store = FileWidgetSnapshotStore(fileURL: url)
    let snapshot = buildFixtureSnapshot()

    try store.write(snapshot)

    #expect(store.read() == snapshot)

    // A second write replaces the existing file rather than appending or failing.
    var updated = snapshot
    updated.balance = "1"
    try store.write(updated)
    #expect(store.read() == updated)
}

@Test func writeCreatesTheMissingParentDirectory() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "zentri-snapshots-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileWidgetSnapshotStore(fileURL: directory.appending(path: "nested/widget-snapshot.json"))

    try store.write(buildFixtureSnapshot())

    #expect(store.read() != nil)
}

@Test func readReturnsNilAfterTheFileIsDeleted() throws {
    let url = temporarySnapshotURL()
    let store = FileWidgetSnapshotStore(fileURL: url)
    try store.write(buildFixtureSnapshot())
    #expect(store.read() != nil)

    try FileManager.default.removeItem(at: url)

    #expect(store.read() == nil)
}

@Test func removeDeletesTheSnapshotAndToleratesAMissingFile() throws {
    let url = temporarySnapshotURL()
    defer { try? FileManager.default.removeItem(at: url) }
    let store = FileWidgetSnapshotStore(fileURL: url)
    try store.write(buildFixtureSnapshot())

    try store.remove()

    #expect(store.read() == nil)
    #expect(!FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
    // Nothing left to remove is already the requested state.
    try store.remove()
    try FileWidgetSnapshotStore(fileURL: nil).remove()
}

@Test func readReturnsNilForACorruptFile() throws {
    let url = temporarySnapshotURL()
    defer { try? FileManager.default.removeItem(at: url) }
    try Data("{not json".utf8).write(to: url)

    #expect(FileWidgetSnapshotStore(fileURL: url).read() == nil)
}

@Test func readReturnsNilForAnUnsupportedVersion() throws {
    let url = temporarySnapshotURL()
    defer { try? FileManager.default.removeItem(at: url) }
    let store = FileWidgetSnapshotStore(fileURL: url)
    var future = buildFixtureSnapshot()
    future.schemaVersion = WidgetSnapshot.currentSchemaVersion + 1

    try store.write(future)

    #expect(store.read() == nil)
}

@Test func nilFileURLMakesTheStoreInert() throws {
    let store = FileWidgetSnapshotStore(fileURL: nil)

    #expect(store.read() == nil)
    try store.write(buildFixtureSnapshot())
    #expect(store.read() == nil)
}

@Test func sharedContainerURLsUseTheAppGroupFileNames() {
    if let container = SharedContainer.containerURL {
        #expect(SharedContainer.widgetSnapshotURL == container.appending(path: AppGroup.widgetSnapshotFileName))
        #expect(SharedContainer.settingsURL == container.appending(path: AppGroup.settingsFileName))
    } else {
        #expect(SharedContainer.widgetSnapshotURL == nil)
        #expect(SharedContainer.settingsURL == nil)
    }
}

// MARK: - Live refresher

@Test @MainActor func liveRefresherWritesTheStoreState() async throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)
    try SeedData.seed(into: context)
    let categories = try context.fetch(FetchDescriptor<ZentriCore.Category>())
    let groceries = try #require(categories.first { $0.name == "Groceries" })
    let account = Account(name: "Everyday", institutionName: "Bank", sortOrder: 0, createdAt: snapshotNow)
    context.insert(account)
    context.insert(BalanceCheckpoint(
        account: account,
        amount: cents(100_000),
        recordedAt: utcDate(2026, 11, 1),
        source: .opening,
        createdAt: utcDate(2026, 11, 1)
    ))
    context.insert(Transaction(
        account: account,
        amount: cents(2500),
        direction: .debit,
        occurredAt: utcDate(2026, 11, 18, hour: 9),
        recordedAt: utcDate(2026, 11, 18, hour: 9, minute: 5),
        merchantRaw: "Market",
        merchantDisplay: "Market",
        category: groceries
    ))
    context.insert(Transaction(
        account: account,
        amount: cents(900),
        direction: .debit,
        occurredAt: utcDate(2026, 11, 18, hour: 8),
        recordedAt: utcDate(2026, 11, 18, hour: 8, minute: 5),
        merchantRaw: "Corner Shop",
        merchantDisplay: "Corner Shop"
    ))
    try context.save()
    let url = temporarySnapshotURL()
    defer { try? FileManager.default.removeItem(at: url) }
    let store = FileWidgetSnapshotStore(fileURL: url)
    let refresher = LiveWidgetSnapshotRefresher(
        context: context,
        store: store,
        settings: { .defaultValue },
        now: { snapshotNow },
        calendar: snapshotCalendar()
    )

    await refresher.refresh()

    let snapshot = try #require(store.read())
    #expect(snapshot.balance == "966")
    #expect(snapshot.todaySpend == "34")
    #expect(snapshot.balanceAsOf == utcDate(2026, 11, 1))
    #expect(snapshot.recentTransactions.map(\.merchant) == ["Market", "Corner Shop"])
    #expect(snapshot.recentTransactions.last?.categoryName == "Other")
    #expect(snapshot.recentTransactions.last?.symbolName == "ellipsis")
    #expect(snapshot.topCategories.first?.name == "Groceries")
}
