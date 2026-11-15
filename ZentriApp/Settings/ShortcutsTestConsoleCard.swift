import SwiftUI

/// Points at the rule tester, where a pasted message runs through the parser without being saved.
///
/// The link pushes ``ParsingRoute/tester``, which the hosting stack registers.
struct ShortcutsTestConsoleCard: View {
    var body: some View {
        SectionCard("Try a message first") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Paste one of your bank's messages into the test console to see what Zentri reads from it. Nothing is saved.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)

                NavigationLink(value: ParsingRoute.tester) {
                    HStack {
                        Label("Open Test Console", systemImage: "testtube.2")
                            .foregroundStyle(Theme.accent)
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .foregroundStyle(Theme.secondaryInk)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: Theme.Layout.minimumTapTarget)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("shortcuts.tester")
            }
        }
    }
}

#Preview {
    NavigationStack {
        ShortcutsTestConsoleCard()
            .padding()
    }
}
