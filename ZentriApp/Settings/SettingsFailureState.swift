import SwiftUI

/// Shown when a Settings screen could not read the store, which is not the same as having nothing
/// stored.
struct SettingsFailureState: View {
    let title: LocalizedStringResource
    let onRetry: @MainActor () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            Text("Zentri couldn't read your data just now. Try again.")
        } actions: {
            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(minHeight: Theme.Layout.minimumTapTarget)
                .accessibilityIdentifier("settings.retry")
        }
    }
}

#Preview {
    SettingsFailureState(title: "Can't show your accounts", onRetry: {})
}
