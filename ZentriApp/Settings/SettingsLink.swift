import SwiftUI

/// A row that pushes one Settings destination, titled and iconed from the destination itself.
struct SettingsLink: View {
    let destination: SettingsDestination

    var body: some View {
        NavigationLink(value: destination) {
            Label {
                Text(destination.title)
                    .foregroundStyle(Theme.ink)
            } icon: {
                Image(systemName: destination.systemImage)
                    .foregroundStyle(Theme.accent)
            }
        }
        .accessibilityIdentifier(destination.accessibilityIdentifier)
    }
}
