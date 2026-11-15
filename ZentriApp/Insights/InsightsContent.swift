import SwiftData
import SwiftUI
import ZentriCore

/// The Insights screen itself: the month selector over the month's cards, the month's empty state,
/// or the failure state that offers another read.
///
/// The content owns the model, so the selected month survives every re-render of the tab. It
/// refreshes when the screen appears and whenever a mutation elsewhere bumps the revision; the
/// model reads the month again itself whenever the selection changes.
struct InsightsContent: View {
    @Environment(\.locale) private var locale
    @State private var model: InsightsModel
    private let dataRevision: Int
    private let onShowTransactions: @MainActor (TransactionFilter) -> Void

    init(
        context: ModelContext,
        dataRevision: Int,
        onShowTransactions: @escaping @MainActor (TransactionFilter) -> Void
    ) {
        _model = State(initialValue: InsightsModel(context: context))
        self.dataRevision = dataRevision
        self.onShowTransactions = onShowTransactions
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { model.refresh() }
            .onChange(of: dataRevision) {
                model.refresh()
            }
    }

    /// The store is read on the first appearance, so the blank branch is on screen for one frame at
    /// most; it has to exist so the view appears and that read runs.
    @ContentBuilder
    private var content: some View {
        switch model.loadState {
        case .loading:
            Color.clear
        case .failed:
            InsightsFailureState(onRetry: model.refresh)
        case .loaded:
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    InsightsMonthSelector(
                        month: model.selectedMonth,
                        isShowingThisMonth: model.isShowingThisMonth,
                        onPrevious: model.previousMonth,
                        onNext: model.nextMonth,
                        onThisMonth: model.thisMonth
                    )
                    if let summary = model.summary, model.hasActivity {
                        InsightsCards(
                            summary: summary,
                            observations: model.observations,
                            largestSpends: model.largestSpends,
                            onSelectCategory: showTransactions(for:),
                            onSelectMerchant: showTransactions(forMerchant:)
                        )
                    } else {
                        ContentUnavailableView(
                            "No activity",
                            systemImage: "chart.bar.xaxis",
                            description: Text("Nothing was spent or received in \(monthName).")
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var monthName: String {
        model.selectedMonth.formatted(.dateTime.month(.wide).year().locale(locale))
    }

    private func showTransactions(for category: CategoryTotal) {
        guard let filter = model.transactionFilter(for: category) else { return }
        onShowTransactions(filter)
    }

    private func showTransactions(forMerchant merchant: String) {
        onShowTransactions(model.transactionFilter(forMerchant: merchant))
    }
}
