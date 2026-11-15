import SwiftUI

/// Shown when transactions exist but none match the search or the filters.
struct TransactionsNoMatchesState: View {
    let searchText: String
    let hasActiveFilters: Bool
    let onClearFilters: @MainActor () -> Void

    var body: some View {
        if hasActiveFilters {
            ContentUnavailableView {
                Label("No matching transactions", systemImage: "line.3.horizontal.decrease.circle")
            } description: {
                Text("No transactions match the current filters.")
            } actions: {
                Button("Clear Filters", action: onClearFilters)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(minHeight: Theme.Layout.minimumTapTarget)
            }
        } else {
            ContentUnavailableView.search(text: searchText)
        }
    }
}
