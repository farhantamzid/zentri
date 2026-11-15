import SwiftUI
import ZentriCore

/// Adds or edits a parsing rule, with a live preview of the pattern against a sample message.
///
/// Save stays disabled until the pattern compiles and has an `amount` group, and the rule has a
/// name and an account. The service checks again, so a refused save keeps the sheet open and says
/// why. The sample is only for trying the pattern and is never stored.
struct RuleEditorView: View {
    typealias Save = @MainActor (ParsingRuleDraft) throws -> Void

    private let onSave: Save

    @State private var model: RuleEditorModel
    @State private var failureMessage: LocalizedStringResource?

    @Environment(\.dismiss) private var dismiss

    init(
        rule: ParsingRuleListItem?,
        defaultAccountID: UUID?,
        accounts: [TransactionAccountOption],
        previewer: @escaping @MainActor (ParsingRuleSpec, String) async -> RulePreview,
        onSave: @escaping Save
    ) {
        self.onSave = onSave
        _model = State(
            initialValue: RuleEditorModel(
                rule: rule,
                defaultAccountID: defaultAccountID,
                accounts: accounts,
                previewer: previewer
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                RuleEditorDetailsSection(model: model)
                RuleEditorPatternSection(model: model)
                RuleGroupCheatSheet(onUseExample: model.useExamplePattern)
                RuleEditorSampleSection(model: model)
            }
            .navigationTitle(model.isCreating ? "New Rule" : "Edit Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!model.canSave)
                        .accessibilityIdentifier("ruleEditor.save")
                }
            }
            .task(id: model.previewInput) {
                await model.refreshPreview()
            }
            .alert("Couldn't save the rule", item: $failureMessage) { _ in
            } message: { message in
                Text(message)
            }
        }
    }

    private func cancel() {
        dismiss()
    }

    private func save() {
        guard let draft = model.draft else { return }
        do {
            try onSave(draft)
            dismiss()
        } catch {
            failureMessage = SettingsErrorMessage.message(for: error)
        }
    }
}
