import Foundation
import SwiftData
import Testing
import ZentriCore
@testable import ZentriApp

/// A fixed calendar so the tests' days never depend on the machine running them.
private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func date(_ day: Int, hour: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour))!
}

/// Holds the container for as long as a test uses its context.
@MainActor
private struct Store {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
}

private struct ReadFailure: Error {}

/// A transaction read that throws until it is told the store answers again.
@MainActor
private final class FlakyTransactions {
    var isFailing = true
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func read() throws -> [ZentriCore.Transaction] {
        guard !isFailing else { throw ReadFailure() }
        return try context.fetch(FetchDescriptor<ZentriCore.Transaction>())
    }
}

/// A store with two accounts, two categories, and four transactions over three days:
///
/// - 14 Mar 09:00, Everyday: Starbucks −5 (Dining, rules), with a bank message
/// - 14 Mar 18:00, Everyday: Salary +3,000 (Income, rules, note "March pay")
/// - 12 Mar 12:00, Savings: Grab −20 (no category, manual), a transfer
/// - 10 Mar 12:00, Everyday: Amazon −50 (Shopping, Apple Intelligence)
@MainActor
private struct Fixture {
    let store: Store
    let everyday: Account
    let savings: Account
    let dining: ZentriCore.Category

    init() throws {
        store = Store(container: try ZentriContainer.make(inMemory: true))
        let context = store.context
        everyday = Account(name: "Everyday", sortOrder: 0, createdAt: date(1))
        savings = Account(name: "Savings", sortOrder: 1, createdAt: date(1))
        context.insert(everyday)
        context.insert(savings)
        context.insert(BalanceCheckpoint(account: everyday, amount: 1_000, recordedAt: date(1), source: .opening, createdAt: date(1)))
        context.insert(BalanceCheckpoint(account: savings, amount: 500, recordedAt: date(1), source: .opening, createdAt: date(1)))
        dining = ZentriCore.Category(name: "Dining", symbolName: "fork.knife", colorToken: "coral", sortOrder: 0)
        let income = ZentriCore.Category(name: "Income", symbolName: "banknote", colorToken: "green", sortOrder: 1)
        let shopping = ZentriCore.Category(name: "Shopping", symbolName: "bag", colorToken: "violet", sortOrder: 2)
        let other = ZentriCore.Category(name: "Other", symbolName: "ellipsis", colorToken: "slate", sortOrder: 3)
        for category in [dining, income, shopping, other] {
            context.insert(category)
        }

        let message = RawMessage(
            text: "POS purchase USD 5.00 at STARBUCKS COFFEE #12",
            receivedAt: date(14, hour: 9),
            status: .parsed,
            fingerprint: "starbucks"
        )
        context.insert(message)
        add("Starbucks", raw: "STARBUCKS COFFEE #12", 5, .debit, date(14, hour: 9), everyday, dining, .rules, message: message)
        add("Salary", raw: "ACME PAYROLL", 3_000, .credit, date(14, hour: 18), everyday, income, .rules, note: "March pay")
        add("Grab", raw: "Grab", 20, .debit, date(12), savings, nil, .manual, isTransfer: true)
        add("Amazon", raw: "AMZN Mktp", 50, .debit, date(10), everyday, shopping, .foundationModels)
        try context.save()
    }

    private func add(
        _ merchant: String,
        raw: String,
        _ amount: Decimal,
        _ direction: Direction,
        _ occurredAt: Date,
        _ account: Account,
        _ category: ZentriCore.Category?,
        _ engine: ParseEngine,
        note: String? = nil,
        isTransfer: Bool = false,
        message: RawMessage? = nil
    ) {
        store.context.insert(
            ZentriCore.Transaction(
                account: account,
                amount: amount,
                direction: direction,
                occurredAt: occurredAt,
                recordedAt: occurredAt,
                merchantRaw: raw,
                merchantDisplay: merchant,
                category: category,
                categorySource: category == nil ? nil : .rule,
                rawMessage: message,
                parseEngine: engine,
                isTransfer: isTransfer,
                note: note
            )
        )
    }

    func model() -> TransactionsModel {
        TransactionsModel(context: store.context, calendar: calendar)
    }
}

private extension TransactionsModel {
    /// The merchants on screen, in list order.
    var merchants: [String] {
        sections.flatMap(\.items).map(\.merchant)
    }
}

@MainActor
@Suite("TransactionsModel")
struct TransactionsModelTests {
    @Test("Groups transactions by day, newest day and newest transaction first")
    func groupsByDay() throws {
        let fixture = try Fixture()
        let model = fixture.model()

        model.refresh(filter: TransactionFilter())

        #expect(model.loadState == .loaded)
        #expect(model.hasTransactions)
        #expect(model.sections.map(\.day) == [date(14, hour: 0), date(12, hour: 0), date(10, hour: 0)])
        #expect(model.sections.map(\.id) == model.sections.map(\.day))
        #expect(model.merchants == ["Salary", "Starbucks", "Grab", "Amazon"])
    }

    @Test("Copies each row's account, category, direction, engine, and transfer flag")
    func rowValues() throws {
        let fixture = try Fixture()
        let model = fixture.model()

        model.refresh(filter: TransactionFilter())

        let items = model.sections.flatMap(\.items)
        let starbucks = try #require(items.first { $0.merchant == "Starbucks" })
        #expect(starbucks.accountName == "Everyday")
        #expect(starbucks.categoryName == "Dining")
        #expect(starbucks.signedAmount == -5)
        #expect(starbucks.rawText == "POS purchase USD 5.00 at STARBUCKS COFFEE #12")
        let grab = try #require(items.first { $0.merchant == "Grab" })
        #expect(grab.isManual)
        #expect(grab.isTransfer)
        // An uncategorized row is shown as the live Other category but filters as uncategorized.
        #expect(grab.categoryName == "Other")
        #expect(grab.categoryID == nil)
    }

    @Test(
        "Search matches the merchant, the message's merchant, the note, and the raw SMS",
        arguments: [
            ("grab", ["Grab"]),
            ("AMZN", ["Amazon"]),
            ("march PAY", ["Salary"]),
            ("POS purchase", ["Starbucks"]),
            ("  starbucks ", ["Starbucks"]),
            ("nothing like this", []),
        ]
    )
    func search(query: String, expected: [String]) throws {
        let fixture = try Fixture()
        let model = fixture.model()

        model.refresh(filter: TransactionFilter(searchText: query))

        #expect(model.merchants == expected)
        #expect(model.hasTransactions)
    }

    @Test("Filters by account, category, direction, and engine")
    func filters() throws {
        let fixture = try Fixture()
        let model = fixture.model()
        model.refresh(filter: TransactionFilter())

        model.apply(TransactionFilter(accountID: fixture.savings.id))
        #expect(model.merchants == ["Grab"])

        model.apply(TransactionFilter(categoryID: fixture.dining.id))
        #expect(model.merchants == ["Starbucks"])

        model.apply(TransactionFilter(direction: .credit))
        #expect(model.merchants == ["Salary"])

        model.apply(TransactionFilter(engine: .foundationModels))
        #expect(model.merchants == ["Amazon"])

        model.apply(TransactionFilter(accountID: fixture.everyday.id, direction: .debit))
        #expect(model.merchants == ["Starbucks", "Amazon"])
    }

    @Test("A date range covers both ends' whole days, whatever the times in it")
    func dateRange() throws {
        let fixture = try Fixture()
        let model = fixture.model()
        model.refresh(filter: TransactionFilter())

        model.apply(TransactionFilter(dateRange: date(12, hour: 23)...date(14, hour: 1)))

        #expect(model.merchants == ["Salary", "Starbucks", "Grab"])
    }

    @Test("Applying a filter re-filters without reading the store; a refresh reads it again")
    func applyDoesNotRefetch() throws {
        let fixture = try Fixture()
        let model = fixture.model()
        model.refresh(filter: TransactionFilter())
        fixture.store.context.insert(
            ZentriCore.Transaction(
                account: fixture.everyday,
                amount: 1,
                direction: .debit,
                occurredAt: date(15),
                merchantRaw: "Kiosk",
                merchantDisplay: "Kiosk"
            )
        )

        model.apply(TransactionFilter())
        #expect(!model.merchants.contains("Kiosk"))

        model.refresh(filter: TransactionFilter())
        #expect(model.merchants.first == "Kiosk")
    }

    @Test("The balance is the active accounts' combined balance")
    func balance() throws {
        let fixture = try Fixture()
        let model = fixture.model()

        model.refresh(filter: TransactionFilter())

        // Everyday: 1,000 − 5 + 3,000 − 50; Savings: 500 − 20.
        #expect(model.balance == 4_425)
        #expect(model.accounts.map(\.name) == ["Everyday", "Savings"])
        #expect(model.categories.map(\.name) == ["Dining", "Income", "Shopping", "Other"])
    }

    @Test("An empty store loads as no transactions, not as a failure")
    func emptyStore() throws {
        // The container is held for the whole test: a bare context does not keep its store alive.
        let container = try ZentriContainer.make(inMemory: true)
        let model = TransactionsModel(context: container.mainContext, calendar: calendar)

        model.refresh(filter: TransactionFilter())

        #expect(model.loadState == .loaded)
        #expect(!model.hasTransactions)
        #expect(model.sections.isEmpty)
        #expect(model.balance == nil)
    }

    @Test("A failed read shows the failure, never an empty history, and a retry recovers")
    func failedRead() throws {
        let fixture = try Fixture()
        let context = fixture.store.context
        let transactions = FlakyTransactions(context: context)
        let real = TransactionsStoreReads(context: context)
        let model = TransactionsModel(
            reads: TransactionsStoreReads(
                transactions: { try transactions.read() },
                accounts: real.accounts,
                categories: real.categories,
                parsingRules: real.parsingRules
            ),
            calendar: calendar
        )

        model.refresh(filter: TransactionFilter())
        #expect(model.loadState == .failed)
        #expect(model.sections.isEmpty)
        #expect(!model.hasTransactions)

        transactions.isFailing = false
        model.refresh(filter: TransactionFilter())
        #expect(model.loadState == .loaded)
        #expect(model.merchants.count == 4)
    }

    @Test("A parsing-rule read that fails leaves the list readable")
    func failedRuleRead() throws {
        let fixture = try Fixture()
        let real = TransactionsStoreReads(context: fixture.store.context)
        let model = TransactionsModel(
            reads: TransactionsStoreReads(
                transactions: real.transactions,
                accounts: real.accounts,
                categories: real.categories,
                parsingRules: { throw ReadFailure() }
            ),
            calendar: calendar
        )

        model.refresh(filter: TransactionFilter())

        #expect(model.loadState == .loaded)
        #expect(model.merchants.count == 4)
        #expect(model.ruleName(id: UUID()) == nil)
    }
}
