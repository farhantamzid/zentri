import SwiftUI

/// Shown when Rules is the chosen engine: where rules live, and how to reach them.
///
/// Rules are written in Settings, not here, so this screen explains the one thing left to do and
/// continues the flow with an explicit button. It is a step of its own, so Back returns to the
/// engine choice and Continue carries on to Shortcuts.
struct RulesStepView: View {
    private let onContinue: () -> Void

    init(onContinue: @escaping () -> Void) {
        self.onContinue = onContinue
    }

    var body: some View {
        OnboardingStepLayout(
            "Rules read messages your way",
            message: "A rule is a pattern you write once. It matches a message and tells Zentri the amount, the merchant, and the direction."
        ) {
            SectionCard("Where rules live") {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    OnboardingFeatureRow(
                        symbolName: "slider.horizontal.3",
                        title: "Settings → Parsing",
                        detail: "Add, edit, reorder, and test rules there."
                    )
                    OnboardingFeatureRow(
                        symbolName: "checkmark.seal",
                        title: "Nothing to do now",
                        detail: "New messages wait in the inbox until a rule or the on-device model can read them."
                    )
                }
            }

            Button("Add your first rule in Settings → Parsing", action: onContinue)
                .prominentButtonStyle()
                .controlSize(.large)
                .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget)
                .accessibilityIdentifier("onboarding.rules.continue")
        }
    }
}

#Preview {
    ScrollView {
        RulesStepView(onContinue: {})
    }
    .background { Theme.canvas.ignoresSafeArea() }
}
