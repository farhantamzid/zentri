import Foundation
import ZentriCore

extension ParseEngine {
    /// How the detail and filters name the source of a transaction.
    var displayName: LocalizedStringResource {
        switch self {
        case .rules: "Bank rule"
        case .foundationModels: "Apple Intelligence"
        case .manual: "Manual"
        }
    }
}
