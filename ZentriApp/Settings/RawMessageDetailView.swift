import SwiftUI

/// One archived message, read from the inbox's shared model so a change here shows at once in the
/// list behind it.
struct RawMessageDetailView: View {
    let model: RawMessageInboxModel
    let messageID: UUID

    var body: some View {
        if let message = model.message(id: messageID) {
            RawMessageDetailForm(model: model, message: message)
                .navigationTitle("Message")
                .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView(
                "Message not found",
                systemImage: "tray",
                description: Text("This message is no longer in the archive.")
            )
        }
    }
}
