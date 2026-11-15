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
        case .about:
            AboutView()
        case .faceID, .parsing, .shortcuts, .backup:
            SettingsPlaceholderView(
                title: destination.title,
                systemImage: destination.systemImage,
                message: destination.placeholderMessage ?? ""
            )
        }
    }
}
