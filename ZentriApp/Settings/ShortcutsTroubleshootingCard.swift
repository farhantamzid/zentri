import SwiftUI

/// What to check when messages do not arrive, or only arrive after a tap.
struct ShortcutsTroubleshootingCard: View {
    var body: some View {
        SectionCard("Troubleshooting") {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                OnboardingFeatureRow(
                    symbolName: "bolt",
                    title: "Transactions wait for a tap",
                    detail: "Open the automation and choose Run Immediately. With Run After Confirmation, iOS waits for you before the message reaches Zentri."
                )
                .accessibilityIdentifier("shortcuts.troubleshooting.runImmediately")

                OnboardingFeatureRow(
                    symbolName: "person.crop.circle.badge.questionmark",
                    title: "Nothing arrives",
                    detail: "Check that the automation's sender matches how your bank's messages appear in Messages. Banks often send from a short code or a name, not a saved contact. If you're unsure, use Message Contains with a word every bank message includes."
                )
                .accessibilityIdentifier("shortcuts.troubleshooting.sender")

                OnboardingFeatureRow(
                    symbolName: "building.columns",
                    title: "More than one account",
                    detail: "Choose the account in the Capture Bank SMS action, so each message lands in the right one. A message Zentri can't place waits in the message inbox."
                )
                .accessibilityIdentifier("shortcuts.troubleshooting.account")
            }
        }
    }
}

#Preview {
    ScrollView {
        ShortcutsTroubleshootingCard()
            .padding()
    }
    .background(Theme.canvas)
}
