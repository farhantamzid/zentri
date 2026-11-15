import Foundation
import SwiftData
import Testing
@testable import ZentriCore

/// A store holding at least one row of every model the schema declares.
@MainActor
private func makeFullStore() throws -> ModelContainer {
    let container = try ZentriContainer.make(inMemory: true)
    let context = container.mainContext
    try SeedData.seed(into: context)
    let account = Account(name: "Everyday", sortOrder: 0, createdAt: .now)
    let message = RawMessage(text: "Paid 5.00 at Cafe", receivedAt: .now, status: .parsed, fingerprint: "cafe")
    context.insert(account)
    context.insert(message)
    context.insert(BalanceCheckpoint(account: account, amount: 100, recordedAt: .now, source: .opening))
    context.insert(ParsingRule(account: account, name: "Card", direction: .debit, pattern: "(?<amount>\\d+)", priority: 0, isEnabled: true))
    context.insert(
        ZentriCore.Transaction(
            account: account,
            amount: 5,
            direction: .debit,
            occurredAt: .now,
            merchantRaw: "Cafe",
            merchantDisplay: "Cafe",
            rawMessage: message
        )
    )
    try context.save()
    return container
}

/// The number of stored rows of each model, keyed by model name.
@MainActor
private func rowCounts(in context: ModelContext) throws -> [String: Int] {
    [
        "Account": try context.fetchCount(FetchDescriptor<Account>()),
        "Transaction": try context.fetchCount(FetchDescriptor<ZentriCore.Transaction>()),
        "BalanceCheckpoint": try context.fetchCount(FetchDescriptor<BalanceCheckpoint>()),
        "RawMessage": try context.fetchCount(FetchDescriptor<RawMessage>()),
        "ParsingRule": try context.fetchCount(FetchDescriptor<ParsingRule>()),
        "Category": try context.fetchCount(FetchDescriptor<ZentriCore.Category>()),
        "CategorizationRule": try context.fetchCount(FetchDescriptor<CategorizationRule>()),
    ]
}

@MainActor
@Suite("StoreEraser")
struct StoreEraserTests {
    @Test("Erasing deletes every row of every model")
    func eraseDeletesEverything() throws {
        let container = try makeFullStore()
        let context = container.mainContext
        #expect(try rowCounts(in: context).values.allSatisfy { $0 > 0 })
        // Every model the schema declares is counted, so a model added later fails this test until
        // the eraser learns about it.
        #expect(try rowCounts(in: context).count == ZentriSchemaV1.models.count)

        try StoreEraser().eraseAll(in: context)

        #expect(try rowCounts(in: context).values.allSatisfy { $0 == 0 })
        #expect(try rowCounts(in: ModelContext(container)).values.allSatisfy { $0 == 0 })
    }

    @Test("A failed save rolls back and keeps every row")
    func failedSaveKeepsEverything() throws {
        let container = try makeFullStore()
        let context = container.mainContext
        let before = try rowCounts(in: context)
        var eraser = StoreEraser()
        eraser.saveHandler = { _ in throw CocoaError(.fileWriteUnknown) }

        #expect(throws: CocoaError.self) {
            try eraser.eraseAll(in: context)
        }

        #expect(try rowCounts(in: context) == before)
    }
}
