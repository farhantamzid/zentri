import SwiftUI

/// One numbered step of the Shortcuts setup guide.
///
/// The number and the instruction are one VoiceOver element, so a reader hears "1, In Shortcuts…"
/// rather than a lone digit.
struct ShortcutsSetupStepRow: View {
    let step: ShortcutsSetupStep

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.md) {
            Text(step.number, format: .number)
                .font(.subheadline.bold())
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
                .frame(minWidth: 28, minHeight: 28)
                .background(Theme.accent.opacity(0.12), in: .circle)

            Text(step.instruction)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("shortcuts.step.\(step.number)")
    }
}

#Preview {
    VStack(alignment: .leading) {
        ForEach(ShortcutsSetupStep.allCases) { step in
            ShortcutsSetupStepRow(step: step)
        }
    }
    .padding()
    .background(Theme.canvas)
}
