import Foundation

/// The document the app writes to the App Group for its widgets.
///
/// It is deliberately a plain value: widgets never open SwiftData, so everything they draw — the
/// balance, the spend, the trend, the recent rows, and the top categories — is copied here when the
/// app's data changes. Every amount is a decimal string rather than a `Decimal`, because a string
/// is what survives any decoder without a locale or precision surprise; the currency code and the
/// grouping mode travel with it so the widget formats exactly like the app.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// The version this app writes and accepts.
    ///
    /// ``FileWidgetSnapshotStore`` refuses a document with any other version, so a widget built
    /// against a newer shape shows its placeholder instead of misreading amounts.
    public static let currentSchemaVersion = 1

    /// The document's version, from ``currentSchemaVersion``.
    public var schemaVersion: Int
    /// When the app built this document.
    public var generatedAt: Date
    /// The display currency, e.g. "BDT".
    public var currencyCode: String
    /// How amounts are grouped for display.
    public var numberGrouping: NumberGrouping
    /// The combined balance of the active accounts, as a decimal string.
    public var balance: String
    /// The instant of the newest checkpoint the balance rests on, or `nil` when no account has one.
    public var balanceAsOf: Date?
    /// Today's spend so far, as a decimal string.
    public var todaySpend: String
    /// This month's spend so far, as a decimal string.
    public var monthSpend: String
    /// This month's income so far, as a decimal string.
    public var monthIncome: String
    /// The last 30 days of spend, oldest first, one entry per day including days without spend.
    public var trend: [TrendPoint]
    /// Up to six of the newest transactions across the active accounts, newest first.
    public var recentTransactions: [RecentTransaction]
    /// Up to four categories with the most spend this month, highest spend first.
    public var topCategories: [TopCategory]

    public init(
        schemaVersion: Int = WidgetSnapshot.currentSchemaVersion,
        generatedAt: Date,
        currencyCode: String,
        numberGrouping: NumberGrouping,
        balance: String,
        balanceAsOf: Date?,
        todaySpend: String,
        monthSpend: String,
        monthIncome: String,
        trend: [TrendPoint],
        recentTransactions: [RecentTransaction],
        topCategories: [TopCategory]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.currencyCode = currencyCode
        self.numberGrouping = numberGrouping
        self.balance = balance
        self.balanceAsOf = balanceAsOf
        self.todaySpend = todaySpend
        self.monthSpend = monthSpend
        self.monthIncome = monthIncome
        self.trend = trend
        self.recentTransactions = recentTransactions
        self.topCategories = topCategories
    }

    /// One day of the trend: the day's first instant and the spend recorded in it.
    public struct TrendPoint: Codable, Equatable, Sendable {
        /// The first instant of the day, in the calendar the snapshot was built with.
        public let date: Date
        /// The day's spend, as a decimal string; "0" on a day without spend.
        public let spend: String

        public init(date: Date, spend: String) {
            self.date = date
            self.spend = spend
        }
    }

    /// One row of the recent transactions widget.
    public struct RecentTransaction: Codable, Equatable, Sendable, Identifiable {
        /// The transaction's stable identity, so a widget can deep-link to it.
        public let id: UUID
        /// The merchant as the app displays it.
        public let merchant: String
        /// The assigned category's name.
        public let categoryName: String
        /// The category's SF Symbol.
        public let symbolName: String
        /// The token the design system maps to the category's palette color.
        public let colorToken: String
        /// The amount's magnitude, as a decimal string.
        public let amount: String
        /// Whether the money left or entered the account.
        public let direction: Direction
        /// The reporting date the app shows.
        public let occurredAt: Date

        public init(
            id: UUID,
            merchant: String,
            categoryName: String,
            symbolName: String,
            colorToken: String,
            amount: String,
            direction: Direction,
            occurredAt: Date
        ) {
            self.id = id
            self.merchant = merchant
            self.categoryName = categoryName
            self.symbolName = symbolName
            self.colorToken = colorToken
            self.amount = amount
            self.direction = direction
            self.occurredAt = occurredAt
        }
    }

    /// One row of the top-categories widget.
    public struct TopCategory: Codable, Equatable, Sendable {
        /// The category's display name.
        public let name: String
        /// The category's SF Symbol.
        public let symbolName: String
        /// The token the design system maps to the category's palette color.
        public let colorToken: String
        /// The category's spend this month, as a decimal string.
        public let amount: String
        /// The category's percentage of this month's spend, as a decimal string.
        public let share: String

        public init(name: String, symbolName: String, colorToken: String, amount: String, share: String) {
            self.name = name
            self.symbolName = symbolName
            self.colorToken = colorToken
            self.amount = amount
            self.share = share
        }
    }
}
