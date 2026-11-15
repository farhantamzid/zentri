import Foundation
import SwiftData
import ZentriCore

/// The extra history a Transactions UI test needs on top of ``DashboardFixture``.
///
/// It is a separate switch so the Overview's fixture numbers stay exactly as its tests assert them.
/// The one row is a Grab ride from yesterday, linked to the bank message it was parsed from, so the
/// list has a second day and the detail has a raw SMS to show. It is dated before the dashboard's
/// opening checkpoint, so the combined balance is the dashboard's balance.
enum TransactionsFixture {
    /// The ride's amount.
    static let amount = Decimal(120)
    /// The ride's merchant.
    static let merchant = "Grab"
    /// The bank message the ride came from.
    static let message = "Card payment of USD 120.00 at GRAB*TRIP on your Everyday account."

    /// Inserts the ride and its message into the dashboard fixture's account and saves.
    ///
    /// - Throws: When the dashboard fixture has not been seeded first, or the save fails.
    @MainActor
    static func seed(into context: ModelContext) throws {
        guard let account = try context.fetch(FetchDescriptor<Account>()).first else {
            throw CocoaError(.coderValueNotFound)
        }
        let transport = try context.fetch(FetchDescriptor<ZentriCore.Category>()).first { $0.name == "Transport" }
        let occurredAt = Date.now.addingTimeInterval(-86_400)

        let rawMessage = RawMessage(
            text: message,
            sender: "BANK",
            receivedAt: occurredAt,
            ingestedAt: occurredAt,
            status: .parsed,
            engine: .rules,
            fingerprint: "ui-test-grab-message"
        )
        context.insert(rawMessage)
        context.insert(
            ZentriCore.Transaction(
                account: account,
                amount: amount,
                direction: .debit,
                occurredAt: occurredAt,
                recordedAt: occurredAt,
                merchantRaw: "GRAB*TRIP",
                merchantDisplay: merchant,
                category: transport,
                categorySource: .rule,
                rawMessage: rawMessage,
                parseEngine: .rules
            )
        )
        try context.save()
    }
}
