import SwiftUI
import ZentriCore

/// The rule list with add, edit, switch, delete, and "Reprocess Failures" after a change.
///
/// The content owns the model, so the list survives re-renders; it reads the store when it appears
/// and whenever a mutation anywhere bumps the revision.
struct ParsingRulesContent: View {
    @State private var model: ParsingRulesModel
    @State private var tester: RuleTesterService
    @State private var isAdding = false
    @State private var editing: ParsingRuleListItem?
    @State private var failureMessage: LocalizedStringResource?
    @State private var reprocessSummary: ReprocessSummary?
    @State private var isReprocessing = false
    @State private var savedCount = 0
    private let dataRevision: Int

    init(model: ParsingRulesModel, tester: RuleTesterService, dataRevision: Int) {
        _model = State(initialValue: model)
        _tester = State(initialValue: tester)
        self.dataRevision = dataRevision
    }

    var body: some View {
        ParsingRulesStateView(
            model: model,
            isReprocessing: isReprocessing,
            onAdd: startAdding,
            onEdit: startEditing,
            onToggle: toggle,
            onDelete: delete,
            onReprocessFailures: reprocessFailures
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Rule", systemImage: "plus", action: startAdding)
                    .disabled(model.defaultAccountID == nil)
                    .accessibilityIdentifier("parsingRules.add")
            }
        }
        .onAppear(perform: model.refresh)
        .onChange(of: dataRevision) {
            model.refresh()
        }
        .sheet(isPresented: $isAdding) {
            RuleEditorView(
                rule: nil,
                defaultAccountID: model.defaultAccountID,
                accounts: model.accounts,
                previewer: tester.preview,
                onSave: create
            )
        }
        .sheet(item: $editing) { rule in
            RuleEditorView(
                rule: rule,
                defaultAccountID: rule.accountID,
                accounts: model.accounts,
                previewer: tester.preview,
                onSave: update
            )
        }
        .alert("Couldn't update the rule", item: $failureMessage) { _ in
        } message: { message in
            Text(message)
        }
        .alert("Failures reprocessed", item: $reprocessSummary) { _ in
        } message: { summary in
            Text("Tried \(summary.attempted): \(summary.parsed) became transactions and \(summary.stillFailed) still failed.")
        }
        .sensoryFeedback(.success, trigger: savedCount)
    }

    private func startAdding() {
        isAdding = true
    }

    private func startEditing(_ rule: ParsingRuleListItem) {
        editing = rule
    }

    private func create(_ draft: ParsingRuleDraft) throws {
        try model.create(draft)
        savedCount += 1
    }

    private func update(_ draft: ParsingRuleDraft) throws {
        guard let editing else { return }
        try model.update(id: editing.id, with: draft)
        savedCount += 1
    }

    private func toggle(_ rule: ParsingRuleListItem) {
        run { try model.setEnabled(!rule.isEnabled, id: rule.id) }
    }

    private func delete(_ rule: ParsingRuleListItem) {
        run { try model.delete(id: rule.id) }
    }

    private func reprocessFailures() {
        isReprocessing = true
        Task {
            reprocessSummary = await model.reprocessFailures()
            isReprocessing = false
        }
    }

    /// Runs a change made from the list itself, reporting a refusal in an alert.
    private func run(_ change: () throws -> Void) {
        do {
            try change()
            savedCount += 1
        } catch {
            failureMessage = SettingsErrorMessage.message(for: error)
        }
    }
}
