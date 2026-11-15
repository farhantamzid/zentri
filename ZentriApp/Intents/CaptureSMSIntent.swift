import AppIntents
import Foundation
import WidgetKit
import ZentriCore

/// The action a Shortcuts "Message" automation runs to hand a bank message to Zentri.
///
/// It runs in the background without opening the app: it builds the same store, settings, parser,
/// and widget plumbing the app uses, hands the message to ``CaptureSMSHandler``, and answers with a
/// short dialog. Only a new transaction changes what the widgets show, so only that reloads them.
struct CaptureSMSIntent: AppIntent {
    static let title = LocalizedStringResource(
        "Capture Bank SMS",
        comment: "The Shortcuts action that sends a bank message to Zentri."
    )
    static let description = IntentDescription(
        LocalizedStringResource(
            "Reads a bank message on this iPhone and records its transaction in Zentri.",
            comment: "The Shortcuts description of the Capture Bank SMS action."
        )
    )
    /// Background only: the capture must never bring Zentri to the front.
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: LocalizedStringResource("SMS Text", comment: "The capture action's parameter for the message text."),
        inputOptions: String.IntentInputOptions(multiline: true)
    )
    var smsText: String

    @Parameter(
        title: LocalizedStringResource("Account", comment: "The Shortcuts name for a Zentri bank account.")
    )
    var account: AccountEntity?

    @Parameter(
        title: LocalizedStringResource("Sender", comment: "The capture action's parameter for the message sender.")
    )
    var sender: String?

    @Parameter(
        title: LocalizedStringResource("Message Date", comment: "The capture action's parameter for when the message arrived.")
    )
    var messageDate: Date?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let settingsStore = AppComposition.makeSettingsStore()
        guard let container = try? AppComposition.makeContainer() else {
            return .result(dialog: IntentDialog(LocalizedStringResource(
                "Zentri couldn't open its data. Open Zentri, then try again.",
                comment: "Shortcut dialog when the store could not be opened."
            )))
        }
        let handler = CaptureSMSHandler(
            container: container,
            settingsStore: settingsStore,
            parserBuilder: ParserFactory(modelClient: AppComposition.makeModelClient()),
            snapshotRefresher: AppComposition.makeSnapshotRefresher(
                container: container,
                settingsStore: settingsStore,
                snapshotStore: AppComposition.makeSnapshotStore()
            )
        )
        let request = IngestionRequest(
            text: smsText,
            sender: sender,
            receivedAt: messageDate ?? .now,
            accountID: account?.id
        )
        let outcome = await handler.handle(request)
        if case .transaction = outcome {
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result(dialog: IntentDialog(handler.dialog(for: outcome, locale: .current)))
    }
}
