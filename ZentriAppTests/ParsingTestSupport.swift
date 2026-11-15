import Foundation
import SwiftData
import ZentriCore
@testable import ZentriApp

/// A refresher that does nothing; the parsing model tests are about the models, not the widgets.
struct ParsingInertRefresher: WidgetSnapshotRefresher {
    func refresh() async {}
}

enum ParsingReadFailure: Error {
    case unreadable
}

/// Counts how often a model told the app the store changed.
@MainActor
final class ParsingMutationCounter {
    var count = 0
    func record() { count += 1 }
}

/// The pattern the parsing model tests use: an amount after "RM" and a merchant after "at".
let parsingTestPattern = #"RM(?<amount>[\d.,]+) spent at (?<merchant>[A-Za-z ]+?)\."#
/// A message `parsingTestPattern` reads as a 42.75 debit at Fixture Cafe.
let parsingTestMessage = "MYBANK: RM42.75 spent at Fixture Cafe. Thank you."

/// An in-memory store with the seeded categories and one account.
@MainActor
struct ParsingTestStore {
    let container: ModelContainer
    let account: Account
    var context: ModelContext { container.mainContext }

    init(accountName: String = "Everyday") throws {
        container = try ZentriContainer.make(inMemory: true)
        try SeedData.seed(into: container.mainContext)
        account = Account(name: accountName, sortOrder: 0, createdAt: .now.addingTimeInterval(-3_600))
        container.mainContext.insert(account)
        container.mainContext.insert(BalanceCheckpoint(
            account: account,
            amount: 1_000,
            recordedAt: .now.addingTimeInterval(-3_600),
            source: .opening
        ))
        try container.mainContext.save()
    }

    @discardableResult
    func addAccount(_ name: String, sortOrder: Int) throws -> Account {
        let account = Account(name: name, sortOrder: sortOrder, createdAt: .now)
        context.insert(account)
        try context.save()
        return account
    }

    @discardableResult
    func addRule(
        _ name: String,
        account: Account? = nil,
        direction: Direction = .debit,
        pattern: String = parsingTestPattern,
        priority: Int = 0,
        createdAt: Date = .now
    ) throws -> ParsingRule {
        let rule = ParsingRule(
            account: account ?? self.account,
            name: name,
            direction: direction,
            pattern: pattern,
            priority: priority,
            isEnabled: true,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        context.insert(rule)
        try context.save()
        return rule
    }

    @discardableResult
    func addMessage(
        _ text: String = parsingTestMessage,
        status: ParseStatus,
        receivedAt: Date = .now.addingTimeInterval(-60),
        fingerprint: String = UUID().uuidString
    ) throws -> RawMessage {
        let message = RawMessage(
            text: text,
            sender: "MYBANK",
            receivedAt: receivedAt,
            ingestedAt: receivedAt,
            status: status,
            errorDescription: status == .failed ? "No rule matched the message." : nil,
            fingerprint: fingerprint
        )
        context.insert(message)
        try context.save()
        return message
    }

    func reprocessor() -> RawMessageReprocessor {
        RawMessageReprocessor(
            context: context,
            parserBuilder: ParserFactory(modelClient: UnavailableModelClient()),
            snapshotRefresher: ParsingInertRefresher()
        )
    }

    /// Reprocesses with the stored rules in rules mode, as the app does.
    func reprocess(_ message: RawMessage, accountID: UUID?) async -> IngestionOutcome {
        await reprocessor().reprocess(
            message,
            accountID: accountID,
            rules: (try? StoredParsingRules.specs(in: context)) ?? [],
            mode: .rules
        )
    }
}
