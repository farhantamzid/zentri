import SwiftUI
import WidgetKit
import ZentriCore

/// The balance and today's spend on the Lock Screen.
struct AccessoryBalanceWidget: Widget {
    static let kind = "AccessoryBalanceWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: ZentriWidgetConfigurationIntent.self,
            provider: ZentriTimelineProvider()
        ) { entry in
            AccessoryBalanceWidgetView(model: entry.model)
        }
        .configurationDisplayName(Text("Balance", comment: "The balance widget's name in the widget gallery."))
        .description(Text(
            "Your combined balance and today's spending on the Lock Screen.",
            comment: "The Lock Screen balance widget's description in the widget gallery."
        ))
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

/// The Lock Screen content: balance and today's spend when rectangular, the balance alone inline.
///
/// The system draws accessory widgets in a single tint, so nothing here depends on color. A missing
/// snapshot shows the "Open Zentri" hint without the redacted sample behind it, which would not fit.
struct AccessoryBalanceWidgetView: View {
    let model: WidgetDisplayModel

    @Environment(\.widgetFamily) private var family
    @Environment(\.redactionReasons) private var redactionReasons

    var body: some View {
        Group {
            if model.isPlaceholder {
                Text("Open Zentri", comment: "Shown on a widget that has no data yet; opening the app writes it.")
            } else if family == .accessoryInline {
                Text("Balance \(model.balance)", comment: "The inline Lock Screen widget. The argument is the balance or dots when hidden.")
                    .privacySensitive()
                    .accessibilityLabel(Text("Balance", comment: "The balance widget's name in the widget gallery."))
                    .accessibilityValue(Text(verbatim: WidgetStrings.spokenAmount(
                        model.balance,
                        amountsHidden: model.amountsHidden,
                        redactionReasons: redactionReasons
                    )))
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    WidgetFigure("Balance", amount: model.balance, isHidden: model.amountsHidden)
                        .font(.headline)
                        .widgetAccentable()
                    WidgetFigure("Spent today", amount: model.todaySpend, isHidden: model.amountsHidden)
                        .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
        .widgetURL(DeepLink.overview.url)
    }
}

#Preview("Rectangular", as: .accessoryRectangular) {
    AccessoryBalanceWidget()
} timeline: {
    ZentriWidgetEntry.sample()
    ZentriWidgetEntry.sample(hideAmounts: true)
    ZentriWidgetEntry.missingSnapshot
}

#Preview("Inline", as: .accessoryInline) {
    AccessoryBalanceWidget()
} timeline: {
    ZentriWidgetEntry.sample()
    ZentriWidgetEntry.sample(hideAmounts: true)
    ZentriWidgetEntry.missingSnapshot
}
