import SwiftUI

/// Shown when the store could not be read, which is not the same as a month without activity: the
/// wording says only that the read did not finish, and offers another attempt.
struct InsightsFailureState: View {
    let onRetry: @MainActor () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Can't show your insights", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Zentri couldn't read your data just now. Try again.")
        } actions: {
            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(minHeight: Theme.Layout.minimumTapTarget)
                .accessibilityIdentifier("insights.retry")
        }
    }
}
