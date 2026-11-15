import SwiftUI
import WidgetKit
import ZentriCore

/// This month's top categories as a stacked share bar with their names and shares.
struct CategoriesWidget: Widget {
    static let kind = "CategoriesWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: ZentriWidgetConfigurationIntent.self,
            provider: ZentriTimelineProvider()
        ) { entry in
            CategoriesWidgetView(model: entry.model)
        }
        .configurationDisplayName(Text("Top Categories", comment: "The categories widget's name in the widget gallery."))
        .description(Text(
            "Where your money went this month.",
            comment: "The categories widget's description in the widget gallery."
        ))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

/// The categories widget's content: the month's spend, the share bar, and up to four categories —
/// in two columns when medium, and in a list with their amounts when large.
struct CategoriesWidgetView: View {
    let model: WidgetDisplayModel

    @Environment(\.widgetFamily) private var family

    var body: some View {
        WidgetFrame(model: model, link: .insights) {
            VStack(alignment: .leading, spacing: 6) {
                WidgetFigure("Spent this month", amount: model.monthSpend, isHidden: model.amountsHidden)
                    .font(.headline)
                    .foregroundStyle(WidgetPalette.ink)

                if model.categoryRows.isEmpty {
                    WidgetEmptyMessage("No spending this month")
                } else {
                    CategoryShareBar(rows: model.categoryRows)
                    if family == .systemLarge {
                        ForEach(model.categoryRows) { row in
                            CategoryWidgetRow(row: row, amountsHidden: model.amountsHidden, showsAmount: true)
                        }
                    } else {
                        // Two columns keep four categories within a medium widget's height.
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                            ForEach(Array(stride(from: 0, to: model.categoryRows.count, by: 2)), id: \.self) { index in
                                GridRow {
                                    CategoryWidgetRow(
                                        row: model.categoryRows[index],
                                        amountsHidden: model.amountsHidden,
                                        showsAmount: false
                                    )
                                    if index + 1 < model.categoryRows.count {
                                        CategoryWidgetRow(
                                            row: model.categoryRows[index + 1],
                                            amountsHidden: model.amountsHidden,
                                            showsAmount: false
                                        )
                                    }
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

#Preview("Medium", as: .systemMedium) {
    CategoriesWidget()
} timeline: {
    ZentriWidgetEntry.sample()
    ZentriWidgetEntry.sample(hideAmounts: true)
    ZentriWidgetEntry.missingSnapshot
}

#Preview("Large", as: .systemLarge) {
    CategoriesWidget()
} timeline: {
    ZentriWidgetEntry.sample()
    ZentriWidgetEntry.sample(hideAmounts: true)
    ZentriWidgetEntry.missingSnapshot
}
