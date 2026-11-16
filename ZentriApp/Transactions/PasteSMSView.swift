import SwiftUI
import ZentriCore

/// Adds a transaction from a bank message the person pastes in.
///
/// The message goes through the same pipeline as a Shortcuts capture — archived, checked for
/// duplicates, parsed, categorized, and recorded — read with the engine the person picks here,
/// which starts at the saved parser mode. A message that becomes a transaction closes the sheet and
/// hands its id back so the caller can open it for review; any other outcome keeps the sheet open
/// and says what happened, since the message is already kept in the inbox.
struct PasteSMSView: View {
    private let accounts: [TransactionAccountOption]
    private let onAdded: @MainActor (UUID) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var parserMode: ParserMode
    @State private var accountID: UUID?
    @State private var receivedAt = Date.now
    @State private var availability: ModelAvailability?
    @State private var isReading = false
    @State private var result: LocalizedStringResource?
    @FocusState private var isEditorFocused: Bool

    init(
        accounts: [TransactionAccountOption],
        parserMode: ParserMode,
        onAdded: @escaping @MainActor (UUID) -> Void
    ) {
        self.accounts = accounts
        self.onAdded = onAdded
        _parserMode = State(initialValue: parserMode)
        _accountID = State(initialValue: accounts.first?.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                messageSection
                parserSection
                detailsSection
                if let result {
                    Section {
                        Label {
                            Text(result)
                        } icon: {
                            Image(systemName: "exclamationmark.bubble")
                                .foregroundStyle(Theme.secondaryInk)
                        }
                        .accessibilityIdentifier("pasteSMS.result")
                    }
                }
            }
            .navigationTitle("Paste Bank SMS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isReading {
                        ProgressView()
                    } else {
                        Button("Add", action: read)
                            .disabled(!canRead)
                            .accessibilityIdentifier("pasteSMS.add")
                    }
                }
            }
            .interactiveDismissDisabled(isReading)
            .task {
                availability = await appState.modelClient.availability()
            }
            .onChange(of: text) { result = nil }
            .onChange(of: parserMode) { result = nil }
        }
    }

    // MARK: - Sections

    private var messageSection: some View {
        Section {
            TextField("Message", text: $text, prompt: Text("Paste the bank's SMS here"), axis: .vertical)
                .lineLimit(4...12)
                .focused($isEditorFocused)
                .accessibilityIdentifier("pasteSMS.text")
            HStack {
                PasteButton(payloadType: String.self) { strings in
                    guard let pasted = strings.first else { return }
                    text = pasted
                }
                .labelStyle(.titleAndIcon)
                .buttonBorderShape(.capsule)
                Spacer()
                if !text.isEmpty {
                    Button("Clear", role: .destructive) { text = "" }
                        .buttonStyle(.borderless)
                }
            }
        } header: {
            Text("Message")
        } footer: {
            Text("Copy the message from Messages, then paste it here.")
        }
    }

    private var parserSection: some View {
        Section {
            Picker("Read With", selection: $parserMode) {
                ForEach(ParserMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("pasteSMS.parser")
            if usesModel, case .unavailable(let reason) = availability {
                Label(reason, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryInk)
            }
        } header: {
            Text("Read With")
        } footer: {
            Text(parserMode.detail)
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        Section {
            if accounts.count > 1 {
                TransactionAccountPicker(accountID: $accountID, accounts: accounts)
            }
            DatePicker("Received", selection: $receivedAt)
        } footer: {
            Text("The date is used when the message doesn't state one.")
        }
    }

    // MARK: - Reading

    private var usesModel: Bool {
        parserMode != .rules
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canRead: Bool {
        !trimmedText.isEmpty && accountID != nil && !isReading
    }

    private func read() {
        guard canRead else { return }
        isEditorFocused = false
        isReading = true
        result = nil
        let request = IngestionRequest(text: trimmedText, receivedAt: receivedAt, accountID: accountID)
        Task {
            let outcome = await appState.capturePasted(request, parserMode: parserMode)
            isReading = false
            if case .transaction(let id) = outcome {
                dismiss()
                onAdded(id)
            } else {
                result = message(for: outcome)
            }
        }
    }

    /// What the sheet says when the message did not become a transaction.
    private func message(for outcome: IngestionOutcome) -> LocalizedStringResource {
        switch outcome {
        case .transaction:
            "The transaction was added."
        case .duplicate:
            "This message is already in Zentri, so nothing was added."
        case .notTransaction:
            "This message doesn't describe a transaction, so nothing was added."
        case .failed(let diagnostics):
            if diagnostics.contains(where: { $0.code == .modelUnavailable }) {
                "The on-device model can't run right now. Try reading the message with Rules instead."
            } else if let first = diagnostics.first {
                "Zentri couldn't read this message. \(String(localized: first.localizedMessage)) It's kept in the message inbox, where you can try again after adding a rule."
            } else {
                "Zentri couldn't read this message. It's kept in the message inbox."
            }
        }
    }
}
