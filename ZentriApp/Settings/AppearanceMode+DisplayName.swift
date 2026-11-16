import SwiftUI
import ZentriCore

extension AppearanceMode {
    /// The mode's name in the Appearance picker.
    var title: LocalizedStringResource {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// The color scheme the app's windows are forced to, or nil to follow the device.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
