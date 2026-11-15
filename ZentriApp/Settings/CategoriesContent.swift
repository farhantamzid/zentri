import SwiftData
import SwiftUI
import ZentriCore

/// The category list with add, rename, delete, and drag reordering, plus the link to keyword rules.
///
/// The content owns the model, so the list survives re-renders; it reads the store when it appears
/// and whenever a mutation anywhere bumps the revision.
struct CategoriesContent: View {
    @State private var model: CategoriesModel
    @State private var isAdding = false
    @State private var renaming: CategoryListItem?
    @State private var pendingDeletion: CategoryListItem?
    @State private var failureMessage: LocalizedStringResource?
    @State private var savedCount = 0
    @State private var deletedCount = 0
    private let dataRevision: Int

    init(
        context: ModelContext,
        service: CategoryMutationService,
        dataRevision: Int,
        onMutation: @escaping @MainActor () -> Void
    ) {
        _model = State(initialValue: CategoriesModel(context: context, service: service, onMutation: onMutation))
        self.dataRevision = dataRevision
    }

    var body: some View {
        CategoriesStateView(
            model: model,
            onRename: startRenaming,
            onDelete: confirmDeletion,
            onReorder: reorder
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Category", systemImage: "plus", action: startAdding)
                    .accessibilityIdentifier("categories.add")
            }
        }
        .onAppear(perform: model.refresh)
        .onChange(of: dataRevision) {
            model.refresh()
        }
        .sheet(isPresented: $isAdding) {
            CategoryEditorView(category: nil, onSave: create)
        }
        .sheet(item: $renaming) { category in
            CategoryEditorView(category: category, onSave: rename)
        }
        .confirmationDialog("Delete this category?", item: $pendingDeletion, titleVisibility: .visible) { category in
            Button("Delete \(category.name)", role: .destructive) {
                delete(category)
            }
        } message: { category in
            Text("^[\(category.transactionCount) transaction](inflect: true) will move to Other, and this category's keyword rules will be deleted.")
        }
        .alert("Couldn't update categories", item: $failureMessage) { _ in
        } message: { message in
            Text(message)
        }
        .sensoryFeedback(.success, trigger: savedCount)
        .sensoryFeedback(.warning, trigger: deletedCount)
    }

    private func startAdding() {
        isAdding = true
    }

    private func startRenaming(_ category: CategoryListItem) {
        renaming = category
    }

    private func confirmDeletion(_ category: CategoryListItem) {
        pendingDeletion = category
    }

    private func create(name: String, symbolName: String, colorToken: String) async throws {
        try await model.create(name: name, symbolName: symbolName, colorToken: colorToken)
        savedCount += 1
    }

    private func rename(name: String, symbolName: String, colorToken: String) async throws {
        guard let renaming else { return }
        try await model.rename(id: renaming.id, to: name)
        savedCount += 1
    }

    private func delete(_ category: CategoryListItem) {
        Task {
            do {
                try await model.delete(id: category.id)
                deletedCount += 1
            } catch {
                failureMessage = SettingsErrorMessage.message(for: error)
            }
        }
    }

    private func reorder(_ orderedIDs: [UUID]) {
        Task {
            do {
                try await model.reorder(to: orderedIDs)
            } catch {
                failureMessage = SettingsErrorMessage.message(for: error)
            }
        }
    }
}
