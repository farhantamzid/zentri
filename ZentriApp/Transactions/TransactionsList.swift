import SwiftUI

/// The list itself: the balance, then one section per day with a pinned day header.
struct TransactionsList: View {
    let balance: Decimal?
    let sections: [TransactionDaySection]
    let onSelect: @MainActor (TransactionListItem) -> Void

    var body: some View {
        List {
            if let balance {
                TransactionsBalanceRow(balance: balance)
            }
            ForEach(sections) { section in
                Section {
                    ForEach(section.items) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            TransactionRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    TransactionDayHeader(day: section.day)
                }
            }
        }
        .listStyle(.plain)
    }
}
