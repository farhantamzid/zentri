import Foundation

/// The day with the most spend in a period, compared with the period's average day.
///
/// Every field is a locale-free value, so the sentence that reports it — "You spent 3.2× your daily
/// average on 12 Oct." — is written and its date formatted by the interface, in the person's language.
public struct PeakDaySpend: Sendable, Equatable {
    /// The first instant of the day, as `DailySpend.date` gives it.
    public let date: Date
    /// The spend recorded that day.
    public let amount: Decimal
    /// The period's spend divided by the number of days it covered.
    public let averageDailySpend: Decimal
    /// How many times the average day the peak day's spend is, rounded to one decimal.
    public let ratioToAverage: Decimal

    public init(date: Date, amount: Decimal, averageDailySpend: Decimal, ratioToAverage: Decimal) {
        self.date = date
        self.amount = amount
        self.averageDailySpend = averageDailySpend
        self.ratioToAverage = ratioToAverage
    }
}
