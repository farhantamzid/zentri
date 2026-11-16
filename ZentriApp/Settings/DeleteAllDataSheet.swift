import SwiftUI

/// Asks for the confirmation word before everything Zentri keeps is deleted.
///
/// The delete button stays disabled until the word is typed. The explanation says what goes and
/// what stays — exported backups and the backup folder are untouched — before anything is deleted.
/// A `Form` scrolls, so the explanation, the field, and the button all stay reachable at the largest
/// accessibility text sizes.
struct DeleteAllDataSheet: View {
    /// Runs the deletion once the person confirms; the sheet has already been dismissed.
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var typedText = ""

    private let confirmation = DeleteAllDataConfirmation()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Every account, balance, transaction, saved message, rule, and category on this iPhone is deleted, along with your settings and the widget data, and automatic backups stop. Backups you exported or saved to your backup folder are not touched. This can't be undone.")
                        .foregroundStyle(Theme.ink)
                }

                Section {
                    TextField(
                        "Confirmation word",
                        text: $typedText,
                        prompt: Text(verbatim: confirmation.word)
                    )
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .accessibilityHint(Text("Type \(confirmation.word) to turn on Delete All Data."))
                    .accessibilityIdentifier("about.deleteConfirmation.field")
                } header: {
                    Text("Type \(confirmation.word) to confirm")
                }

                Section {
                    Button("Delete All Data", systemImage: "trash", role: .destructive, action: delete)
                        .disabled(!confirmation.isConfirmed(by: typedText))
                        .accessibilityIdentifier("about.deleteConfirmation.delete")
                }
            }
            .scrollContentBackground(.hidden)
            .background { Theme.canvas.ignoresSafeArea() }
            .navigationTitle("Delete All Data?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
            }
        }
    }

    private func delete() {
        guard confirmation.isConfirmed(by: typedText) else { return }
        dismiss()
        onDelete()
    }

    private func cancel() {
        dismiss()
    }
}
