import SwiftUI

/// Settings › Categories.
///
/// This view only supplies what the content needs from the app's shared state; everything else lives
/// in ``CategoriesContent``.
struct CategoriesView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        CategoriesContent(
            context: appState.container.mainContext,
            service: appState.makeCategoryMutationService(),
            dataRevision: appState.dataRevision,
            onMutation: appState.mutate
        )
        .background { Theme.canvas.ignoresSafeArea() }
        .navigationTitle("Categories")
    }
}
