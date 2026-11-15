import AppIntents

/// The windows the trend widget can show, both served by the snapshot's 30-day trend.
enum WidgetTrendPeriod: String, AppEnum {
    case sevenDays
    case thirtyDays

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Trend Period", comment: "The widget setting that picks how many days the trend shows.")
    )

    static let caseDisplayRepresentations: [WidgetTrendPeriod: DisplayRepresentation] = [
        .sevenDays: DisplayRepresentation(
            title: LocalizedStringResource("7 Days", comment: "A trend period option: the last seven days.")
        ),
        .thirtyDays: DisplayRepresentation(
            title: LocalizedStringResource("30 Days", comment: "A trend period option: the last thirty days.")
        ),
    ]

    /// The number of days the window covers.
    var dayCount: Int {
        switch self {
        case .sevenDays: 7
        case .thirtyDays: 30
        }
    }
}
