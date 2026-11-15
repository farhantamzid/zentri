import SwiftUI
import ZentriCore

/// Narrows the list by account, category, direction, source, and dates.
///
/// The sheet edits a copy and hands it back on Apply, so cancelling leaves the list as it was. The
/// search text travels through untouched.
struct TransactionFilterSheet: View {
    private let accounts: [TransactionAccountOption]
    private let categories: [TransactionCategoryOption]
    private let onApply: @MainActor (TransactionFilter) -> Void

    @State private var draft: TransactionFilter
    @State private var limitsDates: Bool
    @State private var startDate: Date
    @State private var endDate: Date

    @Environment(\.dismiss) private var dismiss

    init(
        filter: TransactionFilter,
        accounts: [TransactionAccountOption],
        categories: [TransactionCategoryOption],
        onApply: @escaping @MainActor (TransactionFilter) -> Void
    ) {
        self.accounts = accounts
        self.categories = categories
        self.onApply = onApply
        _draft = State(initialValue: filter)
        _limitsDates = State(initialValue: filter.dateRange != nil)
        let today = Date.now
        _startDate = State(initialValue: filter.dateRange?.lowerBound ?? today.addingTimeInterval(-30 * 86_400))
        _endDate = State(initialValue: filter.dateRange?.upperBound ?? today)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Account", selection: $draft.accountID) {
                        Text("All accounts").tag(UUID?.none)
                        ForEach(accounts) { account in
                            Text(account.name).tag(Optional(account.id))
                        }
                    }
                    Picker("Category", selection: $draft.categoryID) {
                        Text("All categories").tag(UUID?.none)
                        ForEach(categories) { category in
                            Label(category.name, systemImage: category.symbolName).tag(Optional(category.id))
                        }
                    }
                    Picker("Direction", selection: $draft.direction) {
                        Text("Both").tag(Direction?.none)
                        ForEach(Direction.allCases, id: \.self) { direction in
                            Text(direction.displayName).tag(Optional(direction))
                        }
                    }
                    Picker("Source", selection: $draft.engine) {
                        Text("All sources").tag(ParseEngine?.none)
                        ForEach(ParseEngine.allCases, id: \.self) { engine in
                            Text(engine.displayName).tag(Optional(engine))
                        }
                    }
                }

                Section {
                    Toggle("Limit to dates", isOn: $limitsDates)
                    if limitsDates {
                        DatePicker("From", selection: $startDate, in: ...endDate, displayedComponents: .date)
                        DatePicker("To", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }

                Section {
                    Button("Reset Filters", role: .destructive, action: reset)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply", action: apply)
                }
            }
        }
    }

    private func reset() {
        draft = draft.clearingFilters
        limitsDates = false
    }

    private func cancel() {
        dismiss()
    }

    private func apply() {
        var filter = draft
        filter.dateRange = limitsDates ? startDate...max(startDate, endDate) : nil
        onApply(filter)
        dismiss()
    }
}
