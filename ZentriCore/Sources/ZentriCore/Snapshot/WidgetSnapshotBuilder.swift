import Foundation

/// Builds the widget snapshot from store values, without touching SwiftData or a clock.
///
/// The builder is the single place the widget's numbers are decided: the balance comes from
/// ``BalanceCalculator`` and the spend, income, trend, and category figures from
/// ``InsightsCalculator``, so a widget can never disagree with the app's own screens. Only the
/// non-archived accounts are included, and every amount leaves as a decimal string.
public struct WidgetSnapshotBuilder: Sendable {
    /// The number of transactions the recent list shows.
    public static let recentTransactionLimit = 6
    /// The number of categories the top list shows.
    public static let topCategoryLimit = 4
    /// The number of days the trend covers, ending today.
    public static let trendDayCount = 30

    /// The category a transaction without one is shown as.
    ///
    /// It is the same seeded fallback ``CategorizationService`` uses, so an uncategorized
    /// transaction cannot invent a category name the app has never seen.
    private static let unknownCategoryName = CategorizationService.fallbackCategoryName
    /// The SF Symbol used when neither the transaction nor the catalog supplies one.
    private static let unknownSymbolName = "ellipsis"
    /// The color token used when neither the transaction nor the catalog supplies one.
    private static let unknownColorToken = "slate"

    public init() {}

    /// An account and its checkpoints, without any SwiftData dependency.
    public struct AccountInput: Sendable, Equatable {
        /// The account's stable identity.
        public let id: UUID
        /// Whether the account is archived and therefore left out of the snapshot.
        public let isArchived: Bool
        /// Every checkpoint recorded for the account; the balance uses the newest one.
        public let checkpoints: [CheckpointValue]

        public init(id: UUID, isArchived: Bool = false, checkpoints: [CheckpointValue] = []) {
            self.id = id
            self.isArchived = isArchived
            self.checkpoints = checkpoints
        }
    }

    /// A transaction, with the ingestion instant the balance math needs.
    ///
    /// ``TransactionSnapshot`` has no `recordedAt` because insights never need one; balance math
    /// does, because a checkpoint only applies to transactions recorded after it.
    public struct TransactionInput: Sendable, Equatable, Identifiable {
        /// The transaction's stable identity.
        public let id: UUID
        /// The account the money moved through.
        public let accountID: UUID
        /// The positive magnitude of the movement.
        public let amount: Decimal
        /// Whether the movement left or entered the account.
        public let direction: Direction
        /// The reporting date.
        public let occurredAt: Date
        /// The creation date that drives checkpoint balance math.
        public let recordedAt: Date
        /// The merchant as the app displays it.
        public let merchant: String
        /// The assigned category's identity, when it has one.
        public let categoryID: UUID?
        /// The assigned category's name; empty when the transaction has no category.
        public let categoryName: String
        /// The assigned category's SF Symbol; empty when the transaction has no category.
        public let symbolName: String
        /// The assigned category's color token; empty when the transaction has no category.
        public let colorToken: String
        /// Whether both sides of a transfer are excluded from spend and income.
        public let isTransfer: Bool

        public init(
            id: UUID = UUID(),
            accountID: UUID,
            amount: Decimal,
            direction: Direction,
            occurredAt: Date,
            recordedAt: Date,
            merchant: String,
            categoryID: UUID? = nil,
            categoryName: String = "",
            symbolName: String = "",
            colorToken: String = "",
            isTransfer: Bool = false
        ) {
            self.id = id
            self.accountID = accountID
            self.amount = amount
            self.direction = direction
            self.occurredAt = occurredAt
            self.recordedAt = recordedAt
            self.merchant = merchant
            self.categoryID = categoryID
            self.categoryName = categoryName
            self.symbolName = symbolName
            self.colorToken = colorToken
            self.isTransfer = isTransfer
        }
    }

    /// Builds the snapshot.
    ///
    /// - Parameters:
    ///   - accounts: Every account; archived ones are ignored.
    ///   - transactions: Every transaction; those of archived accounts are ignored.
    ///   - categories: The live catalog, used to style a transaction that carries no category.
    ///   - settings: The currency and grouping the widget formats with.
    ///   - now: The instant the snapshot describes; today and this month end here.
    ///   - calendar: The calendar that defines days and months. Pass a fixed calendar in tests.
    /// - Returns: The snapshot to write for the widgets.
    public func build(
        accounts: [AccountInput],
        transactions: [TransactionInput],
        categories: [CategorySnapshot],
        settings: AppSettings,
        now: Date,
        calendar: Calendar
    ) -> WidgetSnapshot {
        let activeAccounts = accounts.filter { !$0.isArchived }
        let activeAccountIDs = Set(activeAccounts.map(\.id))
        let activeTransactions = transactions.filter { activeAccountIDs.contains($0.accountID) }
        let checkpoints = activeAccounts.flatMap(\.checkpoints)

        let balance = BalanceCalculator.combined(
            accountIDs: activeAccounts.map(\.id),
            checkpoints: checkpoints,
            transactions: activeTransactions.map {
                TransactionValue(
                    accountID: $0.accountID,
                    amount: $0.amount,
                    direction: $0.direction,
                    recordedAt: $0.recordedAt
                )
            }
        )

        let snapshots = activeTransactions.map { snapshot(from: $0, categories: categories) }
        let todayStart = calendar.startOfDay(for: now)
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? todayStart
        let trendStart = calendar.date(byAdding: .day, value: -(Self.trendDayCount - 1), to: todayStart)
            ?? todayStart

        let today = InsightsCalculator.summary(
            transactions: snapshots,
            period: InsightsPeriod(start: todayStart, end: now),
            calendar: calendar
        )
        let month = InsightsCalculator.summary(
            transactions: snapshots,
            period: InsightsPeriod(start: monthStart, end: now),
            calendar: calendar
        )
        let trend = InsightsCalculator.summary(
            transactions: snapshots,
            period: InsightsPeriod(start: trendStart, end: now),
            calendar: calendar
        )

        let recentTransactions = snapshots
            .sorted { lhs, rhs in
                if lhs.occurredAt != rhs.occurredAt {
                    return lhs.occurredAt > rhs.occurredAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .prefix(Self.recentTransactionLimit)
            .map { transaction in
                WidgetSnapshot.RecentTransaction(
                    id: transaction.id,
                    merchant: transaction.merchant,
                    categoryName: transaction.categoryName,
                    symbolName: transaction.symbolName,
                    colorToken: transaction.colorToken,
                    amount: Self.money(transaction.amount),
                    direction: transaction.direction,
                    occurredAt: transaction.occurredAt
                )
            }

        let topCategories = month.categoryTotals
            .prefix(Self.topCategoryLimit)
            .map { category in
                WidgetSnapshot.TopCategory(
                    name: category.categoryName,
                    symbolName: category.symbolName,
                    colorToken: category.colorToken,
                    amount: Self.money(category.amount),
                    share: Self.money(category.share)
                )
            }

        return WidgetSnapshot(
            schemaVersion: WidgetSnapshot.currentSchemaVersion,
            generatedAt: now,
            currencyCode: settings.currencyCode,
            numberGrouping: settings.numberGrouping,
            balance: Self.money(balance),
            balanceAsOf: checkpoints.map(\.recordedAt).max(),
            todaySpend: Self.money(today.totalSpend),
            monthSpend: Self.money(month.totalSpend),
            monthIncome: Self.money(month.totalIncome),
            trend: trend.dailySpend.map { WidgetSnapshot.TrendPoint(date: $0.date, spend: Self.money($0.amount)) },
            recentTransactions: Array(recentTransactions),
            topCategories: Array(topCategories)
        )
    }

    /// The insights projection of a transaction, with its category styling resolved.
    ///
    /// A transaction without a category takes the seeded fallback name, and any missing symbol or
    /// color comes from the live catalog — so a renamed or restyled "Other" reaches the widgets.
    private func snapshot(
        from transaction: TransactionInput,
        categories: [CategorySnapshot]
    ) -> TransactionSnapshot {
        let name = transaction.categoryName.isEmpty
            ? Self.unknownCategoryName
            : transaction.categoryName
        let catalog = categories.first { $0.name == name }
        return TransactionSnapshot(
            id: transaction.id,
            accountID: transaction.accountID,
            amount: transaction.amount,
            direction: transaction.direction,
            occurredAt: transaction.occurredAt,
            merchant: transaction.merchant,
            categoryID: transaction.categoryID ?? catalog?.id,
            categoryName: name,
            symbolName: Self.style(
                transaction.symbolName, catalog: catalog?.symbolName, unknown: Self.unknownSymbolName
            ),
            colorToken: Self.style(
                transaction.colorToken, catalog: catalog?.colorToken, unknown: Self.unknownColorToken
            ),
            isTransfer: transaction.isTransfer
        )
    }

    /// The first non-empty style: the transaction's own, then the catalog's, then the fallback.
    private static func style(_ value: String, catalog: String?, unknown: String) -> String {
        if !value.isEmpty {
            return value
        }
        if let catalog, !catalog.isEmpty {
            return catalog
        }
        return unknown
    }

    /// A decimal amount as the invariant string the widgets read back, e.g. `-12.5`.
    ///
    /// `NSDecimalNumber` writes a plain `-` sign and a `.` separator whatever the device's locale
    /// is, which is what makes the document portable between the app and its extension.
    private static func money(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
