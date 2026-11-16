import Foundation
import SwiftData
import ZentriCore

/// Hands one message from the Shortcut to the ingestion pipeline and describes the result.
///
/// It is the testable part of ``CaptureSMSIntent``: the intent only builds the app's shared pieces and
/// reloads the widgets, while everything here runs against whatever container, settings, parser, and
/// refresher a test supplies. The pipeline refreshes the widget snapshot itself, once per message, so
/// the handler never refreshes again.
@MainActor
final class CaptureSMSHandler {
    private let container: ModelContainer
    private let settingsStore: SettingsStore
    private let parserBuilder: any ParserBuilding
    private let snapshotRefresher: any WidgetSnapshotRefresher

    init(
        container: ModelContainer,
        settingsStore: SettingsStore,
        parserBuilder: any ParserBuilding,
        snapshotRefresher: any WidgetSnapshotRefresher
    ) {
        self.container = container
        self.settingsStore = settingsStore
        self.parserBuilder = parserBuilder
        self.snapshotRefresher = snapshotRefresher
    }

    /// Ingests the message, or refuses it without touching the store.
    ///
    /// A capture before onboarding has finished is refused, since there are no settings and no account
    /// to file it under, and so is empty text. Neither is archived. When the request names no account
    /// the pipeline resolves one itself.
    ///
    /// Settings that exist but could not be read are read again first, since the failure is
    /// remembered for the life of the process. If they are still unreadable the message is archived
    /// unparsed, as `processing`: the accounts and rules are intact, and the retry that runs once the
    /// settings are fixed reads it. A real message is never dropped.
    ///
    /// - Parameter parserMode: The engine to read this one message with, when the person chose one
    ///   for a pasted message; `nil` uses the saved parser mode.
    func handle(_ request: IngestionRequest, parserMode: ParserMode? = nil) async -> IngestionOutcome {
        if settingsStore.settings == nil, settingsStore.loadFailure != nil {
            try? settingsStore.load()
        }
        let settingsAreUnreadable = settingsStore.settings == nil && settingsStore.loadFailure != nil
        guard settingsStore.settings != nil || settingsAreUnreadable else {
            return .failed([CaptureSMSDiagnostics.setupIncomplete])
        }
        guard !request.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failed([CaptureSMSDiagnostics.emptyText])
        }
        let service = IngestionService(
            context: container.mainContext,
            // Read per message, so a parser-mode change applies without rebuilding the handler.
            settings: { [settingsStore] in
                var settings = settingsStore.settings ?? .defaultValue
                if let parserMode {
                    settings.parserMode = parserMode
                }
                return settings
            },
            parserBuilder: parserBuilder,
            snapshotRefresher: snapshotRefresher,
            now: { .now }
        )
        if settingsAreUnreadable {
            return await service.archiveForRetry(request, reporting: CaptureSMSDiagnostics.settingsUnreadable)
        }
        return await service.ingest(request)
    }

    /// The Shortcut's dialog for an outcome, with amounts in the person's currency and grouping.
    func dialog(for outcome: IngestionOutcome, locale: Locale) -> LocalizedStringResource {
        let settings = settingsStore.settings ?? .defaultValue
        let format = MoneyFormat(currencyCode: settings.currencyCode, grouping: settings.numberGrouping, locale: locale)
        return CaptureSMSDialog(context: container.mainContext, format: format).message(for: outcome)
    }
}
