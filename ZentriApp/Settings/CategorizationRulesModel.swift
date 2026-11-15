import Foundation
import Observation
import SwiftData
import ZentriCore

/// The keyword rules screen's data and actions, run through ``CategoryMutationService``.
///
/// Rules are listed in the order categorization tries them: lowest priority number first. After
/// every successful change the model reads again and calls `onMutation`, which the app wires to
/// `AppState.mutate()`. A refused change is rethrown so the caller can say why.
@MainActor
@Observable
final class CategorizationRulesModel {
    /// How far the last read got. An empty list only means "no rules" once loaded.
    private(set) var loadState = SettingsLoadState.loading
    /// Every rule, in the order categorization tries them.
    private(set) var rules: [CategorizationRuleListItem] = []
    /// Every category a rule can file into, in display order.
    private(set) var categories: [TransactionCategoryOption] = []

    @ObservationIgnored private var storedRules: [UUID: CategorizationRule] = [:]
    @ObservationIgnored private var storedCategories: [UUID: ZentriCore.Category] = [:]
    @ObservationIgnored private let fetchRules: @MainActor () throws -> [CategorizationRule]
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
            fetchRules: { try context.fetch(FetchDescriptor<CategorizationRule>()) },
            fetchCategories: { try context.fetch(FetchDescriptor<ZentriCore.Category>()) },
            service: service,
            onMutation: onMutation
        )
    }

    /// Creates the model over supplied reads, which is how a test makes a read throw.
    init(
        fetchRules: @escaping @MainActor () throws -> [CategorizationRule],
        fetchCategories: @escaping @MainActor () throws -> [ZentriCore.Category],
        service: CategoryMutationService,
        onMutation: @escaping @MainActor () -> Void
    ) {
        self.fetchRules = fetchRules
        self.fetchCategories = fetchCategories
        self.service = service
        self.onMutation = onMutation
    }

    /// Reads the rules and categories again. A read that throws becomes
    /// ``SettingsLoadState/failed`` with no rows, never an empty list.
    func refresh() {
        do {
            let rules = try fetchRules().sorted { ($0.priority, $0.keyword) < ($1.priority, $1.keyword) }
            let categories = try fetchCategories().sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
            storedRules = Dictionary(rules.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            storedCategories = Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            self.rules = rules.map { rule in
                CategorizationRuleListItem(
                    id: rule.id,
                    keyword: rule.keyword,
                    categoryID: rule.category.id,
                    categoryName: rule.category.name,
                    symbolName: rule.category.symbolName,
                    colorToken: rule.category.colorToken,
                    priority: rule.priority,
                    isEnabled: rule.isEnabled
                )
            }
            self.categories = categories.map {
                TransactionCategoryOption(id: $0.id, name: $0.name, symbolName: $0.symbolName, colorToken: $0.colorToken)
            }
            loadState = .loaded
        } catch {
            storedRules = [:]
            storedCategories = [:]
            rules = []
            categories = []
            loadState = .failed
        }
    }

    /// Adds a rule.
    func create(_ draft: CategorizationRuleDraft) async throws {
        guard let category = storedCategories[draft.categoryID] else { throw CategorizationRulesModelError.missingCategory }
        try await service.createRule(
            keyword: draft.keyword,
            category: category,
            priority: draft.priority,
            isEnabled: draft.isEnabled
        )
        didMutate()
    }

    /// Replaces a rule's keyword, category, priority, and switch.
    func update(id: UUID, with draft: CategorizationRuleDraft) async throws {
        guard let rule = storedRules[id] else { return }
        guard let category = storedCategories[draft.categoryID] else { throw CategorizationRulesModelError.missingCategory }
        try await service.updateRule(
            rule,
            keyword: draft.keyword,
            category: category,
            priority: draft.priority,
            isEnabled: draft.isEnabled
        )
        didMutate()
    }

    /// Turns a rule on or off.
    func setEnabled(_ isEnabled: Bool, id: UUID) async throws {
        guard let rule = storedRules[id] else { return }
        try await service.setRuleEnabled(rule, isEnabled: isEnabled)
        didMutate()
    }

    /// Deletes a rule; transactions it already filed keep their category.
    func delete(id: UUID) async throws {
        guard let rule = storedRules[id] else { return }
        try await service.deleteRule(rule)
        didMutate()
    }

    private func didMutate() {
        refresh()
        onMutation()
    }
}
