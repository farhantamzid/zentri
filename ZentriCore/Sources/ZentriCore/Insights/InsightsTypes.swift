import Foundation

/// The dates an insights summary covers.
///
/// The range is inclusive: a transaction that occurs exactly at ``start`` or ``end`` is part of the
/// period. A period whose end precedes its start covers nothing.
public struct InsightsPeriod: Sendable, Equatable {
    /// The first instant included in the period.
    public let start: Date
    /// The last instant included in the period.
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

/// A transaction without any SwiftData dependency, so insights are independently testable.
public struct TransactionSnapshot: Sendable, Equatable, Identifiable {
    /// Stable identity used by backups and widget snapshots.
    public let id: UUID
    /// The account the money moved through.
    public let accountID: UUID
    /// The positive magnitude of the movement.
    public let amount: Decimal
    /// Whether the movement left or entered the account.
    public let direction: Direction
    /// The reporting date the period filters on.
    public let occurredAt: Date
    /// The merchant as displayed; insights normalize its whitespace and case before grouping.
    public let merchant: String
    /// The assigned category's identity, when it has one.
    public let categoryID: UUID?
    /// The assigned category's display name.
    public let categoryName: String
    /// The assigned category's SF Symbol.
    public let symbolName: String
    /// The token the design system maps to the category's palette color.
    public let colorToken: String
    /// Whether both sides of a transfer are excluded from spend and income.
    public let isTransfer: Bool

    /// Creates a snapshot.
    ///
    /// The category defaults mirror the seeded `Other` category — the name, symbol, and color token that
    /// `SeedData` seeds and that `CategorizationService.fallbackCategoryName` names — so a transaction the
    /// caller has not categorized still produces a total instead of disappearing from the breakdown. They
    /// are written out rather than read from `SeedData` so the insights layer stays free of the persistence
    /// layer; the seed-sync test in `CategorizationServiceTests` fails if they drift from the seeded category.
    public init(
        id: UUID,
        accountID: UUID,
        amount: Decimal,
        direction: Direction,
        occurredAt: Date,
        merchant: String,
        categoryID: UUID? = nil,
        categoryName: String = "Other",
        symbolName: String = "ellipsis",
        colorToken: String = "slate",
        isTransfer: Bool = false
    ) {
        self.id = id
        self.accountID = accountID
        self.amount = amount
        self.direction = direction
        self.occurredAt = occurredAt
        self.merchant = merchant
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.symbolName = symbolName
        self.colorToken = colorToken
        self.isTransfer = isTransfer
    }
}

/// A category's spend within a period.
public struct CategoryTotal: Sendable, Equatable {
    /// The category's identity, taken from the first transaction in the category.
    public let categoryID: UUID?
    /// The category's display name.
    public let categoryName: String
    /// The category's SF Symbol.
    public let symbolName: String
    /// The token the design system maps to the category's palette color.
    public let colorToken: String
    /// The spend the category received in the period.
    public let amount: Decimal
    /// The category's percentage of the period's spend, rounded to two decimals.
    ///
    /// The shares of all categories add up to exactly 100 whenever the period has spend; the rounding
    /// remainder is carried by the largest category.
    public let share: Decimal
    /// The number of spend transactions in the category.
    public let transactionCount: Int
    /// The spend the category received in the calendar month before the period's month, or zero when it
    /// had none.
    ///
    /// This is always the actual previous-month figure, even when the period is not a calendar month. In
    /// that case ``changePercent`` is `nil`, so there is no meaningful comparison to draw from it.
    public let previousAmount: Decimal
    /// The signed percentage change from the previous month, rounded to two decimals.
    ///
    /// Positive values are increases. The value is `nil` when the previous month has no spend in the
    /// category, because a change from nothing has no meaningful percentage, and when the period is not
    /// exactly one calendar month, because the comparison would then describe a different range than
    /// ``amount`` and ``share`` do. See `InsightsCalculator.summary(transactions:period:calendar:)`.
    public let changePercent: Decimal?

    public init(
        categoryID: UUID?,
        categoryName: String,
        symbolName: String,
        colorToken: String,
        amount: Decimal,
        share: Decimal,
        transactionCount: Int,
        previousAmount: Decimal,
        changePercent: Decimal?
    ) {
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.symbolName = symbolName
        self.colorToken = colorToken
        self.amount = amount
        self.share = share
        self.transactionCount = transactionCount
        self.previousAmount = previousAmount
        self.changePercent = changePercent
    }
}

/// A merchant's spend within a period.
public struct MerchantTotal: Sendable, Equatable {
    /// The merchant's display name, as first written in the period after whitespace normalization.
    public let merchant: String
    /// The spend the merchant received in the period.
    public let amount: Decimal
    /// The number of spend transactions with the merchant.
    public let transactionCount: Int

    public init(merchant: String, amount: Decimal, transactionCount: Int) {
        self.merchant = merchant
        self.amount = amount
        self.transactionCount = transactionCount
    }
}

/// One day's spend within a period.
public struct DailySpend: Sendable, Equatable {
    /// The first instant of the day in the calculator's calendar.
    public let date: Date
    /// The spend recorded that day; zero on days without spend.
    public let amount: Decimal

    public init(date: Date, amount: Decimal) {
        self.date = date
        self.amount = amount
    }
}

/// One month's income and expense, for the six-month chart.
public struct MonthlyIncomeExpense: Sendable, Equatable {
    /// The first instant of the month in the calculator's calendar.
    public let month: Date
    /// The money that entered the account that month, excluding transfers.
    public let income: Decimal
    /// The money that left the account that month, excluding transfers.
    public let spend: Decimal

    public init(month: Date, income: Decimal, spend: Decimal) {
        self.month = month
        self.income = income
        self.spend = spend
    }
}

/// Everything the insights screen shows for one period.
public struct InsightsSummary: Sendable, Equatable {
    /// The period the summary describes.
    public let period: InsightsPeriod
    /// The money that left the account in the period, excluding transfers.
    public let totalSpend: Decimal
    /// The money that entered the account in the period, excluding transfers.
    public let totalIncome: Decimal
    /// The number of non-transfer transactions in the period, in both directions.
    public let transactionCount: Int
    /// The period's spend by category, highest spend first.
    public let categoryTotals: [CategoryTotal]
    /// The period's spend by merchant, highest spend first.
    public let merchantTotals: [MerchantTotal]
    /// One entry for every day in the period, including days without spend.
    public let dailySpend: [DailySpend]
    /// The six months ending with the period's month, oldest first.
    public let monthlyIncomeExpense: [MonthlyIncomeExpense]
    /// The period's largest transactions, excluding transfers, largest first.
    public let largestTransactions: [TransactionSnapshot]
    /// Deterministic, user-facing observations about the period, such as a month-over-month change.
    public let observations: [String]

    public init(
        period: InsightsPeriod,
        totalSpend: Decimal,
        totalIncome: Decimal,
        transactionCount: Int,
        categoryTotals: [CategoryTotal],
        merchantTotals: [MerchantTotal],
        dailySpend: [DailySpend],
        monthlyIncomeExpense: [MonthlyIncomeExpense],
        largestTransactions: [TransactionSnapshot],
        observations: [String]
    ) {
        self.period = period
        self.totalSpend = totalSpend
        self.totalIncome = totalIncome
        self.transactionCount = transactionCount
        self.categoryTotals = categoryTotals
        self.merchantTotals = merchantTotals
        self.dailySpend = dailySpend
        self.monthlyIncomeExpense = monthlyIncomeExpense
        self.largestTransactions = largestTransactions
        self.observations = observations
    }

    /// A summary with no data, used for an empty or invalid period.
    public static func empty(period: InsightsPeriod) -> InsightsSummary {
        InsightsSummary(
            period: period,
            totalSpend: 0,
            totalIncome: 0,
            transactionCount: 0,
            categoryTotals: [],
            merchantTotals: [],
            dailySpend: [],
            monthlyIncomeExpense: [],
            largestTransactions: [],
            observations: []
        )
    }
}
