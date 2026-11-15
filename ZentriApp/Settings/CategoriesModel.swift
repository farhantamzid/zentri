import Foundation
import Observation
import SwiftData
import ZentriCore

/// The Categories screen's data and actions, run through ``CategoryMutationService``.
///
/// The model reads the store only in ``refresh()``. After every successful change it reads again
/// and calls `onMutation`, which the app wires to `AppState.mutate()` so the Overview, Transactions,
/// and Insights pick up the new names. A refused change is rethrown so the caller can say why.
@MainActor
@Observable
final class CategoriesModel {
    /// How far the last read got. An empty list only means "no categories" once loaded.
    private(set) var loadState = SettingsLoadState.loading
    /// Every category, in display order.
    private(set) var categories: [CategoryListItem] = []

    @ObservationIgnored private var storedCategories: [UUID: ZentriCore.Category] = [:]
    @ObservationIgnored private let fetchCategories: @MainActor () throws -> [ZentriCore.Category]
    @ObservationIgnored private let service: CategoryMutationService
    @ObservationIgnored private let onMutation: @MainActor () -> Void

    /// Creates the model over the supplied context.
    convenience init(
        context: ModelContext,
        service: CategoryMutationService,
        onMutation: @escaping @MainActor () -> Void
    ) {
        self.init(
            fetchCategories: { try context.fetch(FetchDescriptor<ZentriCore.Category>()) },
            service: service,
            onMutation: onMutation
        )
    }

    /// Creates the model over a supplied read, which is how a test makes the read throw.
    init(
        fetchCategories: @escaping @MainActor () throws -> [ZentriCore.Category],
        service: CategoryMutationService,
        onMutation: @escaping @MainActor () -> Void
    ) {
        self.fetchCategories = fetchCategories
        self.service = service
        self.onMutation = onMutation
    }

    /// Reads every category again. A read that throws becomes ``SettingsLoadState/failed`` with no
    /// rows, never an empty list.
    func refresh() {
        do {
            let stored = try fetchCategories().sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
            storedCategories = Dictionary(stored.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            categories = stored.map { category in
                CategoryListItem(
                    id: category.id,
                    name: category.name,
                    symbolName: category.symbolName,
                    colorToken: category.colorToken,
                    transactionCount: category.transactions.count,
                    isFallback: category.name == CategorizationService.fallbackCategoryName
                )
            }
            loadState = .loaded
        } catch {
            storedCategories = [:]
            categories = []
            loadState = .failed
        }
    }

    /// Adds a category after the others.
    func create(name: String, symbolName: String, colorToken: String) async throws {
        try await service.create(name: name, symbolName: symbolName, colorToken: colorToken)
        didMutate()
    }

    /// Renames a category.
    func rename(id: UUID, to name: String) async throws {
        guard let category = storedCategories[id] else { return }
        try await service.rename(category, to: name)
        didMutate()
    }

    /// Deletes a category, moving its transactions to `Other` and deleting its keyword rules.
    func delete(id: UUID) async throws {
        guard let category = storedCategories[id] else { return }
        try await service.delete(category)
        didMutate()
    }

    /// Stores a new display order.
    ///
    /// The list shows the new order at once, so a drag never snaps back while the save runs; a
    /// failed save reads the store again, which puts the old order back.
    func reorder(to orderedIDs: [UUID]) async throws {
        let byID = Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        categories = orderedIDs.compactMap { byID[$0] }
        do {
            try await service.reorder(orderedIDs.compactMap { storedCategories[$0] })
        } catch {
            refresh()
            throw error
        }
        didMutate()
    }

    private func didMutate() {
        refresh()
        onMutation()
    }
}
