import SwiftUI
import WidgetKit

struct PlaceholderWidget: Widget {
    private static let kind = "PlaceholderWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PlaceholderTimelineProvider()) { _ in
            PlaceholderWidgetView()
        }
        .configurationDisplayName("Zentri")
        .description("Shows a Zentri widget placeholder.")
    }
}

struct PlaceholderTimelineEntry: TimelineEntry {
    let date: Date
}

struct PlaceholderTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderTimelineEntry {
        PlaceholderTimelineEntry(date: .now)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping @Sendable (PlaceholderTimelineEntry) -> Void
    ) {
        completion(PlaceholderTimelineEntry(date: .now))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping @Sendable (Timeline<PlaceholderTimelineEntry>) -> Void
    ) {
        completion(Timeline(entries: [PlaceholderTimelineEntry(date: .now)], policy: .never))
    }
}

struct PlaceholderWidgetView: View {
    var body: some View {
        Text("Zentri")
            .font(.headline)
            .containerBackground(.background, for: .widget)
    }
}
