import Foundation
import SwiftData
import ZentriCore

/// A parsing rule and a failed message it can read, for the Parsing UI test.
///
/// The fixture lands on the dashboard fixture's only account, so a reprocess never needs an account
/// choice. The message failed before the rule existed; reprocessing it with the rule turns it into
/// a transaction. It sits behind its own launch switch so the other suites keep the dashboard's
/// single failed message.
enum ParsingFixture {
    /// The rule's name, as the rule list shows it.
    static let ruleName = "Fixture card debit"
    /// The rule's pattern: an amount after "RM" and a merchant after "at".
    static let pattern = #"RM(?<amount>[\d.,]+) spent at (?<merchant>[A-Za-z ]+?)\."#
    /// The failed message, which the rule reads as a 42.75 debit at Fixture Cafe.
    static let messageText = "MYBANK: RM42.75 spent at Fixture Cafe. Thank you."

    @MainActor
    static func seed(into context: ModelContext) throws {
        let accounts = try context.fetch(FetchDescriptor<Account>())
        guard let account = accounts.min(by: { $0.sortOrder < $1.sortOrder }) else { return }
        let now = Date.now
        context.insert(
            ParsingRule(
                account: account,
                name: ruleName,
                direction: .debit,
                pattern: pattern,
                priority: 0,
                isEnabled: true,
                createdAt: now,
                updatedAt: now
            )
        )
        context.insert(
            RawMessage(
                text: messageText,
                sender: "MYBANK",
                receivedAt: now.addingTimeInterval(-60),
                ingestedAt: now.addingTimeInterval(-60),
                status: .failed,
                errorDescription: "No rule matched the message.",
                fingerprint: "ui-test-parsing-message"
            )
        )
        try context.save()
    }
}
