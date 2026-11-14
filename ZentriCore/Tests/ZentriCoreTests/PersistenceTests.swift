import Foundation
import SwiftData
import Testing
@testable import ZentriCore

// `Category` is qualified as `ZentriCore.Category` because Foundation imports the Objective-C
// runtime's `Category` typedef, which makes the bare name ambiguous outside the module.

@Test @MainActor func insertsAndFetchesAccount() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)
    let account = Account(name: "Everyday", institutionName: "Bank", sortOrder: 0, createdAt: .now)
    context.insert(account)
    try context.save()
    let fetched = try context.fetch(FetchDescriptor<Account>())
    #expect(fetched.map(\.name) == ["Everyday"])
}

@Test @MainActor func seedingIsIdempotent() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)
    try SeedData.seed(into: context)
    try SeedData.seed(into: context)
    let categories = try context.fetch(FetchDescriptor<ZentriCore.Category>())
    #expect(categories.count == 12)
    #expect(Set(categories.map(\.name)).count == 12)
}

/// `insert(into:)` exists so a caller can seed inside the same save as its own rows: it must be
/// idempotent and must leave the store untouched until the caller saves.
@Test @MainActor func insertIsIdempotentAndSavesNothing() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)
    let verification = ModelContext(container)

    try SeedData.insert(into: context)

    // The insert has not been saved, so no other context can see it.
    #expect(try verification.fetchCount(FetchDescriptor<ZentriCore.Category>()) == 0)
    #expect(try verification.fetchCount(FetchDescriptor<CategorizationRule>()) == 0)

    // A second insert finds the pending rows and adds nothing.
    try SeedData.insert(into: context)
    #expect(try context.fetchCount(FetchDescriptor<ZentriCore.Category>()) == 12)
    #expect(try context.fetchCount(FetchDescriptor<CategorizationRule>()) == 5)

    try context.save()
    #expect(try verification.fetchCount(FetchDescriptor<ZentriCore.Category>()) == 12)
    #expect(try verification.fetchCount(FetchDescriptor<CategorizationRule>()) == 5)
    #expect(try verification.fetchCount(FetchDescriptor<Account>()) == 0)
}

/// `seed(into:)` is the insert plus the save, so a fresh context sees the rows straight away.
@Test @MainActor func seedSavesWhatInsertOnlyPrepares() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)
    let verification = ModelContext(container)

    try SeedData.seed(into: context)

    #expect(try verification.fetchCount(FetchDescriptor<ZentriCore.Category>()) == 12)
    #expect(try verification.fetchCount(FetchDescriptor<CategorizationRule>()) == 5)
}

@Test @MainActor func seedingCreatesSpecifiedCategoriesAndRules() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)
    try SeedData.seed(into: context)

    let descriptor = FetchDescriptor<ZentriCore.Category>(sortBy: [SortDescriptor(\.sortOrder)])
    let categories = try context.fetch(descriptor)
    #expect(categories.map(\.name) == [
        "Groceries", "Dining", "Transport", "Shopping", "Bills & Utilities", "Health",
        "Entertainment", "Travel", "Fees & Charges", "Income", "Transfers", "Other",
    ])
    #expect(categories.map(\.symbolName) == [
        "cart", "fork.knife", "car", "bag", "bolt", "heart",
        "film", "airplane", "banknote", "arrow.up.right", "arrow.left.arrow.right", "ellipsis",
    ])
    #expect(categories.allSatisfy { $0.isSystem && !$0.colorToken.isEmpty })

    let rules = try context.fetch(FetchDescriptor<CategorizationRule>())
    #expect(Set(rules.map(\.keyword)) == ["grab", "uber", "starbucks", "netflix", "amazon"])
    #expect(rules.first { $0.keyword == "uber" }?.category.name == "Transport")
    #expect(rules.first { $0.keyword == "grab" }?.category.name == "Transport")
    #expect(rules.first { $0.keyword == "starbucks" }?.category.name == "Dining")
    #expect(rules.first { $0.keyword == "netflix" }?.category.name == "Entertainment")
    #expect(rules.first { $0.keyword == "amazon" }?.category.name == "Shopping")

    try SeedData.seed(into: context)
    #expect(try context.fetchCount(FetchDescriptor<CategorizationRule>()) == 5)
}

@Test @MainActor func deletingAccountCascadesToTransactionsCheckpointsAndRules() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)
    let account = Account(name: "Everyday", institutionName: "Bank", sortOrder: 0, createdAt: .now)
    context.insert(account)
    let rawMessage = RawMessage(
        text: "RM42 spent at Cafe", receivedAt: .now, ingestedAt: .now, status: .parsed, fingerprint: "cascade"
    )
    let transaction = Transaction(
        account: account, amount: 42, direction: .debit, occurredAt: .now,
        merchantRaw: "Cafe", merchantDisplay: "Cafe", rawMessage: rawMessage
    )
    let checkpoint = BalanceCheckpoint(
        account: account, amount: 500, recordedAt: .now, source: .opening, createdAt: .now
    )
    let rule = ParsingRule(
        account: account, name: "Debit", direction: .debit, pattern: "spent",
        priority: 0, isEnabled: true, createdAt: .now, updatedAt: .now
    )
    context.insert(rawMessage)
    context.insert(transaction)
    context.insert(checkpoint)
    context.insert(rule)
    try context.save()
    #expect(account.transactions.count == 1)
    #expect(account.checkpoints.count == 1)
    #expect(account.rules.count == 1)

    context.delete(account)
    try context.save()
    #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<BalanceCheckpoint>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<ParsingRule>()) == 0)
    // Raw messages are the parse archive: they outlive the transactions they produced.
    #expect(try context.fetchCount(FetchDescriptor<RawMessage>()) == 1)
    #expect(rawMessage.transaction == nil)
}

@Test @MainActor func rawMessageLinksToItsTransaction() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)
    let account = Account(name: "Everyday", institutionName: "Bank", sortOrder: 0, createdAt: .now)
    let rawMessage = RawMessage(
        text: "RM10 spent at Cafe", sender: "Bank", receivedAt: .now, ingestedAt: .now,
        status: .parsed, fingerprint: "abc123"
    )
    let transaction = Transaction(
        account: account, amount: 10, direction: .debit, occurredAt: .now,
        merchantRaw: "Cafe", merchantDisplay: "Cafe", rawMessage: rawMessage
    )
    context.insert(account)
    context.insert(rawMessage)
    context.insert(transaction)
    try context.save()

    #expect(rawMessage.transaction?.id == transaction.id)
    #expect(transaction.rawMessage?.id == rawMessage.id)
}

@Test @MainActor func categoryDeletionCascadesRulesAndClearsTransactions() throws {
    let container = try ZentriContainer.make(inMemory: true)
    let context = ModelContext(container)
    try SeedData.seed(into: context)
    let categories = try context.fetch(FetchDescriptor<ZentriCore.Category>())
    let transport = try #require(categories.first { $0.name == "Transport" })
    #expect(transport.categorizationRules.count == 2)

    let account = Account(name: "Everyday", institutionName: "Bank", sortOrder: 0, createdAt: .now)
    context.insert(account)
    let transaction = Transaction(
        account: account, amount: 15, direction: .debit, occurredAt: .now,
        merchantRaw: "Grab", merchantDisplay: "Grab", category: transport
    )
    context.insert(transaction)
    try context.save()
    #expect(transport.transactions.count == 1)

    context.delete(transport)
    try context.save()
    #expect(try context.fetchCount(FetchDescriptor<CategorizationRule>()) == 3)
    #expect(try context.fetchCount(FetchDescriptor<Transaction>()) == 1)
    #expect(transaction.category == nil)
}

@Test @MainActor func onDiskStoreReopensWithItsSavedAccount() throws {
    // A real SQLite store, not the in-memory configuration every other test uses: the store must
    // survive the container that wrote it and read back through a second container at the same
    // URL, which is what proves the versioned schema and migration plan can back a real file.
    let directory = FileManager.default.temporaryDirectory
        .appending(path: "zentri-store-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let storeURL = directory.appending(path: "Zentri.store")
    let schema = Schema(versionedSchema: ZentriSchemaV1.self)

    do {
        let configuration = ModelConfiguration(
            "ZentriOnDisk",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: schema,
            migrationPlan: ZentriMigrationPlan.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        context.insert(Account(name: "Everyday", institutionName: "Bank", sortOrder: 0, createdAt: .now))
        try context.save()
    }

    #expect(FileManager.default.fileExists(atPath: storeURL.path(percentEncoded: false)))

    let configuration = ModelConfiguration(
        "ZentriOnDisk",
        schema: schema,
        url: storeURL,
        cloudKitDatabase: .none
    )
    let reopened = try ModelContainer(
        for: schema,
        migrationPlan: ZentriMigrationPlan.self,
        configurations: configuration
    )
    let context = ModelContext(reopened)
    let accounts = try context.fetch(FetchDescriptor<Account>())
    #expect(accounts.map(\.name) == ["Everyday"])
    #expect(accounts.first?.institutionName == "Bank")
}
