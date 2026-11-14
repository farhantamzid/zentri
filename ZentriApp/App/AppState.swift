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
