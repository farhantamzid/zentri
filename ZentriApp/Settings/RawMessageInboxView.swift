import SwiftUI

/// The raw-message inbox, reached from Settings › Parsing and the Overview's health card.
///
/// This view only supplies what the content needs from the app's shared state; everything else lives
/// in ``RawMessageInboxContent``.
struct RawMessageInboxView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        RawMessageInboxContent(
            model: RawMessageInboxModel(
                context: appState.container.mainContext,
                archive: appState.makeRawMessageReprocessor(),
                reprocess: appState.reprocess,
                reprocessFailures: appState.reprocessFailures,
                onMutation: appState.mutate
            ),
            dataRevision: appState.dataRevision
        )
        .background { Theme.canvas.ignoresSafeArea() }
        .navigationTitle("Message Inbox")
    }
}
