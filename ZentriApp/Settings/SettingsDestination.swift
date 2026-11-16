import SwiftUI

/// The screens the Settings tab pushes, registered once on the Settings root.
enum SettingsDestination: Hashable, Sendable {
    case accounts
    case categories
    case categorizationRules
    case appearance
    case parsing
    case shortcuts
    case backup
    case backupRestore
    case about

    /// The row and navigation title.
    var title: LocalizedStringResource {
        switch self {
        case .accounts: "Accounts"
        case .categories: "Categories"
        case .categorizationRules: "Keyword Rules"
        case .appearance: "Appearance"
        case .parsing: "Parsing"
        case .shortcuts: "Shortcuts"
        case .backup: "Backup"
        case .backupRestore: "Restore from Folder"
        case .about: "About"
        }
    }

    /// The SF Symbol beside the row.
    var systemImage: String {
        switch self {
        case .accounts: "building.columns"
        case .categories: "square.grid.2x2"
        case .categorizationRules: "text.magnifyingglass"
        case .appearance: "textformat.123"
        case .parsing: "text.viewfinder"
        case .shortcuts: "square.2.layers.3d"
        case .backup: "externaldrive"
        case .backupRestore: "clock.arrow.circlepath"
        case .about: "info.circle"
        }
    }

    /// The filled symbol on the row's colored square.
    var rowSymbol: String {
        switch self {
        case .accounts: "building.columns"
        case .categories: "square.grid.2x2"
        case .categorizationRules: "text.magnifyingglass"
        case .appearance: "paintpalette"
        case .parsing: "message"
        case .shortcuts: "bolt"
        case .backup: "icloud.and.arrow.up"
        case .backupRestore: "clock.arrow.circlepath"
        case .about: "info.circle"
        }
    }

    /// The color of the row's square, as the design's Settings list sets them.
    var rowColor: Color {
        switch self {
        case .accounts: Color(light: 0x0E5F5A, dark: 0x147A73)
        case .categories: Color(light: 0x6A4AB8, dark: 0x7B5CCB)
        case .categorizationRules: Color(light: 0x6A4AB8, dark: 0x7B5CCB)
        case .appearance: Color(light: 0xC07A12, dark: 0xC98A2A)
        case .parsing: Color(light: 0x0A6E86, dark: 0x1583A0)
        case .shortcuts: Color(light: 0x3F4FA8, dark: 0x5363BD)
        case .backup, .backupRestore: Color(light: 0x1B7A4B, dark: 0x22915A)
        case .about: Color(light: 0x5A6472, dark: 0x6B7584)
        }
    }

    /// The identifier UI tests find the row by.
    var accessibilityIdentifier: String {
        "settings.\(self)"
    }
}
