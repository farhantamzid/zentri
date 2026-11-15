import Foundation
import SwiftData

/// The only writer of the person's changes to categories and their keyword rules.
///
/// Every mutation validates first and saves once; a save that fails rolls the context back, so a
/// rejected change never lingers in memory. Changes the widget snapshot can show — a category's
/// name, or which category a transaction is in — then await one ``WidgetSnapshotRefresher/refresh()``.
/// Adding or reordering categories and editing rules change nothing the snapshot holds, so they skip
/// it, as ``TransactionMutationService/alwaysCategorize(merchant:categoryID:)`` does.
///
/// The fallback category, ``CategorizationService/fallbackCategoryName``, can be reordered but never
/// renamed or deleted: categorization, the Overview, the widgets, and the Transactions filter all
/// resolve it by name, and it is where a deleted category's transactions go.
@MainActor
public final class CategoryMutationService {
    private let context: ModelContext
    private let snapshotRefresher: any WidgetSnapshotRefresher
    private let now: @Sendable () -> Date

    /// The save every write goes through, replaceable so a test can make persistence fail.
    ///
    /// Production leaves this at `ModelContext.save()`; a healthy store cannot be made to fail a save
    /// on demand, so the rollback path is only reachable through this internal seam.
    internal var saveHandler: @MainActor (ModelContext) throws -> Void = { try $0.save() }

    /// Creates the service.
    ///
    /// - Parameters:
    ///   - context: The context every write goes through.
    ///   - snapshotRefresher: The refresher awaited after a change the widgets can show.
    ///   - now: The clock that stamps `updatedAt` on transactions a delete moves.
    public init(
        context: ModelContext,
        snapshotRefresher: any WidgetSnapshotRefresher,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.context = context
        self.snapshotRefresher = snapshotRefresher
        self.now = now
    }

    // MARK: - Categories

    /// Adds a category of the person's own after every existing one.
    ///
    /// - Throws: ``CategoryMutationError`` before anything is written, or the store's error when the
    ///   save fails.
    @discardableResult
    public func create(name: String, symbolName: String, colorToken: String) async throws -> Category {
        let name = try validatedName(name, excluding: nil)
        let categories = try context.fetch(FetchDescriptor<Category>())
        let category = Category(
            name: name,
            symbolName: symbolName,
            colorToken: colorToken,
            sortOrder: (categories.map(\.sortOrder).max() ?? -1) + 1,
            isSystem: false
        )
        context.insert(category)
        try commit()
        return category
    }

    /// Renames a category. Transactions and rules follow it, because they refer to the row.
    public func rename(_ category: Category, to name: String) async throws {
        try protectFallback(category)
        category.name = try validatedName(name, excluding: category)
        try commit()
        await snapshotRefresher.refresh()
    }

    /// Stores `categories` in the given order; the first sorts first.
    public func reorder(_ categories: [Category]) async throws {
        for (index, category) in categories.enumerated() {
            category.sortOrder = index
        }
        try commit()
    }

    /// Deletes a category, moving its transactions to the fallback category.
    ///
    /// Moved transactions are marked ``CategorySource/default`` — they are in `Other` because their
    /// category disappeared, not because anyone chose it — so a later "Recategorize all" may file
    /// them again. The category's keyword rules are deleted with it: a rule must name a category, and
    /// pointing it at `Other` would silently file future merchants there.
    ///
    /// - Throws: ``CategoryMutationError/fallbackCategoryProtected`` for the fallback itself,
    ///   ``CategoryMutationError/missingFallbackCategory`` when there is nowhere to move the
    ///   transactions, or the store's error when the save fails.
    public func delete(_ category: Category) async throws {
        try protectFallback(category)
        let fallbackName = CategorizationService.fallbackCategoryName
        let fallbackDescriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.name == fallbackName })
        guard let fallback = try context.fetch(fallbackDescriptor).first else {
            throw CategoryMutationError.missingFallbackCategory
        }

        let instant = now()
        for transaction in category.transactions {
            transaction.category = fallback
            transaction.categorySource = .default
            transaction.updatedAt = instant
        }
        for rule in category.categorizationRules {
            context.delete(rule)
        }
        context.delete(category)
        try commit()
        await snapshotRefresher.refresh()
    }

    // MARK: - Keyword rules

    /// Adds a keyword rule. The keyword is stored trimmed and lowercased, as "Always categorize…"
    /// stores it; matching ignores case either way.
    @discardableResult
    public func createRule(
        keyword: String,
        category: Category,
        priority: Int,
        isEnabled: Bool
    ) async throws -> CategorizationRule {
        let keyword = try validatedKeyword(keyword, excluding: nil)
        let rule = CategorizationRule(keyword: keyword, category: category, priority: priority, isEnabled: isEnabled)
        context.insert(rule)
        try commit()
        return rule
    }

    /// Replaces every editable field of a rule.
    public func updateRule(
        _ rule: CategorizationRule,
        keyword: String,
        category: Category,
        priority: Int,
        isEnabled: Bool
    ) async throws {
        rule.keyword = try validatedKeyword(keyword, excluding: rule)
        rule.category = category
        rule.priority = priority
        rule.isEnabled = isEnabled
        try commit()
    }

    /// Turns a rule on or off without changing anything else.
    public func setRuleEnabled(_ rule: CategorizationRule, isEnabled: Bool) async throws {
        rule.isEnabled = isEnabled
        try commit()
    }

    /// Deletes a rule. Transactions it already categorized keep their category.
    public func deleteRule(_ rule: CategorizationRule) async throws {
        context.delete(rule)
        try commit()
    }

    // MARK: - Helpers

    private func commit() throws {
        do {
            try saveHandler(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    private func protectFallback(_ category: Category) throws {
        if category.name == CategorizationService.fallbackCategoryName {
            throw CategoryMutationError.fallbackCategoryProtected
        }
    }

    /// The trimmed name, after checking it is not blank and no other category already uses it.
    private func validatedName(_ name: String, excluding category: Category?) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CategoryMutationError.missingName }
        let lowercased = trimmed.lowercased()
        let others = try context.fetch(FetchDescriptor<Category>()).filter { $0.id != category?.id }
        if others.contains(where: { $0.name.lowercased() == lowercased }) {
            throw CategoryMutationError.duplicateName
        }
        return trimmed
    }

    /// The trimmed, lowercased keyword, after checking it is not blank and no other rule uses it.
    private func validatedKeyword(_ keyword: String, excluding rule: CategorizationRule?) throws -> String {
        let normalized = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { throw CategoryMutationError.missingKeyword }
        let others = try context.fetch(FetchDescriptor<CategorizationRule>()).filter { $0.id != rule?.id }
        if others.contains(where: { $0.keyword.lowercased() == normalized }) {
            throw CategoryMutationError.duplicateKeyword
        }
        return normalized
    }
}
