import Foundation

extension Decimal {
    /// The value rounded to a whole number, halves away from zero — the rounding
    /// `InsightsCalculator` uses for its month-over-month sentences.
    var roundedToWholeNumber: Int {
        var input = self
        var result = Decimal()
        NSDecimalRound(&result, &input, 0, .plain)
        return NSDecimalNumber(decimal: result).intValue
    }
}
