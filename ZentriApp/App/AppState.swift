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
    /// The parser builder ingestion, reprocessing, and the rule tester use.
    let parserBuilder: any ParserBuilding
    /// The on-device model client, asked only whether the model can run here.
    let modelClient: any TransactionModelClient
    /// The refresher that keeps widgets in step with the store: it rewrites the snapshot and reloads
    /// the widgets, and "Delete All Data" removes the snapshot through it.
    let snapshotRefresher: WidgetSnapshotPublisher
    /// The folder automatic backups go to and restores are browsed from.
    let backupFolder: any BackupFolderAccessing
    /// Writes automatic snapshots after data changes and when the app goes to the background.
    let backupScheduler: BackupScheduler
    /// Keeps the app alive long enough for the background backup to finish.
    private let backgroundTasks: any BackgroundTaskRunning

    /// The selected root tab.
    var selectedTab: AppTab = .overview
    /// A filter the Insights tab can hand to Transactions.
    var transactionFilter = TransactionFilter()
    /// A counter screens watch to reload after a mutation elsewhere.
    private(set) var dataRevision = 0
    /// Counts restores that replaced every stored row. The tabs other than Settings rebuild their
    /// navigation when it changes, so no pushed screen keeps a row that no longer exists.
    private(set) var storeReplacementCount = 0

    /// Whether the launch retry has already run, so it runs at most once per session.
    @ObservationIgnored private var hasRetriedPendingIngestion = false
    /// Whether a retry is running, so a launch retry and a foreground retry never overlap.
    @ObservationIgnored private var isRetryingPendingIngestion = false

    init(
        container: ModelContainer,
        settingsStore: SettingsStore,
        parserBuilder: any ParserBuilding,
        modelClient: any TransactionModelClient,
        snapshotStore: any WidgetSnapshotStore,
        timelineReloader: any WidgetTimelineReloading,
        backupFolder: any BackupFolderAccessing = InertBackupFolder(),
        backgroundTasks: any BackgroundTaskRunning = ImmediateBackgroundTasks()
    ) {
        self.container = container
        self.settingsStore = settingsStore
        self.parserBuilder = parserBuilder
        self.modelClient = modelClient
        self.snapshotRefresher = AppComposition.makeSnapshotRefresher(
            container: container,
            settingsStore: settingsStore,
            snapshotStore: snapshotStore,
            timelineReloader: timelineReloader
        )
        self.backupFolder = backupFolder
        self.backgroundTasks = backgroundTasks
        self.backupScheduler = BackupScheduler(
            folder: backupFolder,
            makeDocument: { [container, settingsStore] in
                guard let settings = settingsStore.settings else { return nil }
                return try BackupExporter(settings: settings)
                    .export(context: container.mainContext, appVersion: AppState.appVersion)
            },
            didBackUp: { [settingsStore] date in
                // The current settings, not the ones exported: a change made during the write stays.
                // A failure to record the time only leaves the status line behind; the snapshot is safe.
                guard var settings = settingsStore.settings else { return }
                settings.lastBackupAt = date
                try? settingsStore.save(settings)
            }
        )
    }

    /// The marketing version a backup records.
    static let appVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }()

    /// A backup of everything stored, with the current settings, for a manual export.
    ///
    /// - Throws: An error when the store cannot be read.
    func makeBackupDocument() throws -> BackupDocument {
        try BackupExporter(settings: settingsStore.settings ?? .defaultValue)
            .export(context: container.mainContext, appVersion: Self.appVersion)
    }

    /// Restores a backup and tells every screen, the widgets, and the automatic backup.
    ///
    /// Order, chosen so a failure part-way is never silent and never touches data it should not:
    /// 1. For a replace, the backup's settings are converted first, so a malformed settings block is
    ///    rejected before any row changes.
    /// 2. The importer validates the whole document and swaps (or merges) the rows in one save; if
    ///    it throws, the store is rolled back and nothing has changed.
    /// 3. For a replace, the settings are saved last. If that save fails the rows are already
    ///    restored, so every screen is still told, and ``BackupRestoreError/settingsNotSaved`` is
    ///    thrown so the person learns the previous currency is still in use; restoring again retries.
    ///
    /// When this device has settings, its own `lastBackupAt` and `iCloudBackupEnabled` are kept:
    /// they describe this device's backup folder, not the backup's. A merge never changes settings.
    /// This works from the settings-recovery screen too, where saving the backup's settings clears
    /// the load failure.
    func restoreBackup(_ document: BackupDocument, mode: ImportMode) async throws -> ImportSummary {
        let restoredSettings = mode == .replace ? try settingsToRestore(from: document) : nil
        let summary = try BackupImporter().import(document: document, into: container.mainContext, mode: mode)
        if mode == .replace {
            storeReplacementCount += 1
            transactionFilter = TransactionFilter()
        }
        var settingsError: (any Error)?
        if let restoredSettings {
            do {
                try settingsStore.save(restoredSettings)
            } catch {
                settingsError = error
            }
        }
        await snapshotRefresher.refresh()
        mutate()
        if settingsError != nil {
            throw BackupRestoreError.settingsNotSaved
        }
        return summary
    }

    /// The backup's settings, keeping this device's backup history when it has one.
    private func settingsToRestore(from document: BackupDocument) throws -> AppSettings {
        var settings = try document.settings.makeAppSettings()
        if let current = settingsStore.settings {
            settings.lastBackupAt = current.lastBackupAt
            settings.iCloudBackupEnabled = current.iCloudBackupEnabled
        } else {
            settings.lastBackupAt = nil
        }
        return settings
    }

    /// Writes a pending automatic backup now, with background time to finish it.
    func sceneDidEnterBackground() {
        backgroundTasks.run(named: "Zentri backup") { [backupScheduler] in
            await backupScheduler.flush()
        }
    }

    /// Selects the tab a `zentri://` widget link names; any other URL is ignored.
    func open(_ url: URL) {
        guard let link = DeepLink(url: url) else { return }
        selectedTab = AppTab(deepLink: link)
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

    /// A service for the person's parsing rules. Rules change no balance, so the caller only calls
    /// ``mutate()`` afterwards.
    func makeParsingRuleMutationService() -> ParsingRuleMutationService {
        ParsingRuleMutationService(context: container.mainContext)
    }

    /// The rule tester, which parses with the same builder ingestion uses and never writes.
    func makeRuleTesterService() -> RuleTesterService {
        RuleTesterService(parserBuilder: parserBuilder)
    }

    /// The archive's reprocessor, refreshing the widgets after each reprocess.
    func makeRawMessageReprocessor() -> RawMessageReprocessor {
        RawMessageReprocessor(
            context: container.mainContext,
            parserBuilder: parserBuilder,
            snapshotRefresher: snapshotRefresher
        )
    }

    /// The parser mode new messages and reprocessing use.
    var parserMode: ParserMode {
        (settingsStore.settings ?? .defaultValue).parserMode
    }

    /// Parses an archived message again with the stored rules and the saved parser mode, then tells
    /// every screen.
    ///
    /// The rules are read first: a rule list that cannot be read is reported as a storage failure,
    /// never parsed as "no rules", which would wrongly mark the message as not a transaction.
    func reprocess(_ message: RawMessage, accountID: UUID?) async -> IngestionOutcome {
        guard let rules = try? StoredParsingRules.specs(in: container.mainContext) else {
            return .failed([Self.unreadableRulesDiagnostic])
        }
        let outcome = await makeRawMessageReprocessor().reprocess(
            message,
            accountID: accountID,
            rules: rules,
            mode: parserMode
        )
        mutate()
        return outcome
    }

    /// Reprocesses every failed message with the stored rules, then tells every screen.
    func reprocessFailures() async -> [IngestionOutcome] {
        guard let rules = try? StoredParsingRules.specs(in: container.mainContext) else {
            return [.failed([Self.unreadableRulesDiagnostic])]
        }
        let outcomes = await makeRawMessageReprocessor().reprocessFailures(rules: rules, mode: parserMode)
        mutate()
        return outcomes
    }

    /// Reported when the rules could not be read for a reprocess.
    private static let unreadableRulesDiagnostic = ParseDiagnostic(
        code: .missingField,
        field: "storage",
        message: "The rules could not be read."
    )

    /// Saves new settings, then rewrites the widget snapshot, which carries the currency and grouping.
    ///
    /// Every money label re-renders on its own: the root reads ``moneyFormat(locale:)`` from the
    /// observed settings. Changing the currency never converts a stored amount.
    func updateSettings(_ settings: AppSettings) async throws {
        try settingsStore.save(settings)
        await snapshotRefresher.refresh()
    }

    /// Replaces settings that could not be read with the defaults.
    ///
    /// The accounts, transactions, and rules live in the store, not in settings. When the store
    /// already holds an account the default settings are saved and the app opens on them; running
    /// setup again would add a second account and opening balance beside the existing ones. Only a
    /// store with no account returns to setup, as a fresh install does. A store that cannot be read
    /// is treated as holding accounts, so nothing is added to it.
    func useDefaultSettings() async throws {
        let accountCount = (try? container.mainContext.fetchCount(FetchDescriptor<Account>())) ?? 1
        guard accountCount > 0 else {
            try settingsStore.reset()
            return
        }
        try settingsStore.save(.defaultValue)
        await snapshotRefresher.refresh()
        mutate()
    }

    /// Deletes everything Zentri keeps on this device and returns the app to setup.
    ///
    /// The store goes first, in one save: if that fails nothing has changed. Then the widget
    /// snapshot is removed and the widgets reloaded, so no widget keeps showing a balance from
    /// deleted data — they draw their "Open Zentri" placeholder instead — and last the
    /// settings document, which is what sends the root back to onboarding. A failure after the
    /// store is empty leaves a state the person can finish by deleting again. In `-UITestMode` the
    /// store is in memory, the snapshot store is inert, and the settings repository is in memory, so
    /// nothing real is touched. The backup folder's bookmark is forgotten as well, so no automatic
    /// backup follows; the backups already in that folder are the person's files and are kept.
    func eraseAllData() throws {
        try StoreEraser().eraseAll(in: container.mainContext)
        try snapshotRefresher.removeSnapshot()
        backupScheduler.cancel()
        backupFolder.forgetFolder()
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

    /// Retries messages that an interruption left `processing`, once per session.
    ///
    /// While onboarding is showing there are no settings and nothing to retry, so this is a no-op.
    /// Returning to the foreground retries again through ``sceneDidBecomeActive()``.
    func retryPendingIngestion() async {
        guard settingsStore.settings != nil, !hasRetriedPendingIngestion else { return }
        hasRetriedPendingIngestion = true
        if await !runPendingRetry() {
            // A retry cancelled because the view went away can run again on the next appearance.
            hasRetriedPendingIngestion = false
        }
    }

    /// Catches up after the app returns to the foreground.
    ///
    /// A Shortcuts capture can run while Zentri is suspended in memory. It writes through this state's
    /// container, so every screen only needs to reload; and a capture that was cancelled left its
    /// message `processing`, so pending messages are retried now rather than on the next cold launch.
    func sceneDidBecomeActive() async {
        mutate()
        guard settingsStore.settings != nil else { return }
        hasRetriedPendingIngestion = true
        _ = await runPendingRetry()
    }

    /// Runs one Shortcuts capture through this state's container and settings, then tells every
    /// screen, so a capture made while the app is alive shows without a relaunch.
    func capture(_ request: IngestionRequest) async -> IngestionOutcome {
        let outcome = await makeCaptureSMSHandler().handle(request)
        mutate()
        return outcome
    }

    /// A capture handler over this state's container, settings, parser, and widget refresher.
    func makeCaptureSMSHandler() -> CaptureSMSHandler {
        CaptureSMSHandler(
            container: container,
            settingsStore: settingsStore,
            parserBuilder: parserBuilder,
            snapshotRefresher: snapshotRefresher
        )
    }

    /// Retries every pending message and tells every screen; returns `false` when cancelled.
    ///
    /// Only one retry runs at a time, so a launch retry and a foreground retry can never parse the
    /// same row twice. The service is built per retry with a live settings provider, so a
    /// parser-mode change applies to the next attempt instead of freezing today's settings.
    private func runPendingRetry() async -> Bool {
        guard !isRetryingPendingIngestion else { return true }
        isRetryingPendingIngestion = true
        defer { isRetryingPendingIngestion = false }

        let service = IngestionService(
            context: container.mainContext,
            settings: { [weak self] in self?.settingsStore.settings ?? .defaultValue },
            parserBuilder: parserBuilder,
            snapshotRefresher: snapshotRefresher,
            now: { .now }
        )
        _ = await service.retryPending()
        guard !Task.isCancelled else { return false }
        mutate()
        return true
    }
}
