import SwiftUI

/// Settings › About: the version, the privacy statement, and deleting everything Zentri keeps.
///
/// "Delete All Data" removes every row in the store, the widget snapshot, the backup-folder bookmark,
/// and the settings document once the person types the confirmation word (spec §15); the app then
/// returns to setup.
struct AboutView: View {
    @Environment(AppState.self) private var appState

    @State private var isConfirmingDeletion = false
    @State private var failureMessage: LocalizedStringResource?

    /// The marketing version and build, read once from the app bundle.
    private static let version: String = {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }()

    var body: some View {
        Form {
            Section {
                LabeledContent("Version") {
                    Text(verbatim: Self.version)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("about.version")
            }

            Section {
                Label {
                    Text("Zentri works entirely on this iPhone. There is no account to sign in to, no analytics, and no tracking. Bank messages are parsed on the device — by your own rules or Apple's on-device model — and nothing is sent to a server.")
                        .foregroundStyle(Theme.ink)
                } icon: {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(Theme.accent)
                }
            } header: {
                Text("Privacy")
            }

            Section {
                Button("Delete All Data", systemImage: "trash", role: .destructive, action: confirmDeletion)
                    .accessibilityIdentifier("about.deleteAllData")
            } header: {
                Text("Your data")
            } footer: {
                Text("Zentri returns to setup afterwards.")
            }
        }
        .scrollContentBackground(.hidden)
        .background { Theme.canvas.ignoresSafeArea() }
        .navigationTitle("About")
        .sheet(isPresented: $isConfirmingDeletion) {
            DeleteAllDataSheet(onDelete: deleteAllData)
        }
        .alert("Couldn't delete your data", item: $failureMessage) { _ in
        } message: { message in
            Text(message)
        }
        // The warning plays as the typed confirmation appears; after a deletion this screen is
        // gone, because the root returns to setup.
        .sensoryFeedback(.warning, trigger: isConfirmingDeletion) { _, isConfirming in
            isConfirming
        }
    }

    private func confirmDeletion() {
        isConfirmingDeletion = true
    }

    private func deleteAllData() {
        do {
            try appState.eraseAllData()
        } catch {
            failureMessage = "Some data may remain. Try deleting again."
        }
    }
}
