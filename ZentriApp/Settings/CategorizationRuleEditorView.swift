import SwiftUI

/// Adds or edits a keyword rule: keyword, category, priority, and whether it is on.
///
/// Save stays disabled until there is a keyword and a category, and the service checks again — a
/// keyword another rule already uses is refused — so a refused save keeps the sheet open.
struct CategorizationRuleEditorView: View {
    typealias Save = @MainActor (CategorizationRuleDraft) async throws -> Void

    private let isCreating: Bool
    private let categories: [TransactionCategoryOption]
    private let onSave: Save

    @State private var keyword: String
    @State private var categoryID: UUID?
    @State private var priority: Int
    @State private var isEnabled: Bool
    @State private var isSaving = false
    @State private var failureMessage: LocalizedStringResource?

    @Environment(\.dismiss) private var dismiss

    /// - Parameter rule: The rule to edit, or `nil` to add one, which starts on, at priority zero,
    ///   in the first category.
    init(rule: CategorizationRuleListItem?, categories: [TransactionCategoryOption], onSave: @escaping Save) {
        isCreating = rule == nil
        self.categories = categories
        self.onSave = onSave
        _keyword = State(initialValue: rule?.keyword ?? "")
        _categoryID = State(initialValue: rule?.categoryID ?? categories.first?.id)
        _priority = State(initialValue: rule?.priority ?? 0)
        _isEnabled = State(initialValue: rule?.isEnabled ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Keyword", text: $keyword, prompt: Text("grab"))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                        .accessibilityIdentifier("rules.editor.keyword")
                } footer: {
                    Text("Matches any merchant that contains this text, ignoring case.")
                }

                Section {
                    Picker("Category", selection: $categoryID) {
                        ForEach(categories) { category in
                            Label(category.name, systemImage: category.symbolName)
                                .tag(Optional(category.id))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    Stepper(value: $priority, in: -999...999) {
                        LabeledContent("Priority") {
                            Text(priority, format: .number)
                                .monospacedDigit()
                        }
                    }
                    Toggle("Enabled", isOn: $isEnabled)
                } footer: {
                    Text("When several rules match, the lowest priority number wins.")
                }
            }
            .navigationTitle(isCreating ? "New Rule" : "Edit Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(draft == nil || isSaving)
                        .accessibilityIdentifier("rules.editor.save")
                }
            }
            .alert("Couldn't save the rule", item: $failureMessage) { _ in
            } message: { message in
                Text(message)
            }
        }
    }

    /// The rule the form describes, or `nil` while it cannot be valid.
    private var draft: CategorizationRuleDraft? {
        guard let categoryID, !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return CategorizationRuleDraft(keyword: keyword, categoryID: categoryID, priority: priority, isEnabled: isEnabled)
    }

    private func cancel() {
        dismiss()
    }

    private func save() {
        guard let draft else { return }
        isSaving = true
        Task {
            do {
                try await onSave(draft)
                dismiss()
            } catch {
                failureMessage = SettingsErrorMessage.message(for: error)
            }
            isSaving = false
        }
    }
}
