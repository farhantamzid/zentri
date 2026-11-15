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
        case .about:
            AboutView()
        case .faceID, .shortcuts, .backup:
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
