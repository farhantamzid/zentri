import Foundation
import SwiftData
import ZentriCore

/// The rows a UI test needs to see a populated Overview.
///
/// The fixture is deliberately small and readable: one account with an opening balance, one debit
/// and one credit dated today, and one failed message. The debit's merchant is a plain name so a
/// test can assert it as text, and the amounts are round so a test can compute the strings it
/// expects from the same numbers.
enum DashboardFixture {
    /// The account's opening balance.
    static let openingBalance = Decimal(1_000_000)
    /// The debit's amount, which is also today's spend.
    static let debit = Decimal(250)
    /// The credit's amount.
    static let credit = Decimal(5_000)
    /// The debit's merchant, chosen to be readable as plain text.
    static let debitMerchant = "Starbucks"
    /// The credit's merchant.
    static let creditMerchant = "Salary"

    /// Inserts the fixture rows and saves.
    ///
    /// All three rows are stamped within the same second, so "today" and "this month" cover them
    /// whenever the test runs. The checkpoint comes first because balance math only applies
    /// transactions recorded strictly after the checkpoint it anchors on — at the same instant they
    /// would be ignored and the hero would show the opening balance alone. The debit is the newest
    /// row and is categorized as Dining, so the month summary, top categories, and recent list each
    /// have a row to show, in a stable order.
    @MainActor
    static func seed(into context: ModelContext) throws {
        let now = Date.now
        let openedAt = now.addingTimeInterval(-2)
        let creditAt = now.addingTimeInterval(-1)
        let account = Account(name: "Everyday", sortOrder: 0, createdAt: openedAt)
        context.insert(account)
        context.insert(
            BalanceCheckpoint(
                account: account,
                amount: openingBalance,
                recordedAt: openedAt,
                source: .opening,
                createdAt: openedAt
            )
        )

        let categories = try context.fetch(FetchDescriptor<ZentriCore.Category>())
        let dining = categories.first { $0.name == "Dining" }
        let income = categories.first { $0.name == "Income" }

        context.insert(
            ZentriCore.Transaction(
                account: account,
                amount: debit,
                direction: .debit,
                occurredAt: now,
                recordedAt: now,
                merchantRaw: debitMerchant,
                merchantDisplay: debitMerchant,
                category: dining,
                categorySource: .rule
            )
        )
        context.insert(
            ZentriCore.Transaction(
                account: account,
                amount: credit,
                direction: .credit,
                occurredAt: creditAt,
                recordedAt: creditAt,
                merchantRaw: creditMerchant,
                merchantDisplay: creditMerchant,
                category: income,
                categorySource: .rule
            )
        )

        context.insert(
            RawMessage(
                text: "A message the parser could not read.",
                receivedAt: now,
                ingestedAt: now,
                status: .failed,
                errorDescription: "The message did not contain an amount.",
                fingerprint: "ui-test-failed-message"
            )
        )

        try context.save()
    }
}
