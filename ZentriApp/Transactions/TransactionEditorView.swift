import SwiftUI
import ZentriCore

/// Adds a missed transaction by hand, or edits an existing one.
///
/// Save stays disabled until the edit could be valid — an amount above zero, an account, and a
/// merchant — and the service checks again, so a refused save keeps the sheet open with the reason.
struct TransactionEditorView: View {
    private let title: LocalizedStringResource
    private let accounts: [TransactionAccountOption]
    private let categories: [TransactionCategoryOption]
    private let onSave: @MainActor (TransactionEdit) async throws -> Void

    @State private var amount: Decimal?
    @State private var direction: Direction
    @State private var merchant: String
    @State private var accountID: UUID?
    @State private var categoryID: UUID?
    @State private var occurredAt: Date
    @State private var note: String
    @State private var isTransfer: Bool
    @State private var isSaving = false
    @State private var failureMessage: LocalizedStringResource?

    @Environment(\.dismiss) private var dismiss

    /// - Parameter initial: The transaction as it stands, or `nil` for a new manual transaction,
    ///   which starts as a debit on the first account, dated now.
    init(
        title: LocalizedStringResource,
        initial: TransactionEdit?,
        accounts: [TransactionAccountOption],
        categories: [TransactionCategoryOption],
        onSave: @escaping @MainActor (TransactionEdit) async throws -> Void
    ) {
        self.title = title
        self.accounts = accounts
        self.categories = categories
        self.onSave = onSave
        _amount = State(initialValue: initial?.amount)
        _direction = State(initialValue: initial?.direction ?? .debit)
        _merchant = State(initialValue: initial?.merchant ?? "")
        _accountID = State(initialValue: initial?.accountID ?? accounts.first?.id)
        _categoryID = State(initialValue: initial?.categoryID)
        _occurredAt = State(initialValue: initial?.occurredAt ?? .now)
        _note = State(initialValue: initial?.note ?? "")
        _isTransfer = State(initialValue: initial?.isTransfer ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount", value: $amount, format: .number, prompt: Text("0.00"))
                        .keyboardType(.decimalPad)
                        .font(.title2.monospacedDigit())
                        .accessibilityIdentifier("transactions.editor.amount")
                    Picker("Direction", selection: $direction) {
                        ForEach(Direction.allCases, id: \.self) { direction in
                            Text(direction.displayName).tag(direction)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField("Merchant", text: $merchant)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("transactions.editor.merchant")
                }

                Section {
                    TransactionAccountPicker(accountID: $accountID, accounts: accounts)
                    TransactionCategoryPicker(categoryID: $categoryID, categories: categories)
                    DatePicker("Date", selection: $occurredAt)
                    Toggle("Transfer", isOn: $isTransfer)
                }

                Section("Note") {
                    TextField("Note", text: $note, prompt: Text("Optional"), axis: .vertical)
                        .lineLimit(1...5)
                }
            }
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(edit == nil || isSaving)
                        .accessibilityIdentifier("transactions.editor.save")
                }
            }
            .alert("Couldn't save the transaction", item: $failureMessage) { _ in
            } message: { message in
                Text(message)
            }
        }
    }

    /// The edit the form describes, or `nil` while it cannot be valid.
    private var edit: TransactionEdit? {
        guard let amount, amount > 0, let accountID,
              !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return TransactionEdit(
            accountID: accountID,
            amount: amount,
            direction: direction,
            occurredAt: occurredAt,
            merchant: merchant,
            categoryID: categoryID,
            note: note,
            isTransfer: isTransfer
        )
    }

    private func cancel() {
        dismiss()
    }

    private func save() {
        guard let edit else { return }
        isSaving = true
        Task {
            await perform(edit)
        }
    }

    private func perform(_ edit: TransactionEdit) async {
        do {
            try await onSave(edit)
            dismiss()
        } catch let error as TransactionMutationError {
            failureMessage = error.message
        } catch {
            failureMessage = "Zentri couldn't save your changes. Try again."
        }
        isSaving = false
    }
}
