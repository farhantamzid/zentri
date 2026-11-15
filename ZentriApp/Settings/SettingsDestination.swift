import Foundation

/// The screens the Settings tab pushes, registered once on the Settings root.
///
/// Face ID is a placeholder until its own task lands; it says what will arrive there.
enum SettingsDestination: Hashable, Sendable {
    case accounts
    case categories
    case categorizationRules
    case appearance
    case faceID
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
        case .faceID: "Face ID"
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
        case .faceID: "faceid"
        case .parsing: "text.viewfinder"
        case .shortcuts: "square.2.layers.3d"
        case .backup: "externaldrive"
        case .backupRestore: "clock.arrow.circlepath"
        case .about: "info.circle"
        }
    }

    /// What a placeholder screen says will arrive, or `nil` for a screen that is already built.
    var placeholderMessage: LocalizedStringResource? {
        switch self {
        case .faceID:
            "Require Face ID to open Zentri. Coming in a later update."
        case .accounts, .categories, .categorizationRules, .appearance, .parsing, .shortcuts, .backup, .backupRestore,
             .about:
            nil
        }
    }

    /// The identifier UI tests find the row by.
    var accessibilityIdentifier: String {
        "settings.\(self)"
    }
}
