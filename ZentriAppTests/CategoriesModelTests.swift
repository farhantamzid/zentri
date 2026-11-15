import Foundation
import SwiftData
import Testing
import ZentriCore
@testable import ZentriApp

/// A refresher that does nothing; these tests are about the models, not the widgets.
private struct InertRefresher: WidgetSnapshotRefresher {
    func refresh() async {}
}

private enum ReadFailure: Error {
    case unreadable
}

/// Counts how often a model told the app the store changed.
@MainActor
private final class MutationCounter {
    var count = 0
    func record() { count += 1 }
}

/// A seeded store and a service over it.
@MainActor
private func makeStore() throws -> (ModelContainer, CategoryMutationService) {
    let container = try ZentriContainer.make(inMemory: true)
    try SeedData.seed(into: container.mainContext)
    return (container, CategoryMutationService(context: container.mainContext, snapshotRefresher: InertRefresher()))
}

@MainActor
@Test func categoriesModelListsCategoriesInOrderAndMarksOther() throws {
    let (container, service) = try makeStore()
    let model = CategoriesModel(context: container.mainContext, service: service, onMutation: {})

    model.refresh()

    #expect(model.loadState == .loaded)
    #expect(model.categories.map(\.name) == SeedData.builtInCategoryNames)
    #expect(model.categories.filter(\.isFallback).map(\.name) == [SeedData.fallbackCategoryName])
}

@MainActor
@Test func categoriesModelReportsAFailedRead() throws {
    let (_, service) = try makeStore()
    let model = CategoriesModel(fetchCategories: { throw ReadFailure.unreadable }, service: service, onMutation: {})

    model.refresh()

    #expect(model.loadState == .failed)
    #expect(model.categories.isEmpty)
}

@MainActor
@Test func categoriesModelAddsRenamesReordersAndDeletes() async throws {
    let (container, service) = try makeStore()
    let counter = MutationCounter()
    let model = CategoriesModel(context: container.mainContext, service: service, onMutation: counter.record)
    model.refresh()

    try await model.create(name: "Pets", symbolName: "pawprint", colorToken: "amber")
    #expect(model.categories.last?.name == "Pets")
    let pets = try #require(model.categories.last)

    try await model.rename(id: pets.id, to: "Animals")
    #expect(model.categories.last?.name == "Animals")

    let reversed = model.categories.map(\.id).reversed()
    try await model.reorder(to: Array(reversed))
    #expect(model.categories.first?.name == "Animals")

    try await model.delete(id: pets.id)
    #expect(!model.categories.contains { $0.id == pets.id })
    #expect(counter.count == 4)

    let other = try #require(model.categories.first { $0.isFallback })
    await #expect(throws: CategoryMutationError.fallbackCategoryProtected) {
        try await model.delete(id: other.id)
    }
    #expect(counter.count == 4)
}

@MainActor
@Test func rulesModelListsRulesByPriorityAndEditsThem() async throws {
    let (container, service) = try makeStore()
    let counter = MutationCounter()
    let model = CategorizationRulesModel(context: container.mainContext, service: service, onMutation: counter.record)
    model.refresh()

    #expect(model.loadState == .loaded)
    #expect(model.rules.map(\.priority) == model.rules.map(\.priority).sorted())
    #expect(model.categories.count == SeedData.builtInCategoryNames.count)
    let groceries = try #require(model.categories.first { $0.name == "Groceries" })

    try await model.create(CategorizationRuleDraft(keyword: "Market", categoryID: groceries.id, priority: -5, isEnabled: true))
    let market = try #require(model.rules.first)
    #expect(market.keyword == "market")
    #expect(market.categoryName == "Groceries")

    try await model.setEnabled(false, id: market.id)
    #expect(model.rules.first { $0.id == market.id }?.isEnabled == false)

    try await model.update(
        id: market.id,
        with: CategorizationRuleDraft(keyword: "market", categoryID: groceries.id, priority: 50, isEnabled: true)
    )
    #expect(model.rules.last?.id == market.id)

    try await model.delete(id: market.id)
    #expect(!model.rules.contains { $0.id == market.id })
    #expect(counter.count == 4)

    await #expect(throws: CategoryMutationError.duplicateKeyword) {
        try await model.create(CategorizationRuleDraft(keyword: "grab", categoryID: groceries.id, priority: 0, isEnabled: true))
    }
    await #expect(throws: CategorizationRulesModelError.missingCategory) {
        try await model.create(CategorizationRuleDraft(keyword: "new", categoryID: UUID(), priority: 0, isEnabled: true))
    }
    #expect(counter.count == 4)
}

@MainActor
@Test func rulesModelReportsAFailedRead() throws {
    let (_, service) = try makeStore()
    let model = CategorizationRulesModel(
        fetchRules: { [] },
        fetchCategories: { throw ReadFailure.unreadable },
        service: service,
        onMutation: {}
    )

    model.refresh()

    #expect(model.loadState == .failed)
    #expect(model.rules.isEmpty)
}
