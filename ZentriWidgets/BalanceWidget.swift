import SwiftUI
import WidgetKit
import ZentriCore

/// The combined balance, today's spend, and when the balance was last set.
struct BalanceWidget: Widget {
    static let kind = "BalanceWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: ZentriWidgetConfigurationIntent.self,
            provider: ZentriTimelineProvider()
        ) { entry in
            BalanceWidgetView(model: entry.model)
        }
        .configurationDisplayName(Text("Balance", comment: "The balance widget's name in the widget gallery."))
        .description(Text(
            "Your combined balance and today's spending.",
            comment: "The balance widget's description in the widget gallery."
        ))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// The balance widget's content: the balance and today's spend, with the month beside them when
/// medium.
struct BalanceWidgetView: View {
    let model: WidgetDisplayModel

    @Environment(\.widgetFamily) private var family

    var body: some View {
        WidgetFrame(model: model, link: .overview) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    WidgetFigure("Balance", amount: model.balance, isHidden: model.amountsHidden)
                        .font(.title2.bold())
                        .kerning(-0.4)
                        .foregroundStyle(model.isBalanceNegative ? WidgetPalette.spending : WidgetPalette.ink)
                        .widgetAccentable()
                    if let asOf = model.balanceAsOf {
                        Text("As of \(asOf, format: .dateTime.month(.abbreviated).day())")
                            .font(.caption2)
                            .foregroundStyle(WidgetPalette.secondaryInk)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    WidgetFigure("Spent today", amount: model.todaySpend, isHidden: model.amountsHidden)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WidgetPalette.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if family == .systemMedium {
                    VStack(alignment: .leading) {
                        WidgetFigure("Spent this month", amount: model.monthSpend, isHidden: model.amountsHidden)
                            .font(.headline)
                            .foregroundStyle(WidgetPalette.ink)
                        Spacer(minLength: 0)
                        WidgetFigure("Income this month", amount: model.monthIncome, isHidden: model.amountsHidden)
                            .font(.headline)
                            .foregroundStyle(WidgetPalette.income)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

#Preview("Small", as: .systemSmall) {
    BalanceWidget()
} timeline: {
    ZentriWidgetEntry.sample()
    ZentriWidgetEntry.sample(hideAmounts: true)
    ZentriWidgetEntry.missingSnapshot
}

#Preview("Medium", as: .systemMedium) {
    BalanceWidget()
} timeline: {
    ZentriWidgetEntry.sample()
    ZentriWidgetEntry.sample(hideAmounts: true)
    ZentriWidgetEntry.missingSnapshot
}
