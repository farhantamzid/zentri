import SwiftData
import SwiftUI
import ZentriCore

/// The keyword rules, in the order categorization tries them, with add, edit, switch, and delete.
///
/// The content owns the model, so the list survives re-renders; it reads the store when it appears
/// and whenever a mutation anywhere bumps the revision.
struct CategorizationRulesContent: View {
    @State private var model: CategorizationRulesModel
    @State private var isAdding = false
    @State private var editing: CategorizationRuleListItem?
    @State private var failureMessage: LocalizedStringResource?
    @State private var savedCount = 0
    private let dataRevision: Int

    init(
        context: ModelContext,
        service: CategoryMutationService,
        dataRevision: Int,
        onMutation: @escaping @MainActor () -> Void
    ) {
        _model = State(
            initialValue: CategorizationRulesModel(context: context, service: service, onMutation: onMutation)
        )
        self.dataRevision = dataRevision
    }

    var body: some View {
        CategorizationRulesStateView(
            model: model,
            onAdd: startAdding,
            onEdit: startEditing,
            onToggle: toggle,
            onDelete: delete
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Rule", systemImage: "plus", action: startAdding)
                    .disabled(model.categories.isEmpty)
                    .accessibilityIdentifier("rules.add")
            }
        }
        .onAppear(perform: model.refresh)
        .onChange(of: dataRevision) {
            model.refresh()
        }
        .sheet(isPresented: $isAdding) {
            CategorizationRuleEditorView(rule: nil, categories: model.categories, onSave: create)
        }
        .sheet(item: $editing) { rule in
            CategorizationRuleEditorView(rule: rule, categories: model.categories, onSave: update)
        }
        .alert("Couldn't update the rule", item: $failureMessage) { _ in
        } message: { message in
            Text(message)
        }
        .sensoryFeedback(.success, trigger: savedCount)
    }

    private func startAdding() {
        isAdding = true
    }

    private func startEditing(_ rule: CategorizationRuleListItem) {
        editing = rule
    }

    private func create(_ draft: CategorizationRuleDraft) async throws {
        try await model.create(draft)
        savedCount += 1
    }

    private func update(_ draft: CategorizationRuleDraft) async throws {
        guard let editing else { return }
        try await model.update(id: editing.id, with: draft)
        savedCount += 1
    }

    private func toggle(_ rule: CategorizationRuleListItem) {
        run { try await model.setEnabled(!rule.isEnabled, id: rule.id) }
    }

    private func delete(_ rule: CategorizationRuleListItem) {
        run { try await model.delete(id: rule.id) }
    }

    /// Runs a change made from the list itself, reporting a refusal in an alert.
    private func run(_ change: @escaping @MainActor () async throws -> Void) {
        Task {
            do {
                try await change()
                savedCount += 1
            } catch {
                failureMessage = SettingsErrorMessage.message(for: error)
            }
        }
    }
}
