import Foundation
import WidgetKit
import ZentriCore

/// Supplies every Zentri widget from the snapshot the app writes to the App Group.
///
/// The provider never opens SwiftData: it reads the snapshot through ``FileWidgetSnapshotStore``,
/// which treats a missing App Group, a missing file, a corrupt file, or an unknown schema version as
/// no snapshot, and the widget then draws the redacted placeholder with an "Open Zentri" hint.
struct ZentriTimelineProvider: AppIntentTimelineProvider {
    private let store = FileWidgetSnapshotStore(fileURL: SharedContainer.widgetSnapshotURL)

    func placeholder(in context: Context) -> ZentriWidgetEntry {
        // WidgetKit redacts a placeholder itself; the sample only gives it realistic shapes.
        .sample()
    }

    func snapshot(for configuration: ZentriWidgetConfigurationIntent, in context: Context) async -> ZentriWidgetEntry {
        let entry = entry(at: .now, configuration: configuration)
        // The widget gallery shows sample data rather than a placeholder before the app has run.
        if context.isPreview && entry.model.isPlaceholder {
            return .sample(hideAmounts: configuration.hideAmounts, trendPeriod: configuration.trendPeriod)
        }
        return entry
    }

    func timeline(for configuration: ZentriWidgetConfigurationIntent, in context: Context) async -> Timeline<ZentriWidgetEntry> {
        let schedule = WidgetTimelineSchedule(now: .now, calendar: .current)
        let entries = schedule.entryDates.map { entry(at: $0, configuration: configuration) }
        return Timeline(entries: entries, policy: .after(schedule.reloadDate))
    }

    /// The entry for one instant, rolled over to its day.
    private func entry(at date: Date, configuration: ZentriWidgetConfigurationIntent) -> ZentriWidgetEntry {
        ZentriWidgetEntry(
            date: date,
            model: WidgetDisplayModel.load(from: store, hideAmounts: configuration.hideAmounts, at: date)
                ?? .placeholder,
            trendPeriod: configuration.trendPeriod
        )
    }
}
