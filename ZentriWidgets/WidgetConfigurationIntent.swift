import AppIntents
import WidgetKit

/// The settings a person edits on any Zentri widget: privacy and, for the trend, its window.
///
/// Every widget shares this intent, so the trend period also appears on widgets that do not draw a
/// trend; it simply has no effect there.
struct ZentriWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title = LocalizedStringResource(
        "Zentri Widget",
        comment: "The title of the widget configuration screen."
    )
    static let description = IntentDescription(
        LocalizedStringResource(
            "Choose whether amounts are hidden and how many days the trend shows.",
            comment: "The description on the widget configuration screen."
        )
    )

    /// Whether every amount shows as dots, for a widget on a shared screen.
    @Parameter(
        title: LocalizedStringResource("Hide Amounts", comment: "The widget setting that replaces amounts with dots."),
        default: false
    )
    var hideAmounts: Bool

    /// How many days the trend widget shows.
    @Parameter(
        title: LocalizedStringResource("Trend Period", comment: "The widget setting that picks how many days the trend shows."),
        default: .sevenDays
    )
    var trendPeriod: WidgetTrendPeriod
}
