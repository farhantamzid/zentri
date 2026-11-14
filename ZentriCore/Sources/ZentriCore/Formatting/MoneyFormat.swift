import Foundation

/// Formats decimal amounts with the app's currency and number grouping.
///
/// The formatter is deliberately created per call: `NumberFormatter` is not
/// `Sendable`, so a `Sendable` value such as this one cannot store one.
public struct MoneyFormat: Sendable {
    /// The currency whose symbol prefixes formatted amounts.
    public let currencyCode: String
    /// The grouping applied to the integer part of formatted amounts.
    public let grouping: NumberGrouping
    /// The locale supplying decimal digits and, for ``NumberGrouping/system``, separators.
    public let locale: Locale

    public init(currencyCode: String, grouping: NumberGrouping, locale: Locale = .current) {
        self.currencyCode = currencyCode
        self.grouping = grouping
        self.locale = locale
    }

    /// The amount with grouping separators and exactly two fraction digits.
    public func numberString(from amount: Decimal) -> String {
        let formatter = makeFormatter()
        // A formatter only fails for values it cannot represent, so the raw
        // decimal is a safe fallback.
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? amount.description
    }

    /// The amount prefixed with its currency symbol and no separating space.
    public func currencyString(from amount: Decimal) -> String {
        CurrencyCatalog.symbol(for: currencyCode) + numberString(from: amount)
    }

    private func makeFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        switch grouping {
        case .system:
            // Keep the locale's own grouping and separator settings.
            break
        case .western:
            formatter.groupingSize = 3
            formatter.secondaryGroupingSize = 0
            formatter.groupingSeparator = ","
            formatter.decimalSeparator = "."
        case .indian:
            formatter.groupingSize = 3
            formatter.secondaryGroupingSize = 2
            formatter.groupingSeparator = ","
            formatter.decimalSeparator = "."
        }

        return formatter
    }
}
