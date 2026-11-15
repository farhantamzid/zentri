import SwiftUI

/// Records what an account's balance is, as a manual checkpoint.
///
/// The balance shown afterwards is this number plus every transaction recorded after the chosen
/// date, which is how a balance that drifted from missed messages is corrected.
struct SetBalanceView: View {
    /// Saves the balance and the date it was true.
    typealias Save = @MainActor (_ amount: Decimal, _ date: Date) async throws -> Void

    private let accountName: String
    private let onSave: Save

    @State private var model: SetBalanceModel
    @State private var isSaving = false
    @State private var failureMessage: LocalizedStringResource?

    @Environment(\.dismiss) private var dismiss

    init(account: AccountListItem, onSave: @escaping Save) {
        accountName = account.name
        self.onSave = onSave
        _model = State(initialValue: SetBalanceModel(latestCheckpoint: account.asOf))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Balance", text: $model.amountText, prompt: Text("0.00"))
                        .keyboardType(.decimalPad)
                        .font(.title3.monospacedDigit())
                        .accessibilityIdentifier("accounts.setBalance.amount")
                    DatePicker("As of", selection: $model.date, in: model.dateRange)
                } footer: {
                    Text("Enter the balance your bank shows for \(accountName). Transactions recorded after this time are added to it.")
                }
            }
            .navigationTitle("Set Balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!model.canSave || isSaving)
                        .accessibilityIdentifier("accounts.setBalance.save")
                }
            }
            .alert("Couldn't set the balance", item: $failureMessage) { _ in
            } message: { message in
                Text(message)
            }
        }
    }

    private func cancel() {
        dismiss()
    }

    private func save() {
        guard model.canSave, let amount = model.amount else { return }
        isSaving = true
        let date = model.date
        Task {
            do {
                try await onSave(amount, date)
                dismiss()
            } catch {
                failureMessage = SettingsErrorMessage.message(for: error)
            }
            isSaving = false
        }
    }
}
