import Foundation

/// Reads the date captured by a rule, using a fixed locale, calendar, and time zone.
///
/// Bank messages are written for the bank's own locale, so parsing must not follow the
/// device: month names are read as English and Latin digits are required. Dates are
/// interpreted in UTC, and two-digit years use a fixed 2000–2099 window, so the same message
/// always produces the same instant.
public enum DateParser {
    /// The fixed locale, so month and day names are read identically on every device.
    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    /// 2000-01-01 UTC, the start of the fixed two-digit-year window.
    private static let twoDigitStartDate = Date(timeIntervalSince1970: 946_684_800)

    /// Parses `raw` with `format`.
    ///
    /// Returns `receivedAt` when there is no format, no value, or the value does not match
    /// the format: the receipt time is always a safe occurrence time, so a malformed date
    /// never blocks an otherwise valid transaction.
    public static func date(from raw: String?, format: String?, receivedAt: Date) -> Date? {
        guard let format = cleaned(format) else { return receivedAt }
        guard let raw = cleaned(raw) else { return receivedAt }
        return parse(raw, format: format) ?? receivedAt
    }

    /// A strict parse with no fallback, used to try a combined date and time value first.
    static func parse(_ raw: String, format: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = posixLocale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .gmt
        formatter.dateFormat = format
        formatter.isLenient = false
        formatter.twoDigitStartDate = twoDigitStartDate
        return formatter.date(from: raw)
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
