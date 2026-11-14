import SwiftUI

/// The empty content each root tab shows until its feature is built.
///
/// Tasks 11 through 14 replace these placeholders with the real Overview, Transactions, Insights,
/// and Settings screens.
struct TabPlaceholderView: View {
    private let tab: AppTab

    init(tab: AppTab) {
        self.tab = tab
    }

    var body: some View {
        ContentUnavailableView(
            "Nothing here yet",
            systemImage: tab.systemImage,
            description: Text(tab.placeholderMessage)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { Theme.canvas.ignoresSafeArea() }
        .navigationTitle(tab.title)
    }
}
