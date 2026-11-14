import Foundation
import SwiftData

/// Creates the built-in categories and keyword rules a fresh store needs.
///
/// Seeding is idempotent and keyed by name (categories) and keyword (rules), so re-running it never
/// duplicates rows and never overwrites user edits. The seeds are also the single source of truth for
/// the built-in category names and for which category is the fallback: `CategorizationService` reads
/// them instead of keeping its own copy, so a renamed seed cannot leave the suggestion path pointing at
/// a category that no longer exists.
public enum SeedData {
    /// A category the app ships with.
    private struct CategorySeed {
        let name: String
        let symbolName: String
        let colorToken: String
    }

    /// A keyword rule the app ships with.
    private struct RuleSeed {
        let keyword: String
        let categoryName: String
    }

    /// The category that collects spend no rule or suggestion could classify.
    ///
    /// Defined once and included in `categorySeeds` by reference, so its name, symbol, color, and
    /// position in the display order cannot drift from the values the categorization fallback uses.
    private static let fallbackCategorySeed = CategorySeed(
        name: "Other",
        symbolName: "ellipsis",
        colorToken: "slate"
    )

    /// The 12 seeded categories, in display order.
    private static let categorySeeds: [CategorySeed] = [
        CategorySeed(name: "Groceries", symbolName: "cart", colorToken: "green"),
        CategorySeed(name: "Dining", symbolName: "fork.knife", colorToken: "coral"),
        CategorySeed(name: "Transport", symbolName: "car", colorToken: "teal"),
        CategorySeed(name: "Shopping", symbolName: "bag", colorToken: "violet"),
        CategorySeed(name: "Bills & Utilities", symbolName: "bolt", colorToken: "amber"),
        CategorySeed(name: "Health", symbolName: "heart", colorToken: "cyan"),
        CategorySeed(name: "Entertainment", symbolName: "film", colorToken: "indigo"),
        CategorySeed(name: "Travel", symbolName: "airplane", colorToken: "teal"),
        CategorySeed(name: "Fees & Charges", symbolName: "banknote", colorToken: "slate"),
        CategorySeed(name: "Income", symbolName: "arrow.up.right", colorToken: "green"),
        CategorySeed(name: "Transfers", symbolName: "arrow.left.arrow.right", colorToken: "indigo"),
        fallbackCategorySeed,
    ]

    /// The names of the seeded categories, in display order.
    ///
    /// The single source of truth for the built-in category names: `CategorizationService` validates AI
    /// suggestions against this list when the caller supplies no live catalog, so renaming a seed here
    /// renames the seeded row and the name a suggestion is accepted for at the same time.
    public static var builtInCategoryNames: [String] {
        categorySeeds.map(\.name)
    }

    /// The name of the seeded category that uncategorized spend falls back to.
    public static var fallbackCategoryName: String {
        fallbackCategorySeed.name
    }

    /// A small, editable set of common merchants.
    private static let ruleSeeds: [RuleSeed] = [
        RuleSeed(keyword: "grab", categoryName: "Transport"),
        RuleSeed(keyword: "uber", categoryName: "Transport"),
        RuleSeed(keyword: "starbucks", categoryName: "Dining"),
        RuleSeed(keyword: "netflix", categoryName: "Entertainment"),
        RuleSeed(keyword: "amazon", categoryName: "Shopping"),
    ]

    /// Inserts any missing seeded categories and rules, then saves the context.
    public static func seed(into context: ModelContext) throws {
        var categoriesByName = Dictionary(
            try context.fetch(FetchDescriptor<Category>()).map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for (index, seed) in categorySeeds.enumerated() where categoriesByName[seed.name] == nil {
            let category = Category(
                name: seed.name,
                symbolName: seed.symbolName,
                colorToken: seed.colorToken,
                sortOrder: index,
                isSystem: true
            )
            context.insert(category)
            categoriesByName[seed.name] = category
        }

        let existingKeywords = Set(try context.fetch(FetchDescriptor<CategorizationRule>()).map(\.keyword))
        for (index, seed) in ruleSeeds.enumerated() where !existingKeywords.contains(seed.keyword) {
            guard let category = categoriesByName[seed.categoryName] else {
                throw SeedError.missingCategory(seed.categoryName)
            }
            let rule = CategorizationRule(
                keyword: seed.keyword,
                category: category,
                priority: index,
                isEnabled: true
            )
            context.insert(rule)
        }
        try context.save()
    }
}

/// Errors thrown while seeding the store.
enum SeedError: Error {
    /// A seeded rule references a category that has no seed definition.
    case missingCategory(String)
}
