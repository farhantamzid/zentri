import SwiftUI

/// Settings › Categories › Keyword Rules.
///
/// This view only supplies what the content needs from the app's shared state; everything else lives
/// in ``CategorizationRulesContent``.
struct CategorizationRulesView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        CategorizationRulesContent(
            context: appState.container.mainContext,
            service: appState.makeCategoryMutationService(),
            dataRevision: appState.dataRevision,
            onMutation: appState.mutate
        )
        .background { Theme.canvas.ignoresSafeArea() }
        .navigationTitle("Keyword Rules")
    }
}
