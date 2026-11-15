import Foundation
import SwiftData
import Testing
@testable import ZentriCore

/// Counts snapshot refreshes so a test can prove a mutation refreshed the widgets.
private actor CountingSnapshotRefresher: WidgetSnapshotRefresher {
    private(set) var refreshCount = 0

    func refresh() async {
        refreshCount += 1
    }
}

/// The instant the tests treat as now.
private let now = Date(timeIntervalSince1970: 1_800_000_000)

/// Holds the container for as long as a test uses its context.
@MainActor
private struct Store {
    let container: ModelContainer
    let account: Account
    var context: ModelContext { container.mainContext }

    func category(named name: String) throws -> ZentriCore.Category {
        try #require(try context.fetch(FetchDescriptor<ZentriCore.Category>()).first { $0.name == name })
    }

    func categoriesInOrder() throws -> [String] {
        try context.fetch(FetchDescriptor<ZentriCore.Category>(sortBy: [SortDescriptor(\.sortOrder)])).map(\.name)
    }

    func rules() throws -> [CategorizationRule] {
        try context.fetch(FetchDescriptor<CategorizationRule>())
    }
}

/// A seeded store with one account.
@MainActor
private func makeStore() throws -> Store {
    let container = try ZentriContainer.make(inMemory: true)
    let context = container.mainContext
    try SeedData.seed(into: context)
    let account = Account(name: "Everyday", sortOrder: 0, createdAt: now)
    context.insert(account)
    try context.save()
    return Store(container: container, account: account)
}

@MainActor
private func makeService(_ store: Store, refresher: CountingSnapshotRefresher) -> CategoryMutationService {
    CategoryMutationService(context: store.context, snapshotRefresher: refresher, now: { now })
}

@MainActor
private func addTransaction(_ store: Store, merchant: String, category: ZentriCore.Category?) throws -> ZentriCore.Transaction {
    let transaction = ZentriCore.Transaction(
        account: store.account,
        amount: 12,
        direction: .debit,
        occurredAt: now.addingTimeInterval(-60),
        recordedAt: now.addingTimeInterval(-60),
        merchantRaw: merchant,
        merchantDisplay: merchant,
        category: category,
        categorySource: .manual,
        createdAt: now.addingTimeInterval(-60),
        updatedAt: now.addingTimeInterval(-60)
    )
    store.context.insert(transaction)
    try store.context.save()
    return transaction
}

/// The rules as the categorization engine sees them.
@MainActor
private func specs(_ store: Store) throws -> [CategorizationRuleSpec] {
    try store.rules().map {
        CategorizationRuleSpec(keyword: $0.keyword, categoryName: $0.category.name, priority: $0.priority, isEnabled: $0.isEnabled)
    }
}

@MainActor
@Suite("CategoryMutationService")
struct CategoryMutationServiceTests {
    // MARK: - Categories

    @Test("Creating a category appends it after the others, trimmed and not built in")
    func createAppends() async throws {
        let store = try makeStore()
        let service = makeService(store, refresher: CountingSnapshotRefresher())

        let pets = try await service.create(name: "  Pets ", symbolName: "pawprint", colorToken: "amber")

        #expect(pets.name == "Pets")
        #expect(pets.symbolName == "pawprint")
        #expect(pets.colorToken == "amber")
        #expect(pets.isSystem == false)
        #expect(try store.categoriesInOrder().last == "Pets")
        #expect(try store.categoriesInOrder().count == SeedData.builtInCategoryNames.count + 1)
    }

    @Test("A blank or duplicate name is refused before anything is written")
    func createValidates() async throws {
        let store = try makeStore()
        let service = makeService(store, refresher: CountingSnapshotRefresher())

        await #expect(throws: CategoryMutationError.missingName) {
            _ = try await service.create(name: "  ", symbolName: "tag", colorToken: "green")
        }
        // Categorization resolves categories by name, so two with the same name cannot coexist.
        await #expect(throws: CategoryMutationError.duplicateName) {
            _ = try await service.create(name: " dining ", symbolName: "tag", colorToken: "green")
        }
        #expect(try store.categoriesInOrder().count == SeedData.builtInCategoryNames.count)
    }

    @Test("Renaming updates the name and refreshes the snapshot")
    func renameUpdates() async throws {
        let store = try makeStore()
        let refresher = CountingSnapshotRefresher()
        let service = makeService(store, refresher: refresher)
        let dining = try store.category(named: "Dining")

        try await service.rename(dining, to: " Eating Out ")

        #expect(dining.name == "Eating Out")
        #expect(await refresher.refreshCount == 1)

        // Changing only the case of its own name is not a duplicate.
        try await service.rename(dining, to: "eating out")
        #expect(dining.name == "eating out")
    }

    @Test("Renaming refuses a blank or duplicate name and the fallback category")
    func renameValidates() async throws {
        let store = try makeStore()
        let refresher = CountingSnapshotRefresher()
        let service = makeService(store, refresher: refresher)
        let dining = try store.category(named: "Dining")
        let other = try store.category(named: SeedData.fallbackCategoryName)

        await #expect(throws: CategoryMutationError.missingName) {
            try await service.rename(dining, to: " ")
        }
        await #expect(throws: CategoryMutationError.duplicateName) {
            try await service.rename(dining, to: "TRANSPORT")
        }
        await #expect(throws: CategoryMutationError.fallbackCategoryProtected) {
            try await service.rename(other, to: "Misc")
        }
        #expect(dining.name == "Dining")
        #expect(other.name == SeedData.fallbackCategoryName)
        #expect(await refresher.refreshCount == 0)
    }

    @Test("Reordering stores the supplied order")
    func reorderStoresOrder() async throws {
        let store = try makeStore()
        let service = makeService(store, refresher: CountingSnapshotRefresher())
        let categories = try store.context.fetch(
            FetchDescriptor<ZentriCore.Category>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        let reordered = [categories[2]] + categories.filter { $0.id != categories[2].id }.reversed()

        try await service.reorder(reordered)

        #expect(try store.categoriesInOrder() == reordered.map(\.name))
        #expect(reordered.map(\.sortOrder) == Array(0..<reordered.count))
    }

    @Test("Deleting a category moves its transactions to Other, deletes its rules, and refreshes")
    func deleteReassignsToOther() async throws {
        let store = try makeStore()
        let refresher = CountingSnapshotRefresher()
        let service = makeService(store, refresher: refresher)
        let transport = try store.category(named: "Transport")
        let dining = try store.category(named: "Dining")
        let ride = try addTransaction(store, merchant: "Grab", category: transport)
        let lunch = try addTransaction(store, merchant: "Cafe", category: dining)
        #expect(try store.rules().contains { $0.keyword == "grab" })

        try await service.delete(transport)

        let other = try store.category(named: SeedData.fallbackCategoryName)
        #expect(ride.category?.id == other.id)
        // The person never chose Other; it is where unclassified spend falls back to.
        #expect(ride.categorySource == .default)
        #expect(ride.updatedAt == now)
        #expect(lunch.category?.id == dining.id)
        #expect(lunch.categorySource == .manual)
        #expect(try !store.categoriesInOrder().contains("Transport"))
        // A rule needs a category, so Transport's keyword rules go with it; other rules stay.
        let keywords = Set(try store.rules().map(\.keyword))
        #expect(!keywords.contains("grab"))
        #expect(!keywords.contains("uber"))
        #expect(keywords.contains("starbucks"))
        #expect(await refresher.refreshCount == 1)
    }

    @Test("The fallback category cannot be deleted")
    func deleteRefusesFallback() async throws {
        let store = try makeStore()
        let refresher = CountingSnapshotRefresher()
        let service = makeService(store, refresher: refresher)
        let other = try store.category(named: SeedData.fallbackCategoryName)

        await #expect(throws: CategoryMutationError.fallbackCategoryProtected) {
            try await service.delete(other)
        }
        #expect(try store.categoriesInOrder().contains(SeedData.fallbackCategoryName))
        #expect(await refresher.refreshCount == 0)
    }

    @Test("A delete with no fallback category to move transactions to is refused")
    func deleteNeedsFallback() async throws {
        let container = try ZentriContainer.make(inMemory: true)
        let context = container.mainContext
        let pets = ZentriCore.Category(name: "Pets", symbolName: "pawprint", colorToken: "amber", sortOrder: 0)
        context.insert(pets)
        try context.save()
        let service = CategoryMutationService(context: context, snapshotRefresher: CountingSnapshotRefresher())

        await #expect(throws: CategoryMutationError.missingFallbackCategory) {
            try await service.delete(pets)
        }
        #expect(try context.fetch(FetchDescriptor<ZentriCore.Category>()).count == 1)
    }

    @Test("A failed delete rolls back and leaves transactions where they were")
    func failedDeleteRollsBack() async throws {
        let store = try makeStore()
        let refresher = CountingSnapshotRefresher()
        let service = makeService(store, refresher: refresher)
        let transport = try store.category(named: "Transport")
        let ride = try addTransaction(store, merchant: "Grab", category: transport)
        service.saveHandler = { _ in throw CocoaError(.fileWriteUnknown) }

        await #expect(throws: CocoaError.self) {
            try await service.delete(transport)
        }

        #expect(try store.categoriesInOrder().contains("Transport"))
        #expect(ride.category?.name == "Transport")
        #expect(ride.categorySource == .manual)
        #expect(try store.rules().contains { $0.keyword == "grab" })
        #expect(await refresher.refreshCount == 0)
    }

    // MARK: - Keyword rules

    @Test("Creating a rule stores a trimmed, lowercased keyword")
    func createRule() async throws {
        let store = try makeStore()
        let service = makeService(store, refresher: CountingSnapshotRefresher())
        let groceries = try store.category(named: "Groceries")

        let rule = try await service.createRule(keyword: "  Whole Foods ", category: groceries, priority: 7, isEnabled: true)

        #expect(rule.keyword == "whole foods")
        #expect(rule.category.id == groceries.id)
        #expect(rule.priority == 7)
        #expect(rule.isEnabled)
        #expect(try store.rules().count == 6)
    }

    @Test("A blank or duplicate keyword is refused")
    func createRuleValidates() async throws {
        let store = try makeStore()
        let service = makeService(store, refresher: CountingSnapshotRefresher())
        let groceries = try store.category(named: "Groceries")

        await #expect(throws: CategoryMutationError.missingKeyword) {
            _ = try await service.createRule(keyword: " ", category: groceries, priority: 0, isEnabled: true)
        }
        await #expect(throws: CategoryMutationError.duplicateKeyword) {
            _ = try await service.createRule(keyword: "GRAB", category: groceries, priority: 0, isEnabled: true)
        }
        #expect(try store.rules().count == 5)
    }

    @Test("Keyword rules respect priority, and an update can change which one wins")
    func rulesRespectPriority() async throws {
        let store = try makeStore()
        let service = makeService(store, refresher: CountingSnapshotRefresher())
        let dining = try store.category(named: "Dining")
        let transport = try store.category(named: "Transport")
        let grab = try #require(try store.rules().first { $0.keyword == "grab" })
        try await service.updateRule(grab, keyword: "grab", category: transport, priority: 0, isEnabled: true)
        // The longer keyword would win a tie; the lower priority number wins first.
        let food = try await service.createRule(keyword: "grab food", category: dining, priority: 1, isEnabled: true)

        #expect(CategorizationService.match(merchant: "Grab Food", rules: try specs(store), suggestion: nil).categoryName == "Transport")

        try await service.updateRule(food, keyword: "grab food", category: dining, priority: -1, isEnabled: true)
        #expect(CategorizationService.match(merchant: "Grab Food", rules: try specs(store), suggestion: nil).categoryName == "Dining")

        try await service.setRuleEnabled(food, isEnabled: false)
        #expect(food.isEnabled == false)
        #expect(CategorizationService.match(merchant: "Grab Food", rules: try specs(store), suggestion: nil).categoryName == "Transport")
    }

    @Test("Updating a rule refuses another rule's keyword")
    func updateRuleValidates() async throws {
        let store = try makeStore()
        let service = makeService(store, refresher: CountingSnapshotRefresher())
        let uber = try #require(try store.rules().first { $0.keyword == "uber" })

        await #expect(throws: CategoryMutationError.duplicateKeyword) {
            try await service.updateRule(uber, keyword: "Grab", category: uber.category, priority: 0, isEnabled: true)
        }
        #expect(uber.keyword == "uber")

        // Keeping its own keyword is not a duplicate.
        try await service.updateRule(uber, keyword: "UBER", category: uber.category, priority: 9, isEnabled: false)
        #expect(uber.keyword == "uber")
        #expect(uber.priority == 9)
        #expect(uber.isEnabled == false)
    }

    @Test("Deleting a rule removes only that rule")
    func deleteRule() async throws {
        let store = try makeStore()
        let service = makeService(store, refresher: CountingSnapshotRefresher())
        let netflix = try #require(try store.rules().first { $0.keyword == "netflix" })

        try await service.deleteRule(netflix)

        let keywords = Set(try store.rules().map(\.keyword))
        #expect(keywords == ["grab", "uber", "starbucks", "amazon"])
        #expect(try store.categoriesInOrder().contains("Entertainment"))
    }
}
