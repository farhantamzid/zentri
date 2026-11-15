import SwiftData
import SwiftUI

/// The dashboard itself: the balance hero over the data cards, or the empty state that points to
/// setup, or the failure state that offers another read.
///
/// The content owns the model, so the summary survives every re-render of the tab. It refreshes when
/// the screen appears and whenever a mutation elsewhere bumps the revision; refreshing only reads
/// the store, so it can never ask for the next refresh through that same revision.
struct OverviewContent: View {
    @State private var model: OverviewModel
    private let dataRevision: Int
    private let onFinishSetup: @MainActor () -> Void

    init(context: ModelContext, dataRevision: Int, onFinishSetup: @escaping @MainActor () -> Void) {
        _model = State(initialValue: OverviewModel(context: context))
        self.dataRevision = dataRevision
        self.onFinishSetup = onFinishSetup
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
    /// most. It has to exist: a view with no content is never asked to appear, and the read that
    /// would fill it would never run. The empty and failure states wait for that read too, so a
    /// store with an account never flashes "no account" on the way in.
    @ContentBuilder
    private var content: some View {
        switch model.loadState {
        case .loading:
            Color.clear
        case .failed:
            failureState
        case .loaded:
            if let summary = model.summary {
                cards(for: summary)
            } else {
                emptyState
            }
        }
    }

    private func cards(for summary: OverviewSummary) -> some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                BalanceHero(
                    balance: summary.balance,
                    asOf: summary.asOf,
                    todaySpend: summary.todaySpend
                )
                OverviewCards(summary: summary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    /// Shown when the store holds no active account, which is the one case the dashboard cannot
    /// draw: it offers the screen that adds one.
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No account yet", systemImage: "banknote")
        } description: {
            Text("Finish setup to add the account Zentri should watch.")
        } actions: {
            Button("Finish setup", action: onFinishSetup)
                .prominentButtonStyle()
                .controlSize(.large)
                .frame(minHeight: Theme.Layout.minimumTapTarget)
                .accessibilityIdentifier("overview.finishSetup")
        }
    }

    /// Shown when the store could not be read, which is not the same as holding no account: setup
    /// is already done, so pointing at it would send someone to add a second account. The wording
    /// says only what is known — the read did not finish — and offers another attempt.
    private var failureState: some View {
        ContentUnavailableView {
            Label("Can't show your overview", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Zentri couldn't read your data just now. Try again.")
        } actions: {
            Button("Try Again") {
                model.refresh()
            }
            .prominentButtonStyle()
            .controlSize(.large)
            .frame(minHeight: Theme.Layout.minimumTapTarget)
            .accessibilityIdentifier("overview.retry")
        }
    }
}
