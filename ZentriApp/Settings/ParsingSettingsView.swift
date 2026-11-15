import SwiftUI

/// Settings › Parsing.
///
/// This view only supplies what the content needs from the app's shared state; everything else lives
/// in ``ParsingSettingsContent``.
struct ParsingSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ParsingSettingsContent(
            model: ParsingSettingsModel(
                context: appState.container.mainContext,
                settingsStore: appState.settingsStore,
                modelClient: appState.modelClient,
                apply: appState.updateSettings
            ),
            dataRevision: appState.dataRevision
        )
        .background { Theme.canvas.ignoresSafeArea() }
        .navigationTitle("Parsing")
    }
}
