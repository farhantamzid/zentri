import SwiftUI

/// The Transactions tab.
///
/// This view only supplies the store's context, which the content needs to create its model once;
/// everything else lives in ``TransactionsContent``.
struct TransactionsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TransactionsContent(context: appState.container.mainContext)
            .ambientBackground()
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.large)
    }
}
