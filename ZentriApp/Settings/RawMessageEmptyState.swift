import SwiftUI

/// What the inbox shows when the selected filter holds no messages.
struct RawMessageEmptyState: View {
    let filter: RawMessageFilter

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                Image(systemName: "tray")
            }
        } description: {
            Text(description)
        }
        .accessibilityIdentifier("inbox.empty")
    }

    private var title: LocalizedStringResource {
        switch filter {
        case .failed: "No failed messages"
        case .ignored: "No ignored messages"
        case .parsed: "No parsed messages"
        case .duplicate: "No duplicates"
        }
    }

    private var description: LocalizedStringResource {
        switch filter {
        case .failed: "Every message Zentri received was read or set aside."
        case .ignored: "Messages that aren't transactions, such as one-time passwords, appear here."
        case .parsed: "Messages that became transactions appear here."
        case .duplicate: "Repeats of a message that's already stored appear here."
        }
    }
}
