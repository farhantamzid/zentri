import SwiftUI

/// Adds a category with a name, icon, and color, or renames an existing one.
///
/// Save stays disabled until there is a name, and the service checks again — a duplicate name is
/// refused — so a refused save keeps the sheet open with the reason.
struct CategoryEditorView: View {
    /// Saves the name, icon, and color. Renaming changes only the name.
    typealias Save = @MainActor (_ name: String, _ symbolName: String, _ colorToken: String) async throws -> Void

    private let isCreating: Bool
    private let onSave: Save

    @State private var name: String
    @State private var symbolName: String
    @State private var colorToken: String
    @State private var isSaving = false
    @State private var failureMessage: LocalizedStringResource?

    @Environment(\.dismiss) private var dismiss

    /// - Parameter category: The category to rename, or `nil` to add one.
    init(category: CategoryListItem?, onSave: @escaping Save) {
        isCreating = category == nil
        self.onSave = onSave
        _name = State(initialValue: category?.name ?? "")
        _symbolName = State(initialValue: category?.symbolName ?? CategoryStyleOptions.symbolNames[0])
        _colorToken = State(initialValue: category?.colorToken ?? CategoryStyleOptions.colorTokens[0])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("Pets"))
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("categories.editor.name")
                }

                if isCreating {
                    Section {
                        Picker("Icon", selection: $symbolName) {
                            ForEach(CategoryStyleOptions.symbolNames, id: \.self) { symbolName in
                                Image(systemName: symbolName)
                                    .foregroundStyle(Theme.categoryColor(for: colorToken))
                                    .tag(symbolName)
                            }
                        }
                        .pickerStyle(.navigationLink)

                        Picker("Color", selection: $colorToken) {
                            ForEach(CategoryStyleOptions.colorTokens, id: \.self) { token in
                                CategoryColorOption(token: token)
                                    .tag(token)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    } footer: {
                        Text("The icon goes with the name everywhere the category appears, so color is never the only cue.")
                    }
                }
            }
            .navigationTitle(isCreating ? "New Category" : "Rename Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave || isSaving)
                        .accessibilityIdentifier("categories.editor.save")
                }
            }
            .alert("Couldn't save the category", item: $failureMessage) { _ in
            } message: { message in
                Text(message)
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func cancel() {
        dismiss()
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        Task {
            do {
                try await onSave(name, symbolName, colorToken)
                dismiss()
            } catch {
                failureMessage = SettingsErrorMessage.message(for: error)
            }
            isSaving = false
        }
    }
}
