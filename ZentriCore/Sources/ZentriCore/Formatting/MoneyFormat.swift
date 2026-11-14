import Foundation

/// Formats decimal amounts with the app's currency and number grouping.
///
/// ``NumberGrouping/western`` and ``NumberGrouping/indian`` are explicit,
/// locale-independent modes: they format with the invariant `en_US_POSIX`
/// locale, so amounts always use Latin digits, `,` as the grouping separator,
/// and `.` as the decimal separator whatever ``locale`` is injected.
/// ``NumberGrouping/system`` is the only mode that inherits the locale's digit
/// shapes, grouping sizes, and separators.
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

    /// The locale the explicit grouping modes format with. CLDR rules from the
    /// injected locale, such as `minimumGroupingDigits`, must not leak into
    /// `.western` or `.indian` (e.g. `es_ES` would drop a 4-digit separator).
    private static let explicitGroupingLocale = Locale(identifier: "en_US_POSIX")

    public init(currencyCode: String, grouping: NumberGrouping, locale: Locale = .current) {
        self.currencyCode = currencyCode
        self.grouping = grouping
        self.locale = locale
    }

    /// The amount with grouping separators and exactly two fraction digits.
    public func numberString(from amount: Decimal) -> String {
        string(from: amount, using: makeFormatter())
    }

    /// The amount prefixed with its currency symbol and no separating space.
    ///
    /// Negative amounts place the sign before the symbol, e.g. `-$1,234.50`.
    public func currencyString(from amount: Decimal) -> String {
        let formatter = makeFormatter()
        let symbol = CurrencyCatalog.symbol(for: currencyCode)
        guard amount < 0 else {
            return symbol + string(from: amount, using: formatter)
        }
        // Format the magnitude so the sign can lead the symbol; concatenating
        // the formatted negative amount would produce `$-1,234.50`.
        return (formatter.minusSign ?? "-") + symbol + string(from: -amount, using: formatter)
    }

    private func makeFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        // `.system` is the only locale-inheriting mode; the explicit modes use
        // the invariant locale so their digits and separators are deterministic.
        formatter.locale = grouping == .system ? locale : Self.explicitGroupingLocale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        switch grouping {
        case .system:
            // Keep the locale's own grouping sizes and separators.
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

    private func string(from amount: Decimal, using formatter: NumberFormatter) -> String {
        // A formatter only fails for values it cannot represent, so the raw
        // decimal is a safe fallback.
        let number = NSDecimalNumber(decimal: amount)
        return formatter.string(from: number) ?? amount.description
    }
}
