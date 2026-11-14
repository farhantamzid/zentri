import Foundation
import SwiftUI

/// How bank messages reach Zentri: a Shortcut hands them over, and the app reads them on-device.
///
/// The full setup guide and the test console live in Settings (a later task); for now this screen
/// explains the idea and offers to open the Shortcuts app, and Continue skips it.
struct ShortcutsStepView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        OnboardingStepLayout(
            "Capture messages with Shortcuts",
            message: "A Shortcut can pass each bank message to Zentri, so new spending appears without you typing it in."
        ) {
            SectionCard("How it works") {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    OnboardingFeatureRow(
                        symbolName: "square.and.arrow.down",
                        title: "The message arrives",
                        detail: "Your bank's message is handed to Zentri by a Shortcut you run."
                    )
                    OnboardingFeatureRow(
                        symbolName: "text.magnifyingglass",
                        title: "Zentri reads it",
                        detail: "The amount, merchant, and date are extracted on this iPhone."
                    )

                    Button("Open Shortcuts", systemImage: "arrow.up.forward.app", action: openShortcuts)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget)
                        .accessibilityIdentifier("onboarding.shortcuts.open")
                }
            }

            Text("You can skip this and set it up later from Settings.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
        }
    }

    /// Hands over to the Shortcuts app so the user can build the automation there.
    private func openShortcuts() {
        guard let url = URL(string: "shortcuts://") else { return }
        openURL(url)
    }
}

#Preview {
    ScrollView {
        ShortcutsStepView()
    }
    .background { Theme.canvas.ignoresSafeArea() }
}
