import Foundation

extension WidgetSnapshot {
    /// Reads one of the snapshot's decimal-string amounts back into a `Decimal`.
    ///
    /// The builder writes amounts with `NSDecimalNumber`, so they always use a `.` separator, a plain
    /// `-` sign, and no grouping. They are read with the invariant `en_US_POSIX` locale so a device
    /// in a comma-decimal region cannot misread them, and the whole text must have that shape:
    /// `Decimal(string:)` alone would silently stop at a grouping separator or stray letter and
    /// return the prefix.
    ///
    /// - Parameter text: An amount such as `-12.5`.
    /// - Returns: The amount, or `nil` when the text is not one the builder could have written.
    public static func decimal(from text: String) -> Decimal? {
        guard text.wholeMatch(of: /-?[0-9]+(\.[0-9]+)?/) != nil else { return nil }
        return Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
    }
}
