import Foundation
import SwiftData
import Testing
@testable import ZentriCore

private func rule(
    _ keyword: String,
    _ categoryName: String,
    priority: Int = 0,
    isEnabled: Bool = true
) -> CategorizationRuleSpec {
    CategorizationRuleSpec(
        keyword: keyword,
        categoryName: categoryName,
        priority: priority,
        isEnabled: isEnabled
    )
}

private func category(_ name: String, symbolName: String = "circle", colorToken: String = "slate")
    -> CategorySnapshot {
    CategorySnapshot(id: UUID(), name: name, symbolName: symbolName, colorToken: colorToken)
}

@Test func keywordRuleBeatsSuggestion() {
    let match = CategorizationService.match(
        merchant: "GRAB MALAYSIA",
        rules: [CategorizationRuleSpec(keyword: "grab", categoryName: "Transport", priority: 0, isEnabled: true)],
        suggestion: "Shopping"
    )
    #expect(match == CategoryMatch(categoryName: "Transport", source: .rule))
}

@Test func aiSuggestionIsUsedWhenNoRuleMatches() {
    let match = CategorizationService.match(
        merchant: "Unknown Cafe", rules: [], suggestion: "Dining"
    )
    #expect(match == CategoryMatch(categoryName: "Dining", source: .ai))
}

@Test func keywordMatchingIsCaseInsensitive() {
    let match = CategorizationService.match(
        merchant: "Starbucks Reserve", rules: [rule("STARBUCKS", "Dining")], suggestion: nil
    )
    #expect(match == CategoryMatch(categoryName: "Dining", source: .rule))
}

@Test func lowestPriorityNumberWins() {
    let rules = [rule("coffee", "Shopping", priority: 2), rule("coffee", "Dining", priority: 1)]
    #expect(
        CategorizationService.match(merchant: "Coffee Club", rules: rules, suggestion: nil)
            == CategoryMatch(categoryName: "Dining", source: .rule)
    )
    #expect(
        CategorizationService.match(merchant: "Coffee Club", rules: Array(rules.reversed()), suggestion: nil)
            == CategoryMatch(categoryName: "Dining", source: .rule)
    )
}

@Test func equalPrioritiesPreferTheMoreSpecificKeyword() {
    let rules = [rule("grab", "Transport"), rule("grab car", "Travel")]
    #expect(
        CategorizationService.match(merchant: "GRAB CAR to KLIA", rules: rules, suggestion: nil)
            == CategoryMatch(categoryName: "Travel", source: .rule)
    )
    #expect(
        CategorizationService.match(merchant: "GRAB CAR to KLIA", rules: Array(rules.reversed()), suggestion: nil)
            == CategoryMatch(categoryName: "Travel", source: .rule)
    )
}

@Test func disabledRulesAreIgnored() {
    let rules = [rule("grab", "Transport", priority: 0, isEnabled: false)]
    let match = CategorizationService.match(merchant: "GRAB MALAYSIA", rules: rules, suggestion: nil)
    #expect(match == CategoryMatch(categoryName: "Other", source: .default))
}

@Test func unknownMerchantFallsBackToOther() {
    let match = CategorizationService.match(
        merchant: "Corner Shop", rules: [rule("grab", "Transport")], suggestion: nil
    )
    #expect(match == CategoryMatch(categoryName: "Other", source: .default))
}

@Test func unknownSuggestionFallsBackToOther() {
    let match = CategorizationService.match(merchant: "Yoga Studio", rules: [], suggestion: "Wellness")
    #expect(match == CategoryMatch(categoryName: "Other", source: .default))
}

@Test func blankSuggestionFallsBackToOther() {
    let match = CategorizationService.match(merchant: "Corner Shop", rules: [], suggestion: "   ")
    #expect(match == CategoryMatch(categoryName: "Other", source: .default))
}

@Test func suggestionMustNameACategoryTheCatalogKnows() {
    let catalog = [category("Transport", symbolName: "car", colorToken: "teal")]
    let known = CategorizationService.match(
        merchant: "MRT Station", rules: [], suggestion: " transport ", categories: catalog
    )
    #expect(known == CategoryMatch(categoryName: "Transport", source: .ai))

    let unknown = CategorizationService.match(
        merchant: "MRT Station", rules: [], suggestion: "Dining", categories: catalog
    )
    #expect(unknown == CategoryMatch(categoryName: "Other", source: .default))
}

@Test func emptyCatalogRejectsEverySuggestion() {
    let match = CategorizationService.match(
        merchant: "MRT Station", rules: [], suggestion: "Dining", categories: []
    )
    #expect(match == CategoryMatch(categoryName: "Other", source: .default))
}

@Test func rulesWithBlankKeywordsNeverMatch() {
    let match = CategorizationService.match(
        merchant: "Anything", rules: [rule("   ", "Shopping")], suggestion: nil
    )
    #expect(match == CategoryMatch(categoryName: "Other", source: .default))
}

// MARK: - Seed sync

// `Category` is qualified as `ZentriCore.Category` because Foundation imports the Objective-C
// runtime's `Category` typedef, which makes the bare name ambiguous outside the module.

@Test @MainActor func fallbackCatalogMatchesTheSeededCategoriesInDisplayOrder() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)
    try SeedData.seed(into: context)

    let descriptor = FetchDescriptor<ZentriCore.Category>(sortBy: [SortDescriptor(\.sortOrder)])
    let seeded = try context.fetch(descriptor)

    // The fallback validates suggestions against this list, so the rows a fresh store ships with and
    // the names it accepts must be the same names in the same display order.
    #expect(seeded.map(\.name) == CategorizationService.builtInCategoryNames)
    #expect(seeded.map(\.name) == SeedData.builtInCategoryNames)

    // A rename in the seed data therefore reaches the suggestion path instead of silently becoming `Other`:
    // every name the store ships with is a name the fallback accepts.
    for seededCategory in seeded {
        #expect(
            CategorizationService.match(
                merchant: "Merchant", rules: [], suggestion: seededCategory.name
            ) == CategoryMatch(categoryName: seededCategory.name, source: .ai)
        )
    }
}

@Test @MainActor func snapshotDefaultsMatchTheSeededOtherCategory() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)
    try SeedData.seed(into: context)

    let other = try #require(
        try context.fetch(FetchDescriptor<ZentriCore.Category>())
            .first { $0.name == CategorizationService.fallbackCategoryName }
    )
    let snapshot = TransactionSnapshot(
        id: UUID(),
        accountID: UUID(),
        amount: 0,
        direction: .debit,
        occurredAt: Date(timeIntervalSince1970: 0),
        merchant: "Uncategorized"
    )

    // The defaults are a deliberate hand copy so the insights layer stays free of the persistence
    // layer; this test is the mechanism that keeps the copy honest.
    #expect(snapshot.categoryName == other.name)
    #expect(snapshot.symbolName == other.symbolName)
    #expect(snapshot.colorToken == other.colorToken)
}
