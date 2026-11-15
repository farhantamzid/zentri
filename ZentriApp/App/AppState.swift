import Foundation
import Observation
import SwiftData
import ZentriCore

/// The app's shared state: the store, the live settings, the parser, the widget snapshot, and the
/// navigation the tabs share.
///
/// Screens read one `AppState`; a mutation calls `mutate()` so every open tab reloads, and the
/// launch retry asks ingestion to finish anything an interruption left pending.
@MainActor
@Observable
final class AppState {
    /// The SwiftData container every screen reads and writes.
    let container: ModelContainer
    /// The live settings, shared with onboarding, settings, and every money label.
    let settingsStore: SettingsStore
    /// The parser builder ingestion and the rule tester use.
    let parserBuilder: any ParserBuilding
    /// The refresher that keeps widgets in step with the store.
    let snapshotRefresher: any WidgetSnapshotRefresher
    /// Where the widget snapshot is written; "Delete All Data" removes it.
    private let snapshotStore: any WidgetSnapshotStore

    /// The selected root tab.
    var selectedTab: AppTab = .overview
    /// A filter the Insights tab can hand to Transactions.
    var transactionFilter = TransactionFilter()
    /// A counter screens watch to reload after a mutation elsewhere.
    private(set) var dataRevision = 0

    /// Whether the launch retry has already run, so it runs at most once per session.
    @ObservationIgnored private var hasRetriedPendingIngestion = false

    init(
        container: ModelContainer,
        settingsStore: SettingsStore,
        parserBuilder: any ParserBuilding,
        snapshotStore: any WidgetSnapshotStore
    ) {
        self.container = container
        self.settingsStore = settingsStore
        self.parserBuilder = parserBuilder
        self.snapshotStore = snapshotStore
        self.snapshotRefresher = LiveWidgetSnapshotRefresher(
            context: container.mainContext,
            store: snapshotStore,
            settings: { [weak settingsStore] in settingsStore?.settings ?? .defaultValue },
            now: { .now },
            calendar: .current
        )
    }

    /// The money formatting for the current settings and the caller's locale.
    ///
    /// The locale comes from the view environment so previews and per-view overrides work, while
    /// the currency and grouping always follow the saved setting.
    func moneyFormat(locale: Locale) -> MoneyFormat {
        let settings = settingsStore.settings ?? .defaultValue
        return MoneyFormat(
            currencyCode: settings.currencyCode,
            grouping: settings.numberGrouping,
            locale: locale
        )
    }

    /// A service for the person's own changes to transactions, writing to the main context and
    /// refreshing the widgets after each one. The caller still calls ``mutate()`` afterwards.
    func makeTransactionMutationService() -> TransactionMutationService {
        TransactionMutationService(context: container.mainContext, snapshotRefresher: snapshotRefresher)
    }

    /// A service for the person's changes to accounts, refreshing the widgets after each one. The
    /// caller still calls ``mutate()`` afterwards.
    func makeAccountMutationService() -> AccountMutationService {
        AccountMutationService(context: container.mainContext, snapshotRefresher: snapshotRefresher)
    }

    /// A service for the person's changes to categories and keyword rules. The caller still calls
    /// ``mutate()`` afterwards.
    func makeCategoryMutationService() -> CategoryMutationService {
        CategoryMutationService(context: container.mainContext, snapshotRefresher: snapshotRefresher)
    }

    /// Saves new settings, then rewrites the widget snapshot, which carries the currency and grouping.
    ///
    /// Every money label re-renders on its own: the root reads ``moneyFormat(locale:)`` from the
    /// observed settings. Changing the currency never converts a stored amount.
    func updateSettings(_ settings: AppSettings) async throws {
        try settingsStore.save(settings)
        await snapshotRefresher.refresh()
    }

    /// Deletes everything Zentri keeps on this device and returns the app to setup.
    ///
    /// The store goes first, in one save: if that fails nothing has changed. Then the widget
    /// snapshot is removed, so no widget keeps showing a balance from deleted data, and last the
    /// settings document, which is what sends the root back to onboarding. A failure after the
    /// store is empty leaves a state the person can finish by deleting again. In `-UITestMode` the
    /// store is in memory, the snapshot store is inert, and the settings repository is in memory, so
    /// nothing real is touched.
    func eraseAllData() throws {
        try StoreEraser().eraseAll(in: container.mainContext)
        try snapshotStore.remove()
        try settingsStore.reset()
        transactionFilter = TransactionFilter()
        selectedTab = .overview
        mutate()
    }

    /// Tells every open screen that the store changed.
    ///
    /// Mutations call this after saving. It deliberately does not refresh the widget snapshot (the
    /// mutation service does that) and never retries ingestion, so a reload cannot loop.
    func mutate() {
        dataRevision += 1
    }

    /// Retries messages that an interruption left `processing`.
    ///
    /// While onboarding is showing there are no settings and nothing to retry, so this is a no-op.
    /// The service is built per retry with a live settings provider, so a parser-mode change
    /// applies to the next attempt instead of freezing today's settings into the service.
    func retryPendingIngestion() async {
        guard settingsStore.settings != nil, !hasRetriedPendingIngestion else { return }
        hasRetriedPendingIngestion = true

        let service = IngestionService(
            context: container.mainContext,
            settings: { [weak self] in self?.settingsStore.settings ?? .defaultValue },
            parserBuilder: parserBuilder,
            snapshotRefresher: snapshotRefresher,
            now: { .now }
        )
        _ = await service.retryPending()
        guard !Task.isCancelled else {
            // A retry cancelled because the view went away can run again on the next appearance.
            hasRetriedPendingIngestion = false
            return
        }
        mutate()
    }
}
