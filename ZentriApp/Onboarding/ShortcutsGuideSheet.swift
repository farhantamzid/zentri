import SwiftUI

/// The full Shortcuts setup guide, presented from onboarding in its own stack.
///
/// Onboarding's stack hides its navigation bar and registers no parsing screens, so the sheet brings
/// its own: a Done button and the ``ParsingRoute`` destinations the test console and inbox links push.
struct ShortcutsGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ShortcutsSetupView()
                .navigationDestination(for: ParsingRoute.self) { route in
                    ParsingRouteDestination(route: route)
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: close)
                            .accessibilityIdentifier("shortcuts.guide.done")
                    }
                }
        }
    }

    private func close() {
        dismiss()
    }
}
