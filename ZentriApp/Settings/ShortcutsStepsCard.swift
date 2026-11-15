import SwiftUI

/// The five numbered steps for building the automation, and the button that opens Shortcuts.
struct ShortcutsStepsCard: View {
    var body: some View {
        SectionCard("Set up the automation") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(ShortcutsSetupStep.allCases) { step in
                    ShortcutsSetupStepRow(step: step)
                }

                OpenShortcutsButton(accessibilityIdentifier: "shortcuts.open")
            }
        }
    }
}

#Preview {
    ScrollView {
        ShortcutsStepsCard()
            .padding()
    }
    .background(Theme.canvas)
}
