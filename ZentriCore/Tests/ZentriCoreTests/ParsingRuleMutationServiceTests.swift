import Foundation
import SwiftData
import Testing
@testable import ZentriCore

private let ruleNow = Date(timeIntervalSince1970: 1_800_000_000)
private let validPattern = #"RM(?<amount>[\d.,]+) spent at (?<merchant>.+)"#

@MainActor
private struct RuleStore {
    let container: ModelContainer
    let account: Account
    var context: ModelContext { container.mainContext }

    func rules() throws -> [ParsingRule] {
        try context.fetch(FetchDescriptor<ParsingRule>())
    }
}

@MainActor
private func makeRuleStore() throws -> RuleStore {
    let container = try ZentriContainer.make(inMemory: true)
    let account = Account(name: "Everyday", sortOrder: 0, createdAt: ruleNow)
    container.mainContext.insert(account)
    try container.mainContext.save()
    return RuleStore(container: container, account: account)
}

private func draft(
    accountID: UUID,
    name: String = "Card debit",
    pattern: String = validPattern,
    dateFormat: String? = nil,
    priority: Int = 0,
    isEnabled: Bool = true
) -> ParsingRuleDraft {
    ParsingRuleDraft(
        accountID: accountID,
        name: name,
        direction: .debit,
        pattern: pattern,
        dateFormat: dateFormat,
        isCaseInsensitive: true,
        dotMatchesNewlines: false,
        priority: priority,
        isEnabled: isEnabled
    )
}

@MainActor
@Test func createStoresATrimmedRule() throws {
    let store = try makeRuleStore()
    let service = ParsingRuleMutationService(context: store.context, now: { ruleNow })

    let rule = try service.create(draft(accountID: store.account.id, name: "  Card debit  ", dateFormat: "  "))

    #expect(rule.name == "Card debit")
    #expect(rule.dateFormat == nil)
    #expect(rule.account.id == store.account.id)
    #expect(rule.createdAt == ruleNow)
    #expect(try store.rules().count == 1)
    #expect(!store.context.hasChanges)
}

@MainActor
@Test func createRefusesAPatternWithoutAnAmountGroup() throws {
    let store = try makeRuleStore()
    let service = ParsingRuleMutationService(context: store.context, now: { ruleNow })

    #expect(throws: ParsingRuleMutationError.invalidPattern(.missingAmountGroup)) {
        try service.create(draft(accountID: store.account.id, pattern: #"spent at (?<merchant>.+)"#))
    }
    #expect(try store.rules().isEmpty)
}

@MainActor
@Test func createRefusesABrokenPatternABlankNameAndAMissingAccount() throws {
    let store = try makeRuleStore()
    let service = ParsingRuleMutationService(context: store.context, now: { ruleNow })

    #expect(throws: ParsingRuleMutationError.self) {
        try service.create(draft(accountID: store.account.id, pattern: #"RM(?<amount>\d+"#))
    }
    #expect(throws: ParsingRuleMutationError.missingName) {
        try service.create(draft(accountID: store.account.id, name: "  "))
    }
    #expect(throws: ParsingRuleMutationError.missingAccount) {
        try service.create(draft(accountID: UUID()))
    }
    #expect(try store.rules().isEmpty)
}

@MainActor
@Test func updateReplacesEveryFieldAndStampsTheEdit() throws {
    let store = try makeRuleStore()
    var clock = ruleNow
    let service = ParsingRuleMutationService(context: store.context, now: { [clock] in clock })
    let rule = try service.create(draft(accountID: store.account.id))
    let other = Account(name: "Savings", sortOrder: 1, createdAt: ruleNow)
    store.context.insert(other)
    clock = ruleNow.addingTimeInterval(60)
    let later = ParsingRuleMutationService(context: store.context, now: { [clock] in clock })

    try later.update(rule, with: draft(
        accountID: other.id, name: "Savings debit", pattern: #"(?<amount>\d+)"#, dateFormat: "dd/MM/yy",
        priority: 3, isEnabled: false
    ))

    #expect(rule.account.id == other.id)
    #expect(rule.name == "Savings debit")
    #expect(rule.pattern == #"(?<amount>\d+)"#)
    #expect(rule.dateFormat == "dd/MM/yy")
    #expect(rule.priority == 3)
    #expect(!rule.isEnabled)
    #expect(rule.createdAt == ruleNow)
    #expect(rule.updatedAt == ruleNow.addingTimeInterval(60))
}

@MainActor
@Test func enablingABrokenRuleIsRefused() throws {
    let store = try makeRuleStore()
    let rule = ParsingRule(
        account: store.account, name: "Imported", direction: .debit, pattern: "RM(", priority: 0, isEnabled: false
    )
    store.context.insert(rule)
    try store.context.save()
    let service = ParsingRuleMutationService(context: store.context, now: { ruleNow })

    #expect(throws: ParsingRuleMutationError.self) { try service.setEnabled(rule, isEnabled: true) }
    #expect(!rule.isEnabled)

    // Turning a broken rule off is always allowed.
    rule.isEnabled = true
    try store.context.save()
    try service.setEnabled(rule, isEnabled: false)
    #expect(!rule.isEnabled)
}

@MainActor
@Test func deleteRemovesTheRule() throws {
    let store = try makeRuleStore()
    let service = ParsingRuleMutationService(context: store.context, now: { ruleNow })
    let rule = try service.create(draft(accountID: store.account.id))

    try service.delete(rule)

    #expect(try store.rules().isEmpty)
}

@MainActor
@Test func failedSaveRollsBack() throws {
    let store = try makeRuleStore()
    let service = ParsingRuleMutationService(context: store.context, now: { ruleNow })
    service.saveHandler = { _ in throw CocoaError(.fileWriteUnknown) }

    #expect(throws: CocoaError.self) { try service.create(draft(accountID: store.account.id)) }
    #expect(try store.rules().isEmpty)
}

@MainActor
@Test func storedRulesAreOrderedByPriorityThenCreation() throws {
    let store = try makeRuleStore()
    let early = ParsingRule(
        account: store.account, name: "Early", direction: .debit, pattern: "(?<amount>1)",
        priority: 1, isEnabled: true, createdAt: ruleNow
    )
    let late = ParsingRule(
        account: store.account, name: "Late", direction: .debit, pattern: "(?<amount>2)",
        priority: 1, isEnabled: true, createdAt: ruleNow.addingTimeInterval(10)
    )
    let first = ParsingRule(
        account: store.account, name: "First", direction: .credit, pattern: "(?<amount>3)",
        priority: 0, isEnabled: false, createdAt: ruleNow.addingTimeInterval(20)
    )
    for rule in [late, first, early] { store.context.insert(rule) }
    try store.context.save()

    let specs = try StoredParsingRules.specs(in: store.context)

    #expect(specs.map(\.id) == [first.id, early.id, late.id])
    #expect(StoredParsingRules.ordered([late, early, first]).map(\.name) == ["First", "Early", "Late"])
    #expect(specs[0].accountID == store.account.id)
    #expect(specs[0].direction == .credit)
    #expect(!specs[0].isEnabled)
}
