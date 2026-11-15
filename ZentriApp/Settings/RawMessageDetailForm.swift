import SwiftUI
import ZentriCore

/// The message in full — text, status, error, matched rule, and transaction — with reprocess, copy,
/// and delete.
///
/// Reprocessing a parsed message asks first, because it rewrites its transaction. A message with
/// no transaction and several possible accounts asks which account it belongs to instead of
/// guessing.
struct RawMessageDetailForm: View {
    let model: RawMessageInboxModel
    let message: RawMessageListItem

    @State private var isConfirmingReprocess = false
    @State private var isChoosingAccount = false
    @State private var isConfirmingDelete = false
    @State private var isReprocessing = false
    @State private var outcomeMessage: LocalizedStringResource?
    @State private var transactionSelection: TransactionSelection?
    @State private var parsedCount = 0
    @State private var copiedCount = 0
    @State private var failureMessage: LocalizedStringResource?

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            RawMessageDetailSections(message: message, outcomeMessage: outcomeMessage)

            if message.hasTransaction {
                Section {
                    Button("View Transaction", systemImage: "list.bullet.rectangle.portrait", action: showTransaction)
                        .frame(minHeight: Theme.Layout.minimumTapTarget)
                        .accessibilityIdentifier("inbox.detail.transaction")
                }
            }

            Section {
                Button(action: startReprocess) {
                    Label("Reprocess", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget, alignment: .leading)
                        .contentShape(.rect)
                }
                .disabled(isReprocessing)
                .accessibilityIdentifier("inbox.detail.reprocess")
                .confirmationDialog("Reprocess this message?", isPresented: $isConfirmingReprocess, titleVisibility: .visible) {
                    Button("Reprocess", action: reprocessWithoutChoice)
                } message: {
                    Text("Its transaction is replaced only if the message parses. Your note, transfer setting, and chosen category are kept.")
                }
                .confirmationDialog("Which account is this message from?", isPresented: $isChoosingAccount, titleVisibility: .visible) {
                    ForEach(model.accounts) { account in
                        Button(account.name) {
                            reprocess(accountID: account.id)
                        }
                    }
                }

                Button(action: copyText) {
                    Label("Copy Text", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget, alignment: .leading)
                        .contentShape(.rect)
                }
                .accessibilityIdentifier("inbox.detail.copy")
            }

            Section {
                Button(role: .destructive, action: confirmDelete) {
                    Label("Delete Message", systemImage: "trash")
                        .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget, alignment: .leading)
                        .contentShape(.rect)
                }
                .accessibilityIdentifier("inbox.detail.delete")
                .confirmationDialog("Delete this message?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                    Button("Delete Message", role: .destructive, action: delete)
                } message: {
                    Text("The message leaves the archive. Any transaction it became is kept.")
                }
                .sensoryFeedback(.warning, trigger: isConfirmingDelete) { _, isShowing in isShowing }
            }
        }
        .scrollContentBackground(.hidden)
        .sheet(item: $transactionSelection) { selection in
            TransactionDetailView(
                selection: selection,
                service: appState.makeTransactionMutationService(),
                accounts: model.accounts,
                categories: model.categories,
                onMutation: appState.mutate,
                onReprocess: appState.reprocess
            )
        }
        .alert("Couldn't delete the message", item: $failureMessage) { _ in
        } message: { message in
            Text(message)
        }
        .sensoryFeedback(.success, trigger: parsedCount)
        .sensoryFeedback(.success, trigger: copiedCount)
    }

    /// Asks first when the message has a transaction to rewrite, or when its account is ambiguous.
    private func startReprocess() {
        if message.hasTransaction {
            isConfirmingReprocess = true
        } else if model.needsAccountChoice(id: message.id) {
            isChoosingAccount = true
        } else {
            reprocess(accountID: nil)
        }
    }

    private func reprocessWithoutChoice() {
        reprocess(accountID: nil)
    }

    private func reprocess(accountID: UUID?) {
        isReprocessing = true
        let id = message.id
        Task {
            if let outcome = await model.reprocess(id: id, accountID: accountID) {
                outcomeMessage = outcome.reprocessMessage
                if outcome.isTransaction {
                    parsedCount += 1
                }
            }
            isReprocessing = false
        }
    }

    private func showTransaction() {
        transactionSelection = model.transactionSelection(forMessage: message.id)
    }

    private func copyText() {
        Clipboard.copy(message.text)
        copiedCount += 1
    }

    private func confirmDelete() {
        isConfirmingDelete = true
    }

    private func delete() {
        do {
            try model.delete(id: message.id)
            dismiss()
        } catch {
            failureMessage = "Zentri couldn't save your changes. Try again."
        }
    }
}
