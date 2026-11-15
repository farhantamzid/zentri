import SwiftUI
import WidgetKit
import ZentriCore

/// Daily spending bars over the last 7 or 30 days, with the period's total and the month's.
struct TrendWidget: Widget {
    static let kind = "TrendWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: ZentriWidgetConfigurationIntent.self,
            provider: ZentriTimelineProvider()
        ) { entry in
            TrendWidgetView(model: entry.model, period: entry.trendPeriod)
        }
        .configurationDisplayName(Text("Spending Trend", comment: "The trend widget's name in the widget gallery."))
        .description(Text(
            "Your daily spending over the last 7 or 30 days.",
            comment: "The trend widget's description in the widget gallery."
        ))
        .supportedFamilies([.systemMedium])
    }
}

/// The trend widget's content.
///
/// The chart is one VoiceOver element that names the period and speaks its total — or "Hidden" when
/// amounts are hidden or privacy-redacted — so it never reads out a day's amount.
struct TrendWidgetView: View {
    let model: WidgetDisplayModel
    let period: WidgetTrendPeriod

    @Environment(\.redactionReasons) private var redactionReasons

    var body: some View {
        let trend = model.trend(days: period.dayCount)
        WidgetFrame(model: model, link: .insights) {
            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline) {
                    WidgetFigure(periodTitle, amount: trend.total, isHidden: model.amountsHidden)
                        .font(.headline)
                        .foregroundStyle(WidgetPalette.ink)
                    Spacer()
                    WidgetFigure("This month", amount: model.monthSpend, isHidden: model.amountsHidden, alignment: .trailing)
                        .font(.subheadline)
                        .foregroundStyle(WidgetPalette.secondaryInk)
                }

                if trend.hasSpend {
                    TrendChart(bars: trend.bars)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(chartTitle))
                        .accessibilityValue(Text(verbatim: WidgetStrings.spokenAmount(
                            trend.total,
                            amountsHidden: model.amountsHidden,
                            redactionReasons: redactionReasons
                        )))
                } else {
                    WidgetEmptyMessage("No spending in this period")
                }
            }
        }
    }

    private var periodTitle: LocalizedStringResource {
        switch period {
        case .sevenDays: LocalizedStringResource("Last 7 days", comment: "The trend widget's heading for a seven-day trend.")
        case .thirtyDays: LocalizedStringResource("Last 30 days", comment: "The trend widget's heading for a thirty-day trend.")
        }
    }

    private var chartTitle: LocalizedStringResource {
        switch period {
        case .sevenDays: LocalizedStringResource("Spending chart, last 7 days", comment: "VoiceOver for the seven-day trend chart.")
        case .thirtyDays: LocalizedStringResource("Spending chart, last 30 days", comment: "VoiceOver for the thirty-day trend chart.")
        }
    }
}

#Preview("7 days", as: .systemMedium) {
    TrendWidget()
} timeline: {
    ZentriWidgetEntry.sample()
    ZentriWidgetEntry.sample(hideAmounts: true)
    ZentriWidgetEntry.missingSnapshot
}

#Preview("30 days", as: .systemMedium) {
    TrendWidget()
} timeline: {
    ZentriWidgetEntry.sample(trendPeriod: .thirtyDays)
}
