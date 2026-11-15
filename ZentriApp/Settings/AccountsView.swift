import SwiftUI

/// Settings › Accounts.
///
/// This view only supplies what the content needs from the app's shared state; everything else lives
/// in ``AccountsContent``.
struct AccountsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        AccountsContent(
            context: appState.container.mainContext,
            service: appState.makeAccountMutationService(),
            dataRevision: appState.dataRevision,
            onMutation: appState.mutate
        )
        .background { Theme.canvas.ignoresSafeArea() }
        .navigationTitle("Accounts")
    }
}
