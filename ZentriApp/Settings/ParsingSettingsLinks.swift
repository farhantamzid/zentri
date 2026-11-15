import SwiftUI

/// The rows that open the rule list, the tester, and the inbox, with their counts.
///
/// A count that could not be read says so instead of showing zero.
struct ParsingSettingsLinks: View {
    let model: ParsingSettingsModel

    var body: some View {
        Section {
            NavigationLink(value: ParsingRoute.rules(accountID: nil)) {
                LabeledContent {
                    countText(model.ruleCount)
                } label: {
                    Label("Rules", systemImage: "list.bullet.rectangle")
                }
            }
            .accessibilityIdentifier("parsing.rules")

            NavigationLink(value: ParsingRoute.tester) {
                Label("Rule Tester", systemImage: "testtube.2")
            }
            .accessibilityIdentifier("parsing.tester")
        } header: {
            Text("Rules")
        } footer: {
            Text("Each account has its own debit and credit rules. The tester tries a message without saving anything.")
        }

        Section {
            NavigationLink(value: ParsingRoute.inbox) {
                LabeledContent {
                    countText(model.failedMessageCount)
                } label: {
                    Label("Message Inbox", systemImage: "tray.full")
                }
            }
            .accessibilityIdentifier("parsing.inbox")
        } header: {
            Text("Messages")
        } footer: {
            Text("Every message Zentri receives is kept here. The number is how many failed to parse.")
        }
    }

    private func countText(_ count: Int) -> Text {
        switch model.loadState {
        case .loading: Text(verbatim: "")
        case .failed: Text("Unavailable")
        case .loaded: Text(count, format: .number)
        }
    }
}
