import Foundation

/// Everything a widget draws, already formatted: the snapshot's amounts as display strings, plus the
/// labels and layout values that do not depend on money.
///
/// Widgets never format money themselves. This model applies the snapshot's own currency and
/// grouping through ``MoneyFormat``, so a widget always matches the app, and it applies privacy: with
/// amounts hidden, every monetary string — including the ones VoiceOver reads — is
/// ``hiddenAmount``, while names, dates, directions, bar heights, and category shares stay, so the
/// layout does not change when privacy is turned on.
public struct WidgetDisplayModel: Sendable {
    /// What a hidden amount shows, in place of every monetary string.
    public static let hiddenAmount = "••••"

    /// Whether this is the stand-in for a missing snapshot, drawn redacted with an "Open Zentri"
    /// hint.
    public let isPlaceholder: Bool
    /// Whether amounts are hidden for privacy.
    public let amountsHidden: Bool
    /// The combined balance, e.g. `$12,845.67`.
    public let balance: String
    /// Whether the balance is below zero. Always `false` when amounts are hidden, because a sign
    /// shown through color would reveal part of the amount.
    public let isBalanceNegative: Bool
    /// The newest checkpoint the balance rests on, if any.
    public let balanceAsOf: Date?
    /// Today's spend.
    public let todaySpend: String
    /// This month's spend.
    public let monthSpend: String
    /// This month's income.
    public let monthIncome: String
    /// Up to ``WidgetSnapshotBuilder/recentTransactionLimit`` recent transactions, newest first.
    public let recentRows: [RecentRow]
    /// Up to ``WidgetSnapshotBuilder/topCategoryLimit`` categories, highest spend first.
    public let categoryRows: [CategoryRow]

    /// Every trend day the snapshot has, oldest first.
    private let trendBars: [TrendBar]
    /// The same days' spend as `Decimal`, so a period total is exact.
    private let trendAmounts: [Decimal]
    /// The formatting for period totals.
    private let moneyFormat: MoneyFormat

    /// Builds the display model.
    ///
    /// - Parameters:
    ///   - snapshot: The snapshot to show.
    ///   - hideAmounts: Whether to replace every monetary string with ``hiddenAmount``.
    ///   - moneyFormat: The formatting; normally the snapshot's currency and grouping.
    /// - Returns: `nil` when any amount in the snapshot cannot be read, which a widget treats like a
    ///   corrupt snapshot.
    public init?(snapshot: WidgetSnapshot, hideAmounts: Bool, moneyFormat: MoneyFormat) {
        self.init(snapshot: snapshot, hideAmounts: hideAmounts, moneyFormat: moneyFormat, isPlaceholder: false)
    }

    private init?(snapshot: WidgetSnapshot, hideAmounts: Bool, moneyFormat: MoneyFormat, isPlaceholder: Bool) {
        let read = WidgetSnapshot.decimal(from:)
        guard let balance = read(snapshot.balance),
              let todaySpend = read(snapshot.todaySpend),
              let monthSpend = read(snapshot.monthSpend),
              let monthIncome = read(snapshot.monthIncome)
        else { return nil }

        let money = { (amount: Decimal) in
            hideAmounts ? Self.hiddenAmount : moneyFormat.currencyString(from: amount)
        }

        var trendBars: [TrendBar] = []
        var trendAmounts: [Decimal] = []
        for point in snapshot.trend {
            guard let spend = read(point.spend) else { return nil }
            trendBars.append(TrendBar(date: point.date, spend: Self.double(spend), amount: money(spend)))
            trendAmounts.append(spend)
        }

        var recentRows: [RecentRow] = []
        for transaction in snapshot.recentTransactions.prefix(WidgetSnapshotBuilder.recentTransactionLimit) {
            guard let amount = read(transaction.amount) else { return nil }
            let magnitude = abs(amount)
            let isCredit = transaction.direction == .credit
            recentRows.append(RecentRow(
                id: transaction.id,
                merchant: transaction.merchant,
                categoryName: transaction.categoryName,
                symbolName: transaction.symbolName,
                colorToken: transaction.colorToken,
                amount: money(isCredit ? magnitude : -magnitude),
                spokenAmount: money(magnitude),
                isCredit: isCredit,
                occurredAt: transaction.occurredAt
            ))
        }

        var categoryRows: [CategoryRow] = []
        for category in snapshot.topCategories.prefix(WidgetSnapshotBuilder.topCategoryLimit) {
            guard let amount = read(category.amount), let share = read(category.share) else { return nil }
            categoryRows.append(CategoryRow(
                name: category.name,
                symbolName: category.symbolName,
                colorToken: category.colorToken,
                amount: money(amount),
                share: min(max(Self.double(share) / 100, 0), 1)
            ))
        }

        self.isPlaceholder = isPlaceholder
        self.amountsHidden = hideAmounts
        self.balance = money(balance)
        self.isBalanceNegative = !hideAmounts && balance < 0
        self.balanceAsOf = snapshot.balanceAsOf
        self.todaySpend = money(todaySpend)
        self.monthSpend = money(monthSpend)
        self.monthIncome = money(monthIncome)
        self.recentRows = recentRows
        self.categoryRows = categoryRows
        self.trendBars = trendBars
        self.trendAmounts = trendAmounts
        self.moneyFormat = moneyFormat
    }

    /// Reads the stored snapshot and builds its display model for an instant, with the snapshot's
    /// own currency and grouping.
    ///
    /// - Parameters:
    ///   - store: The snapshot store, normally ``FileWidgetSnapshotStore`` over
    ///     ``SharedContainer/widgetSnapshotURL``.
    ///   - hideAmounts: Whether to hide every amount.
    ///   - date: The instant the widget draws for; a snapshot from an earlier day is rolled over to
    ///     it (see ``WidgetSnapshot/rolledOver(to:calendar:)``).
    ///   - calendar: The calendar that defines days and months.
    ///   - locale: The locale for ``NumberGrouping/system`` grouping.
    /// - Returns: `nil` when the snapshot is missing, corrupt, or of an unsupported version; the
    ///   widget then draws ``placeholder``.
    public static func load(
        from store: any WidgetSnapshotStore,
        hideAmounts: Bool,
        at date: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> WidgetDisplayModel? {
        guard let snapshot = store.read() else { return nil }
        return WidgetDisplayModel(
            snapshot: snapshot.rolledOver(to: date, calendar: calendar),
            hideAmounts: hideAmounts,
            moneyFormat: MoneyFormat(currencyCode: snapshot.currencyCode, grouping: snapshot.numberGrouping, locale: locale)
        )
    }

    /// The stand-in drawn, redacted, when there is no snapshot to show.
    ///
    /// It is filled from ``WidgetSnapshot/sample(now:calendar:)`` so the redaction keeps the shape of
    /// real content; its values are never meant to be read.
    public static let placeholder: WidgetDisplayModel = {
        let sample = WidgetSnapshot.sample()
        let format = MoneyFormat(currencyCode: sample.currencyCode, grouping: sample.numberGrouping)
        guard let model = WidgetDisplayModel(snapshot: sample, hideAmounts: false, moneyFormat: format, isPlaceholder: true)
        else { fatalError("The built-in sample snapshot must always be readable.") }
        return model
    }()

    /// The trend for the last `days` days the snapshot holds, with the period's total.
    ///
    /// - Parameter days: The window, such as 7 or 30; the snapshot holds at most 30 days, so a
    ///   longer window returns what there is.
    public func trend(days: Int) -> Trend {
        let count = max(days, 0)
        let amounts = trendAmounts.suffix(count)
        let total = amounts.reduce(Decimal.zero, +)
        return Trend(
            bars: Array(trendBars.suffix(count)),
            total: amountsHidden ? Self.hiddenAmount : moneyFormat.currencyString(from: total),
            hasSpend: amounts.contains { $0 > 0 }
        )
    }

    private static func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    /// One day of the trend.
    public struct TrendBar: Equatable, Sendable {
        /// The day's first instant.
        public let date: Date
        /// The day's spend as a chart value; kept when amounts are hidden, since it only sizes a bar.
        public let spend: Double
        /// The day's spend as display text.
        public let amount: String
    }

    /// A window of the trend.
    public struct Trend: Equatable, Sendable {
        /// The days, oldest first.
        public let bars: [TrendBar]
        /// The window's total spend as display text.
        public let total: String
        /// Whether any day in the window has spend, so an empty window can say so instead of drawing
        /// flat bars.
        public let hasSpend: Bool
    }

    /// One recent transaction.
    public struct RecentRow: Equatable, Sendable, Identifiable {
        /// The transaction's identity.
        public let id: UUID
        /// The merchant as the app displays it.
        public let merchant: String
        /// The category's name.
        public let categoryName: String
        /// The category's SF Symbol.
        public let symbolName: String
        /// The category's palette token.
        public let colorToken: String
        /// The signed amount as the app shows it: negative for money that left, e.g. `-$12.50`.
        public let amount: String
        /// The unsigned amount, for a spoken "spent" or "received" that carries the direction.
        public let spokenAmount: String
        /// Whether the money arrived.
        public let isCredit: Bool
        /// The transaction's reporting date.
        public let occurredAt: Date
    }

    /// One top category.
    public struct CategoryRow: Equatable, Sendable, Identifiable {
        /// The category's name, unique within the list.
        public var id: String { name }
        /// The category's name.
        public let name: String
        /// The category's SF Symbol.
        public let symbolName: String
        /// The category's palette token.
        public let colorToken: String
        /// The category's spend this month.
        public let amount: String
        /// The category's fraction of this month's spend, 0 through 1. The top categories' shares
        /// need not add up to 1, because spend outside them is not listed.
        public let share: Double
    }
}
