import Foundation
import ZentriCore

extension OverviewTransaction {
    /// The recent-activity row as VoiceOver reads it: merchant, category, the transfer tag the row
    /// shows, and the movement in words.
    ///
    /// The direction is spelled out rather than left to the amount's sign, which is how a listener
    /// hears which way the money went without seeing the row's color.
    func spokenSummary(moneyFormat: MoneyFormat) -> String {
        let money = moneyFormat.currencyString(from: amount)
        let movement = switch direction {
        case .credit: String(localized: "received \(money)")
        case .debit: String(localized: "spent \(money)")
        }
        let parts = [merchant, categoryName] + (isTransfer ? [String(localized: "transfer")] : []) + [movement]
        // Comma-separated phrases, the pause pattern VoiceOver reads every row in the app with.
        return parts.joined(separator: ", ")
    }
}
