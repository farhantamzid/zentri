import SwiftUI

/// The minimal first-run screen the shell shows until onboarding is built.
///
/// Task 10 replaces this with the real welcome, currency, account, parser, Shortcuts, and Face ID
/// flow. It deliberately has no actions: no setup can be completed before onboarding exists.
struct OnboardingPlaceholderView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Welcome to Zentri", systemImage: "leaf")
        } description: {
            Text("Setup is coming next. Everything stays on this device.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Theme.canvas.ignoresSafeArea() }
    }
}
