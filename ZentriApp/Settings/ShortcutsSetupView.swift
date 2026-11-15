import SwiftUI

/// Settings › Shortcuts, and the guide onboarding opens: how to build the capture automation.
///
/// This view only supplies what the content needs from the app's shared state. The hosting stack
/// registers ``ParsingRoute`` so the test-console and inbox links can push.
struct ShortcutsSetupView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ShortcutsSetupContent(
            model: ShortcutsSetupModel(context: appState.container.mainContext),
            dataRevision: appState.dataRevision
        )
        .background { Theme.canvas.ignoresSafeArea() }
        .navigationTitle(Text(SettingsDestination.shortcuts.title))
    }
}
