import SwiftUI
import ZentriCore

/// The list itself: the filter chips and the balance, then one glass group per day.
///
/// Each row swipes left for its category and for delete. The list is a native `List`, so rows are
/// recycled as they scroll and swipe actions track the finger at the display's full refresh rate.
/// When nothing matches, the chips stay so the filter can be changed in place.
struct TransactionsList: View {
    let balance: Decimal?
    let sections: [TransactionDaySection]
    let filter: TransactionFilter
    let chipCategories: [TransactionCategoryOption]
    let onSelect: @MainActor (TransactionListItem) -> Void
    let onDelete: @MainActor (TransactionListItem) -> Void
    let onFilterChange: @MainActor (TransactionFilter) -> Void
    let onClearFilters: @MainActor () -> Void
    let transition: Namespace.ID

    var body: some View {
        List {
            Section {
                TransactionFilterChips(filter: filter, categories: chipCategories, onChange: onFilterChange)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .padding(.horizontal, -Theme.Spacing.lg)
                if let balance {
                    TransactionsBalanceRow(balance: balance)
                        .padding(.horizontal, Theme.Spacing.xs)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if sections.isEmpty {
                TransactionsNoMatchesState(
                    searchText: filter.searchText,
                    hasActiveFilters: filter.hasActiveFilters,
                    onClearFilters: onClearFilters
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            ForEach(sections) { section in
                Section {
                    ForEach(section.items) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            TransactionRow(item: item)
                        }
                        .matchedTransitionSource(id: item.id, in: transition)
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.glass)
                        .listRowSeparatorTint(Theme.hairline)
                        .listRowInsets(EdgeInsets(top: 11, leading: 14, bottom: 11, trailing: 14))
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 52 }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                onDelete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(Theme.spending)
                            Button {
                                onSelect(item)
                            } label: {
                                Label("Category", systemImage: "tag")
                            }
                            .tint(Theme.accent)
                        }
                    }
                } header: {
                    TransactionDayHeader(day: section.day, items: section.items)
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(Theme.Spacing.md)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, Theme.Spacing.lg, for: .scrollContent)
        .animation(Theme.Motion.snap, value: sections)
    }
}
