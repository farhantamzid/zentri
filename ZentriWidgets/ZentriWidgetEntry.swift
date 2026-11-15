import Foundation
import WidgetKit
import ZentriCore

/// One moment of a Zentri widget: the display model for that instant and the widget's settings.
struct ZentriWidgetEntry: TimelineEntry {
    let date: Date
    /// What to draw; ``WidgetDisplayModel/placeholder`` when there is no readable snapshot.
    let model: WidgetDisplayModel
    /// How many days the trend widget shows.
    let trendPeriod: WidgetTrendPeriod

    /// A sample entry, for previews and the widget gallery.
    static func sample(hideAmounts: Bool = false, trendPeriod: WidgetTrendPeriod = .sevenDays) -> ZentriWidgetEntry {
        let snapshot = WidgetSnapshot.sample()
        let format = MoneyFormat(currencyCode: snapshot.currencyCode, grouping: snapshot.numberGrouping)
        return ZentriWidgetEntry(
            date: .now,
            model: WidgetDisplayModel(snapshot: snapshot, hideAmounts: hideAmounts, moneyFormat: format)
                ?? .placeholder,
            trendPeriod: trendPeriod
        )
    }

    /// The entry drawn when no snapshot can be read.
    static let missingSnapshot = ZentriWidgetEntry(date: .now, model: .placeholder, trendPeriod: .sevenDays)
}
