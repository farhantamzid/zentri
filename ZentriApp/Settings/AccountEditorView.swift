import SwiftUI

/// Adds an account with its opening balance, or edits an account's name and institution.
///
/// Save stays disabled until the fields could be valid, and the service checks again, so a refused
/// save keeps the sheet open with the reason.
struct AccountEditorView: View {
    /// Saves the name, the institution, and — for a new account — the opening balance.
    typealias Save = @MainActor (_ name: String, _ institutionName: String, _ openingBalance: Decimal?) async throws -> Void

    private let onSave: Save

    @State private var model: AccountEditorModel
    @State private var isSaving = false
    @State private var failureMessage: LocalizedStringResource?

    @Environment(\.dismiss) private var dismiss

    /// - Parameter account: The account to edit, or `nil` to add one.
    init(account: AccountListItem?, onSave: @escaping Save) {
        self.onSave = onSave
        _model = State(initialValue: AccountEditorModel(account: account))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $model.name, prompt: Text("Everyday Account"))
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("accounts.editor.name")
                    TextField("Institution", text: $model.institutionName, prompt: Text("Optional"))
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("accounts.editor.institution")
                }

                if model.isCreating {
                    Section {
                        TextField("Opening balance", text: $model.openingBalanceText, prompt: Text("0.00"))
                            .keyboardType(.decimalPad)
                            .font(.title3.monospacedDigit())
                            .accessibilityIdentifier("accounts.editor.openingBalance")
                    } header: {
                        Text("Opening balance")
                    } footer: {
                        Text("The balance this account has right now. Later messages and transactions add to it.")
                    }
                }
            }
            .navigationTitle(model.isCreating ? "New Account" : "Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!model.canSave || isSaving)
                        .accessibilityIdentifier("accounts.editor.save")
                }
            }
            .alert("Couldn't save the account", item: $failureMessage) { _ in
            } message: { message in
                Text(message)
            }
        }
    }

    private func cancel() {
        dismiss()
    }

    private func save() {
        guard model.canSave else { return }
        isSaving = true
        Task {
            do {
                try await onSave(model.name, model.institutionName, model.isCreating ? model.openingBalance : nil)
                dismiss()
            } catch {
                failureMessage = SettingsErrorMessage.message(for: error)
            }
            isSaving = false
        }
    }
}
