import Foundation

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

    /// The identifier UI tests find the row by.
    var accessibilityIdentifier: String {
        "settings.\(self)"
    }
}
