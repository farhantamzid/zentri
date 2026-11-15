import AppIntents
import Foundation
import ZentriCore

/// The action a Shortcuts "Message" automation runs to hand a bank message to Zentri.
///
/// It runs in the background without opening the app, inside the app's process. When Zentri is
/// already in memory the capture goes through its live ``AppState``, so the open screens reload;
/// otherwise it uses ``AppComposition``'s process-wide container and settings, which a window opened
/// later shares. Either way ``CaptureSMSHandler`` does the work and the intent answers with a short
/// dialog. The handler's snapshot refresher rewrites the widget snapshot and reloads the widgets.
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
        let request = IngestionRequest(
            text: smsText,
            sender: sender,
            receivedAt: messageDate ?? .now,
            accountID: account?.id
        )
        let handler: CaptureSMSHandler
        let outcome: IngestionOutcome
        if let appState = AppComposition.liveAppState {
            // Zentri is in memory: capture through its own container, and its screens reload.
            handler = appState.makeCaptureSMSHandler()
            outcome = await appState.capture(request)
        } else {
            guard let standalone = try? AppComposition.makeStandaloneCaptureHandler() else {
                return .result(dialog: IntentDialog(LocalizedStringResource(
                    "Zentri couldn't open its data. Open Zentri, then try again.",
                    comment: "Shortcut dialog when the store could not be opened."
                )))
            }
            handler = standalone
            outcome = await standalone.handle(request)
            // A window may have opened while the message was being read; it shares the container.
            AppComposition.liveAppState?.mutate()
        }
        return .result(dialog: IntentDialog(handler.dialog(for: outcome, locale: .current)))
    }
}
