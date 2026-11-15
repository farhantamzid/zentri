import SwiftUI

/// Chooses what the inbox shows: nothing yet, the failure, or the filter and its messages.
struct RawMessageInboxStateView: View {
    @Bindable var model: RawMessageInboxModel

    var body: some View {
        switch model.loadState {
        case .loading:
            Color.clear
        case .failed:
            SettingsFailureState(title: "Can't show your messages", onRetry: model.refresh)
        case .loaded:
            List {
                Section {
                    RawMessageFilterPicker(filter: $model.filter, counts: model.counts)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                if model.rows.isEmpty {
                    RawMessageEmptyState(filter: model.filter)
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(model.rows) { message in
                            NavigationLink(value: RawMessageRoute(messageID: message.id)) {
                                RawMessageRow(message: message)
                            }
                            .accessibilityIdentifier("inbox.row")
                        }
                    } footer: {
                        Text("Messages are kept until you delete them or clear the archive.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }
}
