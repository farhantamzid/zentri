import SwiftUI
import WidgetKit
import ZentriCore

/// The newest transactions: three when medium, six when large.
struct RecentTransactionsWidget: Widget {
    static let kind = "RecentTransactionsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: ZentriWidgetConfigurationIntent.self,
            provider: ZentriTimelineProvider()
        ) { entry in
            RecentTransactionsWidgetView(model: entry.model)
        }
        .configurationDisplayName(Text(
            "Recent Transactions",
            comment: "The recent transactions widget's name in the widget gallery."
        ))
        .description(Text(
            "Your newest transactions across your accounts.",
            comment: "The recent transactions widget's description in the widget gallery."
        ))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

/// The recent transactions widget's content.
struct RecentTransactionsWidgetView: View {
    let model: WidgetDisplayModel

    @Environment(\.widgetFamily) private var family

    var body: some View {
        WidgetFrame(model: model, link: .transactions) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent", comment: "The recent transactions widget's heading.")
                    .font(.caption)
                    .foregroundStyle(WidgetPalette.secondaryInk)
                    .accessibilityAddTraits(.isHeader)

                if model.recentRows.isEmpty {
                    WidgetEmptyMessage("No transactions yet")
                } else {
                    ForEach(model.recentRows.prefix(rowLimit)) { row in
                        RecentTransactionWidgetRow(
                            row: row,
                            amountsHidden: model.amountsHidden,
                            showsCategory: family == .systemLarge
                        )
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// Three rows fit a medium widget; a large one shows all six the snapshot carries.
    private var rowLimit: Int {
        family == .systemLarge ? WidgetSnapshotBuilder.recentTransactionLimit : 3
    }
}

#Preview("Medium", as: .systemMedium) {
    RecentTransactionsWidget()
} timeline: {
    ZentriWidgetEntry.sample()
    ZentriWidgetEntry.sample(hideAmounts: true)
    ZentriWidgetEntry.missingSnapshot
}

#Preview("Large", as: .systemLarge) {
    RecentTransactionsWidget()
} timeline: {
    ZentriWidgetEntry.sample()
    ZentriWidgetEntry.sample(hideAmounts: true)
    ZentriWidgetEntry.missingSnapshot
}
