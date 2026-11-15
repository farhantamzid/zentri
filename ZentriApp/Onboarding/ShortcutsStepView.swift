import Foundation
import SwiftUI

/// How bank messages reach Zentri: a Shortcut hands them over, and the app reads them on-device.
///
/// The step explains the idea, offers to open the Shortcuts app, and opens the full setup guide —
/// the same one Settings › Shortcuts shows — in a sheet. Continue skips it.
struct ShortcutsStepView: View {
    @State private var isShowingGuide = false

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

                    OpenShortcutsButton(accessibilityIdentifier: "onboarding.shortcuts.open")

                    Button("Read the Setup Guide", systemImage: "list.number", action: showGuide)
                        .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget)
                        .accessibilityIdentifier("onboarding.shortcuts.guide")
                }
            }

            Text("You can skip this and set it up later from Settings.")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryInk)
        }
        .sheet(isPresented: $isShowingGuide) {
            ShortcutsGuideSheet()
        }
    }

    private func showGuide() {
        isShowingGuide = true
    }
}

#Preview {
    ScrollView {
        ShortcutsStepView()
    }
    .background { Theme.canvas.ignoresSafeArea() }
}
