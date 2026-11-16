import SwiftUI

/// The Settings tab: accounts and categories, how amounts look, capture setup, backup, and About.
///
/// Every row pushes a ``SettingsDestination``; the destinations are registered here, once for the
/// tab's stack, so a screen deeper in the stack (Appearance's Face ID row, Categories' rules row)
/// pushes through the same registration. The parsing screens' ``ParsingRoute`` is registered here
/// too, so an account's detail can open that account's rules.
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            Section {
                SettingsLink(destination: .accounts)
                SettingsLink(destination: .categories)
            } header: {
                GroupHeading("Money")
            }

            Section {
                SettingsLink(destination: .appearance, value: appearanceValue)
            } header: {
                GroupHeading("Display")
            }

            Section {
                SettingsLink(destination: .parsing, value: Text(appState.parserMode.displayName))
                SettingsLink(destination: .shortcuts)
            } header: {
                GroupHeading("Capture")
            }

            Section {
                SettingsLink(destination: .backup)
            } header: {
                GroupHeading("Data")
            }

            Section {
                SettingsLink(destination: .about)
            }
        }
        .listSectionSpacing(Theme.Spacing.lg)
        .scrollContentBackground(.hidden)
        .ambientBackground()
        .navigationTitle("Settings")
        .navigationDestination(for: SettingsDestination.self) { destination in
            SettingsDestinationView(destination: destination)
                .scrollContentBackground(.hidden)
                .ambientBackground()
        }
        .navigationDestination(for: ParsingRoute.self) { route in
            ParsingRouteDestination(route: route)
                .scrollContentBackground(.hidden)
                .ambientBackground()
        }
    }
}

extension SettingsView {
    /// The appearance mode the Appearance row shows beside its title.
    private var appearanceValue: Text? {
        appState.settingsStore.settings.map { Text($0.appearanceMode.title) }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
