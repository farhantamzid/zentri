import Foundation
import ZentriCore

/// One deterministic statement about the selected month, such as "Dining is 24% lower than last
/// month."
///
/// The cases carry values rather than sentences, so the screen writes each sentence from the string
/// catalog in the person's language and formats the date for their locale. `InsightsSummary`'s own
/// `observations` are pre-rendered English and are not shown.
enum InsightsObservation: Hashable, Sendable {
    /// A category's spend compared with the previous month, as a signed whole percentage.
    case categoryChange(categoryName: String, wholePercent: Int)
    /// The day with the most spend and how many times the average day it was.
    case peakDay(date: Date, ratio: Decimal)
    /// The merchant with the most spend and how many spends it had.
    case topMerchant(merchant: String, transactionCount: Int)

    /// How many times the average day the peak day must be before it is worth a sentence; a peak
    /// close to the average says nothing.
    static let peakDayMinimumRatio: Decimal = 2

    /// The month's observations: the month-over-month changes of the largest categories that have a
    /// previous month to compare with, then the peak day, then the top merchant.
    ///
    /// The category changes follow the calculator's own rules: a category needs spend in the previous
    /// month (`changePercent` is `nil` otherwise, and also for a period that is not a calendar month),
    /// and at most `InsightsCalculator.categoryObservationLimit` are reported. A category whose spend
    /// fell to nothing this month is not in the month's totals, so it has no sentence.
    static func observations(summary: InsightsSummary, peakDay: PeakDaySpend?) -> [InsightsObservation] {
        let changes = summary.categoryTotals.compactMap { total in
            total.changePercent.map {
                InsightsObservation.categoryChange(categoryName: total.categoryName, wholePercent: wholePercent($0))
            }
        }
        var observations = Array(changes.prefix(InsightsCalculator.categoryObservationLimit))

        if let peakDay, peakDay.ratioToAverage >= peakDayMinimumRatio {
            observations.append(.peakDay(date: peakDay.date, ratio: peakDay.ratioToAverage))
        }
        if let top = summary.merchantTotals.first {
            observations.append(.topMerchant(merchant: top.merchant, transactionCount: top.transactionCount))
        }
        return observations
    }

    /// The percentage rounded to a whole number, halves away from zero, as the calculator rounds.
    private static func wholePercent(_ value: Decimal) -> Int {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 0, .plain)
        return NSDecimalNumber(decimal: result).intValue
    }
}
