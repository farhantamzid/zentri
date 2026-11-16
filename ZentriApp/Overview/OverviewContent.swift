import SwiftData
import SwiftUI
import ZentriCore

/// The dashboard itself: the balance hero over the data cards, or the empty state that points to
/// setup, or the failure state that offers another read.
///
/// The content owns the model, so the summary survives every re-render of the tab. It refreshes when
/// the screen appears and whenever a mutation elsewhere bumps the revision; refreshing only reads
/// the store, so it can never ask for the next refresh through that same revision.
struct OverviewContent: View {
    @State private var model: OverviewModel
    /// How far the title bar has faded in, from the scroll position: 0 at rest, 1 once the large
    /// header has scrolled away.
    @State private var barProgress: CGFloat = 0
    private let dataRevision: Int
    private let onFinishSetup: @MainActor () -> Void
    private let onSelectCategory: (@MainActor (CategoryTotal) -> Void)?
    private let onSeeAllTransactions: (@MainActor () -> Void)?

    init(
        context: ModelContext,
        dataRevision: Int,
        onFinishSetup: @escaping @MainActor () -> Void,
        onSelectCategory: (@MainActor (CategoryTotal) -> Void)? = nil,
        onSeeAllTransactions: (@MainActor () -> Void)? = nil
    ) {
        _model = State(initialValue: OverviewModel(context: context))
        self.dataRevision = dataRevision
        self.onFinishSetup = onFinishSetup
        self.onSelectCategory = onSelectCategory
        self.onSeeAllTransactions = onSeeAllTransactions
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
            VStack(spacing: 14) {
                header
                    // The inline bar is empty until the page scrolls, so the date sits up under it
                    // where the design places it.
                    .padding(.top, -36)
                    .riseIn()
                BalanceHero(
                    balance: summary.balance,
                    asOf: summary.asOf,
                    todaySpend: summary.todaySpend,
                    monthNet: summary.monthNet,
                    history: summary.balanceHistory
                )
                .riseIn(delay: 0.05)
                OverviewCards(
                    summary: summary,
                    onSelectCategory: onSelectCategory,
                    onSeeAllTransactions: onSeeAllTransactions
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            // Fades the bar in over the 30 points after the date line has scrolled under it. The
            // value is clamped, so scrolling further down the page never re-renders the screen.
            let offset = geometry.contentOffset.y + geometry.contentInsets.top
            return min(1, max(0, (offset - 30) / 30))
        } action: { _, progress in
            barProgress = progress
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Overview")
                    .font(.headline)
                    .opacity(barProgress)
                    .accessibilityHidden(barProgress < 0.5)
            }
            ToolbarItem(placement: .topBarTrailing) {
                MoneyText(summary.balance)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(Theme.accent, in: .capsule)
                    .scaleEffect(0.8 + barProgress * 0.2)
                    .opacity(barProgress)
                    .accessibilityHidden(true)
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }

    /// Today's date over the large title, as the design's header sets them.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.footnote.weight(.semibold))
                .kerning(0.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryInk)
            Text("Overview")
                .font(.largeTitle.bold())
                .kerning(-0.6)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
