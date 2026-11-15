import Foundation
import ZentriCore

extension NumberGrouping {
    /// The grouping's name, shared by onboarding and Settings.
    var title: LocalizedStringResource {
        switch self {
        case .system: "System"
        case .western: "Western"
        case .indian: "Indian"
        }
    }

    /// One line on how the grouping arranges digits.
    var detail: LocalizedStringResource {
        switch self {
        case .system: "Follows this device"
        case .western: "Groups of three digits"
        case .indian: "Three digits, then groups of two"
        }
    }
}
