import Foundation

/// The app's four root tabs.
///
/// The identifiers are stable strings so a deep link or widget can select a tab without knowing
/// the view hierarchy. Titles travel through the string catalog.
enum AppTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case overview
    case transactions
    case insights
    case settings

    var id: Self { self }

    /// The tab's title, localized through the string catalog.
    var title: LocalizedStringResource {
        switch self {
        case .overview: "Overview"
        case .transactions: "Transactions"
        case .insights: "Insights"
        case .settings: "Settings"
        }
    }

    /// The SF Symbol shown in the tab bar.
    var systemImage: String {
        switch self {
        case .overview: "rectangle.grid.2x2"
        case .transactions: "list.bullet.rectangle"
        case .insights: "chart.bar.xaxis"
        case .settings: "gearshape"
        }
    }
}
