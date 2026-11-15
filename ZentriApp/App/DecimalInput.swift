import Foundation

/// Reads a typed amount the way the decimal pad offers it in a given locale.
///
/// Onboarding's opening balance and Settings' opening and "Set balance" fields share this parser, so
/// every balance a person types is read by the same rules.
enum DecimalInput {
    /// Parses typed text, accepting the separators the decimal pad offers in `locale`.
    ///
    /// The pad shows the locale's separators, so in de_DE `1,5` is one and a half and a pasted
    /// `1.000,50` is a thousand and fifty cents. Parsing those as invariant text would turn them
    /// into `15` and `1.00050`. The guards reject the shapes a second separator or a stray sign
    /// would otherwise turn into a wrong number.
    ///
    /// - Returns: The number, or `nil` when the text is not one.
    static func decimal(from text: String, locale: Locale) -> Decimal? {
        let digits = normalized(text, locale: locale)
        guard
            digits.contains(where: \.isNumber),
            digits.filter({ $0 == "." }).count <= 1,
            !digits.dropFirst().contains("-")
        else {
            return nil
        }
        return Decimal(string: digits, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Rewrites typed text in the `.`-decimal form the parser reads, using the locale's separators.
    ///
    /// Grouping goes first: a comma-grouping locale's decimal separator is `.`, so replacing the
    /// decimal before dropping the grouping would lose the point in `10,00,000.00`. When the locale
    /// has no separator to replace, `.` stays the decimal separator.
    private static func normalized(_ text: String, locale: Locale) -> String {
        var normalized = text
        if let groupingSeparator = locale.groupingSeparator, !groupingSeparator.isEmpty {
            normalized = normalized.replacing(groupingSeparator, with: "")
        }
        if let decimalSeparator = locale.decimalSeparator, !decimalSeparator.isEmpty {
            normalized = normalized.replacing(decimalSeparator, with: ".")
        }
        return normalized.filter { $0.isNumber || $0 == "." || $0 == "-" }
    }
}
