import SwiftUI

/// A Settings screen whose feature arrives in a later task, saying what it will hold.
struct SettingsPlaceholderView: View {
    let title: LocalizedStringResource
    let systemImage: String
    let message: LocalizedStringResource

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Theme.canvas.ignoresSafeArea() }
        .navigationTitle(Text(title))
    }
}

#Preview {
    NavigationStack {
        SettingsPlaceholderView(
            title: "Backup",
            systemImage: "externaldrive",
            message: "Export and import backups. Coming in a later update."
        )
    }
}
