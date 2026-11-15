import Foundation

/// When a widget timeline's entries fall and when WidgetKit should ask for the next timeline.
///
/// A timeline holds an entry for now, one an hour later, and one at the next midnight, so the
/// date-dependent figures roll over at the start of a day (see
/// ``WidgetSnapshot/rolledOver(to:calendar:)``). WidgetKit asks again after an hour; the app also
/// reloads every timeline whenever it writes a new snapshot, so the hour only bounds staleness.
public struct WidgetTimelineSchedule: Equatable, Sendable {
    /// How long a timeline lasts before WidgetKit asks for the next one.
    public static let refreshInterval: TimeInterval = 60 * 60

    /// The entry instants, earliest first.
    public let entryDates: [Date]
    /// When WidgetKit should request a new timeline.
    public let reloadDate: Date

    /// - Parameters:
    ///   - now: The instant the timeline is built.
    ///   - calendar: The calendar that defines midnight.
    public init(now: Date, calendar: Calendar) {
        let nextHour = now.addingTimeInterval(Self.refreshInterval)
        let todayStart = calendar.startOfDay(for: now)
        let midnight = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? nextHour
        entryDates = Array(Set([now, nextHour, midnight])).sorted()
        reloadDate = nextHour
    }
}
