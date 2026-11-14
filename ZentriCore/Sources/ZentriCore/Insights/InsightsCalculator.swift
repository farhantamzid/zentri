import Foundation

/// Computes the insights for one period from value snapshots, without reading a store or a clock.
///
/// The calculator is pure: the same snapshots, period, and calendar always produce the same summary.
/// The `transactions` argument is the caller's working set, typically every transaction it has. Entries
/// outside the period still feed the six-month income/expense series and the previous-month comparison,
/// but never the period's totals. Every ordering is defined explicitly, and every division is guarded, so
/// the output never depends on the device's locale, the hash order of a dictionary, or the clock.
public enum InsightsCalculator: Sendable {
    /// The number of months in the income/expense series, ending with the period's month.
    public static let monthlyHistoryMonths = 6
    /// The number of merchants a summary ranks.
    public static let merchantLimit = 5
    /// The number of transactions a summary ranks.
    public static let largestTransactionLimit = 5
    /// The number of month-over-month category observations a summary produces.
    public static let categoryObservationLimit = 3

    /// The label used when a spend transaction has no merchant.
    private static let unknownMerchantName = "Unknown merchant"

    /// Summarizes the transactions that belong to a period.
    ///
    /// Totals, shares, merchants, daily spend, the six-month series, and the largest transactions work for
    /// any period. The month-over-month fields — `CategoryTotal.previousAmount`,
    /// `CategoryTotal.changePercent`, and the month-over-month category observations — additionally assume
    /// the period is exactly one calendar month: it must start at the month's first instant and end inside
    /// that month's last second (see `spansCalendarMonth(_:calendar:)`). They compare the period with the
    /// calendar month before the one containing `period.start`, which only describes the same range as the
    /// totals when the period is that month. For any other period the summary still reports everything
    /// else, `previousAmount` keeps the actual previous-month figure, and `changePercent` is `nil` so no
    /// observation claims a comparison the period does not support.
    ///
    /// - Parameters:
    ///   - transactions: The working set to summarize, including transactions outside the period.
    ///   - period: The inclusive range of dates the period's totals cover.
    ///   - calendar: The calendar that defines days, months, and the previous month. Pass a fixed
    ///     calendar to make the result independent of the device's time zone and locale.
    /// - Returns: The period's summary, or an empty summary when the period's end precedes its start.
    public static func summary(
        transactions: [TransactionSnapshot],
        period: InsightsPeriod,
        calendar: Calendar = .current
    ) -> InsightsSummary {
        guard period.start <= period.end else { return .empty(period: period) }

        let periodTransactions = transactions
            .filter { !$0.isTransfer && period.start <= $0.occurredAt && $0.occurredAt <= period.end }
            .sorted(by: comesBefore)
        let spends = periodTransactions.filter { $0.direction == .debit }
        let totalSpend = sum(spends)
        let totalIncome = sum(periodTransactions.filter { $0.direction == .credit })

        let monthStart = startOfMonth(period.start, calendar: calendar)
        let categories = categoryTotals(
            spends: spends,
            totalSpend: totalSpend,
            previousMonthSpends: previousMonthSpends(
                startingAt: monthStart,
                transactions: transactions,
                calendar: calendar
            ),
            reportsChangeFromPreviousMonth: spansCalendarMonth(period, calendar: calendar)
        )
        let merchants = merchantTotals(spends: spends)

        return InsightsSummary(
            period: period,
            totalSpend: totalSpend,
            totalIncome: totalIncome,
            transactionCount: periodTransactions.count,
            categoryTotals: categories,
            merchantTotals: merchants,
            dailySpend: dailySpend(spends: spends, period: period, calendar: calendar),
            monthlyIncomeExpense: monthlyIncomeExpense(
                transactions: transactions,
                endingAt: monthStart,
                calendar: calendar
            ),
            largestTransactions: Array(
                periodTransactions.sorted(by: largestFirst).prefix(largestTransactionLimit)
            ),
            observations: observations(categoryTotals: categories, merchantTotals: merchants)
        )
    }
}

// MARK: - Totals

private extension InsightsCalculator {
    /// The sum of the transactions' magnitudes.
    static func sum(_ transactions: [TransactionSnapshot]) -> Decimal {
        transactions.reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// The order that makes grouping independent of the caller's array order: oldest first, then by identity.
    static func comesBefore(_ lhs: TransactionSnapshot, _ rhs: TransactionSnapshot) -> Bool {
        if lhs.occurredAt != rhs.occurredAt {
            return lhs.occurredAt < rhs.occurredAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    /// The order of the largest transactions: highest amount first, then newest first.
    static func largestFirst(_ lhs: TransactionSnapshot, _ rhs: TransactionSnapshot) -> Bool {
        if lhs.amount != rhs.amount {
            return lhs.amount > rhs.amount
        }
        if lhs.occurredAt != rhs.occurredAt {
            return lhs.occurredAt > rhs.occurredAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

// MARK: - Categories

private extension InsightsCalculator {
    /// A category's running totals while the period is grouped.
    struct CategoryAccumulator {
        /// The category's display name as first written in the canonical order.
        let name: String
        /// The category's identity as first written in the canonical order.
        let categoryID: UUID?
        /// The category's SF Symbol as first written in the canonical order.
        let symbolName: String
        /// The category's color token as first written in the canonical order.
        let colorToken: String
        /// The spend the category has received so far.
        var amount: Decimal
        /// The number of spend transactions in the category.
        var transactionCount: Int
    }

    /// Groups spend transactions by category name, ignoring categories without spend.
    ///
    /// The name is whitespace-normalized, and grouping ignores case, so "Dining" and " dining " share a
    /// total. The first transaction in the canonical order supplies the displayed name and styling.
    static func categoryAccumulators(
        for transactions: [TransactionSnapshot]
    ) -> [String: CategoryAccumulator] {
        var accumulators: [String: CategoryAccumulator] = [:]
        for transaction in transactions {
            let name = normalized(transaction.categoryName)
            let key = name.lowercased()
            if var accumulator = accumulators[key] {
                accumulator.amount += transaction.amount
                accumulator.transactionCount += 1
                accumulators[key] = accumulator
            } else {
                accumulators[key] = CategoryAccumulator(
                    name: name,
                    categoryID: transaction.categoryID,
                    symbolName: transaction.symbolName,
                    colorToken: transaction.colorToken,
                    amount: transaction.amount,
                    transactionCount: 1
                )
            }
        }
        return accumulators.filter { $0.value.amount > 0 }
    }

    /// The period's categories, highest spend first, with shares and, for a one-month period, the
    /// month-over-month changes.
    static func categoryTotals(
        spends: [TransactionSnapshot],
        totalSpend: Decimal,
        previousMonthSpends: [TransactionSnapshot],
        reportsChangeFromPreviousMonth: Bool
    ) -> [CategoryTotal] {
        let current = categoryAccumulators(for: spends)
        let previous = categoryAccumulators(for: previousMonthSpends)
        let ordered = current.values.sorted(by: categoryComesBefore)
        let shares = shares(for: ordered.map(\.amount), totalSpend: totalSpend)

        return ordered.enumerated().map { index, accumulator in
            let previousAmount = previous[accumulator.name.lowercased()]?.amount ?? 0
            return CategoryTotal(
                categoryID: accumulator.categoryID,
                categoryName: accumulator.name,
                symbolName: accumulator.symbolName,
                colorToken: accumulator.colorToken,
                amount: accumulator.amount,
                share: shares[index],
                transactionCount: accumulator.transactionCount,
                previousAmount: previousAmount,
                changePercent: reportsChangeFromPreviousMonth
                    ? changePercent(current: accumulator.amount, previous: previousAmount)
                    : nil
            )
        }
    }

    /// The order of the category list: highest spend first, then by name.
    static func categoryComesBefore(_ lhs: CategoryAccumulator, _ rhs: CategoryAccumulator) -> Bool {
        if lhs.amount != rhs.amount {
            return lhs.amount > rhs.amount
        }
        return lhs.name < rhs.name
    }

    /// The spend in the month before the supplied month start.
    static func previousMonthSpends(
        startingAt monthStart: Date,
        transactions: [TransactionSnapshot],
        calendar: Calendar
    ) -> [TransactionSnapshot] {
        guard let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: monthStart) else {
            return []
        }
        return spends(
            inMonthStartingAt: previousMonthStart,
            transactions: transactions,
            calendar: calendar
        )
    }

    /// The non-transfer spends in the month that starts at the supplied date.
    static func spends(
        inMonthStartingAt monthStart: Date,
        transactions: [TransactionSnapshot],
        calendar: Calendar
    ) -> [TransactionSnapshot] {
        let monthEnd = startOfMonth(adding: 1, to: monthStart, calendar: calendar)
        return transactions
            .filter {
                !$0.isTransfer && $0.direction == .debit
                    && monthStart <= $0.occurredAt && $0.occurredAt < monthEnd
            }
            .sorted(by: comesBefore)
    }
}

// MARK: - Merchants

private extension InsightsCalculator {
    /// A merchant's running totals while the period is grouped.
    struct MerchantAccumulator {
        /// The merchant's display name as first written in the canonical order.
        let merchant: String
        /// The spend the merchant has received so far.
        var amount: Decimal
        /// The number of spend transactions with the merchant.
        var transactionCount: Int
    }

    /// The period's merchants, highest spend first, then by transaction count and name.
    ///
    /// Merchants are grouped case-insensitively after whitespace normalization, so "Grab" and " GRAB "
    /// share a total. A spend without a merchant is reported as `Unknown merchant`.
    static func merchantTotals(spends: [TransactionSnapshot]) -> [MerchantTotal] {
        var accumulators: [String: MerchantAccumulator] = [:]
        for spend in spends {
            let merchant = normalized(spend.merchant)
            let key = merchant.lowercased()
            if var accumulator = accumulators[key] {
                accumulator.amount += spend.amount
                accumulator.transactionCount += 1
                accumulators[key] = accumulator
            } else {
                accumulators[key] = MerchantAccumulator(
                    merchant: merchant.isEmpty ? unknownMerchantName : merchant,
                    amount: spend.amount,
                    transactionCount: 1
                )
            }
        }

        return accumulators.values
            .filter { $0.amount > 0 }
            .sorted(by: merchantComesBefore)
            .prefix(merchantLimit)
            .map {
                MerchantTotal(
                    merchant: $0.merchant,
                    amount: $0.amount,
                    transactionCount: $0.transactionCount
                )
            }
    }

    /// The order of the merchant list: highest spend first, then most transactions, then by name.
    static func merchantComesBefore(_ lhs: MerchantAccumulator, _ rhs: MerchantAccumulator) -> Bool {
        if lhs.amount != rhs.amount {
            return lhs.amount > rhs.amount
        }
        if lhs.transactionCount != rhs.transactionCount {
            return lhs.transactionCount > rhs.transactionCount
        }
        return lhs.merchant < rhs.merchant
    }
}

// MARK: - Time series

private extension InsightsCalculator {
    /// One entry for every day in the period, including days without spend.
    static func dailySpend(
        spends: [TransactionSnapshot],
        period: InsightsPeriod,
        calendar: Calendar
    ) -> [DailySpend] {
        var amountsByDay: [Date: Decimal] = [:]
        for spend in spends {
            amountsByDay[calendar.startOfDay(for: spend.occurredAt), default: 0] += spend.amount
        }

        var days: [DailySpend] = []
        var dayStart = calendar.startOfDay(for: period.start)
        let lastDayStart = calendar.startOfDay(for: period.end)
        while dayStart <= lastDayStart {
            days.append(DailySpend(date: dayStart, amount: amountsByDay[dayStart] ?? 0))
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            dayStart = nextDay
        }
        return days
    }

    /// The six months ending with the supplied month, oldest first, including months without activity.
    static func monthlyIncomeExpense(
        transactions: [TransactionSnapshot],
        endingAt monthStart: Date,
        calendar: Calendar
    ) -> [MonthlyIncomeExpense] {
        var months: [Date] = []
        var cursor = monthStart
        for _ in 0..<monthlyHistoryMonths {
            months.insert(cursor, at: 0)
            guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: cursor) else {
                break
            }
            cursor = previousMonth
        }

        return months.map { monthStart in
            let monthEnd = startOfMonth(adding: 1, to: monthStart, calendar: calendar)
            let inMonth = transactions.filter {
                !$0.isTransfer && monthStart <= $0.occurredAt && $0.occurredAt < monthEnd
            }
            return MonthlyIncomeExpense(
                month: monthStart,
                income: sum(inMonth.filter { $0.direction == .credit }),
                spend: sum(inMonth.filter { $0.direction == .debit })
            )
        }
    }

    /// The start of the month that contains the date.
    static func startOfMonth(_ date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// The start of the month `months` months after the supplied month start.
    static func startOfMonth(adding months: Int, to monthStart: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .month, value: months, to: monthStart) ?? monthStart
    }

    /// Whether the period is exactly the calendar month that contains its start.
    ///
    /// A month period starts at the month's first instant and ends inside the month's last second, which
    /// accepts the inclusive end instants callers use for a month (`23:59:59` and its sub-second
    /// neighbours). Anything else — a week, a rolling window, a month that starts or ends early, or a
    /// period that runs into the next month — is not that month, so comparing its totals with the whole
    /// previous month would describe a different range than the totals do.
    static func spansCalendarMonth(_ period: InsightsPeriod, calendar: Calendar) -> Bool {
        let monthStart = startOfMonth(period.start, calendar: calendar)
        guard period.start == monthStart else { return false }
        let nextMonthStart = startOfMonth(adding: 1, to: monthStart, calendar: calendar)
        guard let lastSecond = calendar.date(byAdding: .second, value: -1, to: nextMonthStart),
              lastSecond < nextMonthStart
        else {
            return false
        }
        return lastSecond <= period.end && period.end < nextMonthStart
    }
}

// MARK: - Observations

private extension InsightsCalculator {
    /// The deterministic, user-facing observations about the period.
    ///
    /// A category observation appears only when the previous month has spend in the same category, because
    /// a change from nothing has no meaningful percentage, and only for a one-calendar-month period,
    /// because otherwise the comparison would describe a different range than the totals (see the
    /// precondition documented on `summary(transactions:period:calendar:)`). A non-month period therefore
    /// produces only the top-merchant sentence.
    ///
    /// The spec's peak-day observation ("You spent 3.2× your daily average on 12 Oct") is intentionally
    /// deferred: it belongs to Task 13 and is not produced here. Only rendering the date ("12 Oct") needs a
    /// locale-aware formatter — the peak day and the ratio (peak day spend ÷ the period's average daily
    /// spend) are locale-free and computable from what the summary already publishes. Task 13 computes it
    /// from `InsightsSummary.dailySpend` and `InsightsSummary.totalSpend`, or from an additive helper added
    /// alongside them, and formats the date in the UI.
    static func observations(
        categoryTotals: [CategoryTotal],
        merchantTotals: [MerchantTotal]
    ) -> [String] {
        var observations: [String] = []
        let comparable = categoryTotals.filter { $0.changePercent != nil }
        for total in comparable.prefix(categoryObservationLimit) {
            guard let changePercent = total.changePercent else { continue }
            let wholePercent = rounded(changePercent, scale: 0)
            if wholePercent == 0 {
                observations.append("\(total.categoryName) is unchanged from last month.")
            } else if wholePercent < 0 {
                observations.append(
                    "\(total.categoryName) is \(percentText(abs(wholePercent)))% lower than last month."
                )
            } else {
                observations.append(
                    "\(total.categoryName) is \(percentText(wholePercent))% higher than last month."
                )
            }
        }

        if let top = merchantTotals.first {
            let noun = top.transactionCount == 1 ? "transaction" : "transactions"
            observations.append("\(top.merchant) is your top merchant with \(top.transactionCount) \(noun).")
        }
        return observations
    }

    /// The whole-number text of a percentage, e.g. "24"; never locale-formatted.
    static func percentText(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}

// MARK: - Decimal arithmetic

private extension InsightsCalculator {
    /// The share of each amount in the total, rounded to two decimals and adding up to exactly 100.
    ///
    /// The rounding remainder goes to the largest entry, which is the first one because callers sort the
    /// amounts first. That keeps a donut chart closed without making any share depend on locale or hash order.
    static func shares(for amounts: [Decimal], totalSpend: Decimal) -> [Decimal] {
        guard totalSpend > 0 else { return amounts.map { _ in 0 } }
        var shares = amounts.map { rounded(percent(of: $0, total: totalSpend), scale: 2) }
        let residual = 100 - shares.reduce(Decimal.zero, +)
        if residual != 0, !shares.isEmpty {
            shares[0] += residual
        }
        return shares
    }

    /// The signed percentage change from the previous amount, or `nil` when there is nothing to compare.
    static func changePercent(current: Decimal, previous: Decimal) -> Decimal? {
        guard previous > 0 else { return nil }
        return rounded(percent(of: current - previous, total: previous), scale: 2)
    }

    /// The percentage `part` is of `total`. Callers never pass a zero total, but the guard keeps a stray
    /// zero from reaching `NSDecimalNumber`, which raises for division by zero.
    static func percent(of part: Decimal, total: Decimal) -> Decimal {
        guard total != 0 else { return 0 }
        return NSDecimalNumber(decimal: part)
            .dividing(by: NSDecimalNumber(decimal: total))
            .decimalValue * 100
    }

    /// The value rounded to the supplied number of decimal places.
    static func rounded(_ value: Decimal, scale: Int) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, scale, .plain)
        return result
    }

    /// The value with leading, trailing, and repeated whitespace removed.
    static func normalized(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
