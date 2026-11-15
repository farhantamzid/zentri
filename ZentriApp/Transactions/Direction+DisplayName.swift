import Foundation
import ZentriCore

extension Direction {
    /// How the list and editor name the direction.
    var displayName: LocalizedStringResource {
        switch self {
        case .debit: "Spent"
        case .credit: "Received"
        }
    }
}
