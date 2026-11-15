import ZentriCore

extension AppTab {
    /// The tab a widget's deep link opens.
    init(deepLink: DeepLink) {
        self = switch deepLink {
        case .overview: .overview
        case .transactions: .transactions
        case .insights: .insights
        }
    }
}
