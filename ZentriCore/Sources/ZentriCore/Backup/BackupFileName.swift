import Foundation

/// The names backup files are given.
///
/// Automatic snapshots are named `Zentri-YYYY-MM-DD-HHmm.json` in UTC. UTC keeps the names in time
/// order whatever time zone the device is in and across daylight-saving changes, so rotation can
/// sort by name; the restore browser shows each snapshot's own date in local time. A manual export
/// uses the same stem in the device's time zone, and the exporter adds the backup type's extension.
public enum BackupFileName {
    /// The prefix every backup file name starts with.
    private static let prefix = "Zentri-"

    /// The name of an automatic snapshot taken at `date`.
    public static func snapshot(at date: Date) -> String {
        "\(stem(at: date, timeZone: .gmt)).json"
    }

    /// The name of a manual export made at `date`, without an extension.
    public static func exportStem(at date: Date, timeZone: TimeZone) -> String {
        stem(at: date, timeZone: timeZone)
    }

    /// Whether `name` is an automatic snapshot's name, which is all rotation ever deletes.
    public static func isSnapshot(_ name: String) -> Bool {
        name.wholeMatch(of: #/Zentri-\d{4}-\d{2}-\d{2}-\d{4}\.json/#) != nil
    }

    private static func stem(at date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let style = Date.VerbatimFormatStyle(
            format: """
            \(year: .padded(4))-\(month: .twoDigits)-\(day: .twoDigits)-\
            \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased))\(minute: .twoDigits)
            """,
            locale: nil,
            timeZone: timeZone,
            calendar: calendar
        )
        return prefix + date.formatted(style)
    }
}
