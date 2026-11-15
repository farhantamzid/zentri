import SwiftUI

/// The screen for one Settings destination.
struct SettingsDestinationView: View {
    let destination: SettingsDestination

    var body: some View {
        switch destination {
        case .accounts:
            AccountsView()
        case .categories:
            CategoriesView()
        case .categorizationRules:
            CategorizationRulesView()
        case .appearance:
            AppearanceSettingsView()
        case .parsing:
            ParsingSettingsView()
        case .shortcuts:
            ShortcutsSetupView()
        case .backup:
            BackupSettingsView()
        case .backupRestore:
            BackupRestoreView()
        case .about:
            AboutView()
        case .faceID:
            if let message = destination.placeholderMessage {
                SettingsPlaceholderView(
                    title: destination.title,
                    systemImage: destination.systemImage,
                    message: message
                )
            }
        }
    }
}
