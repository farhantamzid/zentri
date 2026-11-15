import Foundation
import ZentriCore

extension CategorySource {
    /// How the detail explains where the category came from.
    var displayName: LocalizedStringResource {
        switch self {
        case .rule: "Keyword rule"
        case .ai: "Apple Intelligence"
        case .manual: "You chose it"
        case .default: "Default"
        }
    }
}
