import SwiftUI

/// The Settings tab: accounts and categories, how amounts look, capture setup, backup, and About.
///
/// Every row pushes a ``SettingsDestination``; the destinations are registered here, once for the
/// tab's stack, so a screen deeper in the stack (Appearance's Face ID row, Categories' rules row)
/// pushes through the same registration.
struct SettingsView: View {
    var body: some View {
        List {
            Section {
                SettingsLink(destination: .accounts)
                SettingsLink(destination: .categories)
            } header: {
                Text("Money")
            }

            Section {
                SettingsLink(destination: .appearance)
            } header: {
                Text("Display")
            }

            Section {
                SettingsLink(destination: .parsing)
                SettingsLink(destination: .shortcuts)
            } header: {
                Text("Capture")
            }

            Section {
                SettingsLink(destination: .backup)
            } header: {
                Text("Data")
            }

            Section {
                SettingsLink(destination: .about)
            }
        }
        .scrollContentBackground(.hidden)
        .background { Theme.canvas.ignoresSafeArea() }
        .navigationTitle("Settings")
        .navigationDestination(for: SettingsDestination.self) { destination in
            SettingsDestinationView(destination: destination)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
