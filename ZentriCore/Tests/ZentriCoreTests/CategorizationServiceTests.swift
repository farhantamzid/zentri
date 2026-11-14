import Foundation
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
