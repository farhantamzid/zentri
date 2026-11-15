import SwiftUI
import ZentriCore

/// Settings › Appearance: the display currency, number grouping with a live preview, and Face ID.
///
/// A currency change asks for confirmation first — amounts are never converted — while a grouping
/// change applies at once, and the preview re-formats from the saved settings straight away.
struct AppearanceSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        AppearanceSettingsForm(
            model: AppearanceSettingsModel(
                settingsStore: appState.settingsStore,
                apply: appState.updateSettings
            )
        )
        .background { Theme.canvas.ignoresSafeArea() }
        .navigationTitle("Appearance")
    }
}
