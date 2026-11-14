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

    /// The years a bank message can plausibly name, matching the two-digit-year window.
    ///
    /// Foundation retries a failed strict parse leniently, which reads an impossible day-first
    /// value as a year: `32/11/26` becomes 0032-11-26. Every candidate is therefore checked
    /// against this window, so a malformed date falls back to the receipt time instead of being
    /// recorded thousands of years early.
    private static let plausibleYears = 2000...2099

    /// The formats tried in order when a rule does not name one, most specific first.
    ///
    /// Bank messages most often write the day before the month, either with slashes or dashes,
    /// with or without month names, or as an ISO date.
    private static let commonFormats = [
        "dd/MM/yy",
        "dd/MM/yyyy",
        "dd-MM-yyyy",
        "dd MMM yy",
        "dd MMM yyyy",
        "yyyy-MM-dd",
    ]

    /// Parses `raw` with `format`, or with the common formats when no format is given.
    ///
    /// Returns `receivedAt` when there is no value, when the value does not match the format,
    /// or when no candidate parses to a year in 2000–2099: the receipt time is always a safe
    /// occurrence time, so a malformed date never blocks an otherwise valid transaction.
    public static func date(from raw: String?, format: String?, receivedAt: Date) -> Date? {
        guard let raw = cleaned(raw) else { return receivedAt }
        if let format = cleaned(format) {
            return parse(raw, format: format) ?? receivedAt
        }
        for format in commonFormats {
            if let date = parse(raw, format: format) { return date }
        }
        return receivedAt
    }

    /// A strict parse with no fallback, used to try a combined date and time value first.
    ///
    /// Returns `nil` both for a value the format does not read and for a date whose year is
    /// outside 2000–2099, so a caller can try the next format and finally fall back to the
    /// receipt time.
    static func parse(_ raw: String, format: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = posixLocale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .gmt
        formatter.dateFormat = format
        formatter.isLenient = false
        formatter.twoDigitStartDate = twoDigitStartDate
        guard let date = formatter.date(from: raw), isPlausible(date) else { return nil }
        return date
    }

    /// Whether the date falls in a year a bank message can carry.
    private static func isPlausible(_ date: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return plausibleYears.contains(calendar.component(.year, from: date))
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
