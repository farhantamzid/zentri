import SwiftUI

/// Opens the Shortcuts app, where the automation is built.
///
/// Onboarding and the setup guide both offer it; each passes its own identifier for UI tests.
struct OpenShortcutsButton: View {
    let accessibilityIdentifier: String

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button("Open Shortcuts", systemImage: "arrow.up.forward.app", action: openShortcuts)
            .buttonStyle(.bordered)
            .controlSize(.large)
            .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget)
            .accessibilityIdentifier(accessibilityIdentifier)
    }

    /// Hands over to the Shortcuts app so the user can build the automation there.
    private func openShortcuts() {
        guard let url = URL(string: "shortcuts://") else { return }
        openURL(url)
    }
}

#Preview {
    OpenShortcutsButton(accessibilityIdentifier: "preview.open")
        .padding()
}
