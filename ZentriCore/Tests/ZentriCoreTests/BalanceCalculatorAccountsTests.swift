import Foundation
import SwiftData
import Testing
@testable import ZentriCore

@MainActor
@Suite("BalanceCalculator over stored accounts")
struct BalanceCalculatorAccountsTests {
    @Test("Each account anchors on its newest checkpoint and adds only what was recorded after it")
    func combinedOverStoredAccounts() throws {
        let container = try ZentriContainer.make(inMemory: true)
        let context = container.mainContext
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let everyday = Account(name: "Everyday", sortOrder: 0, createdAt: start)
        let savings = Account(name: "Savings", sortOrder: 1, createdAt: start)
        let unanchored = Account(name: "New", sortOrder: 2, createdAt: start)
        [everyday, savings, unanchored].forEach { context.insert($0) }
        context.insert(BalanceCheckpoint(account: everyday, amount: 1_000, recordedAt: start, source: .opening, createdAt: start))
        context.insert(BalanceCheckpoint(
            account: everyday, amount: 900, recordedAt: start.addingTimeInterval(100), source: .sms, createdAt: start
        ))
        context.insert(BalanceCheckpoint(account: savings, amount: 500, recordedAt: start, source: .opening, createdAt: start))

        func add(_ account: Account, _ amount: Decimal, _ direction: Direction, at offset: TimeInterval) {
            let instant = start.addingTimeInterval(offset)
            context.insert(Transaction(
                account: account, amount: amount, direction: direction, occurredAt: instant,
                recordedAt: instant, merchantRaw: "M", merchantDisplay: "M"
            ))
        }
        add(everyday, 50, .debit, at: 50)     // before the newest checkpoint: already in its 900
        add(everyday, 30, .debit, at: 200)
        add(everyday, 10, .credit, at: 300)
        add(savings, 20, .debit, at: 10)
        add(unanchored, 99, .credit, at: 10)  // no checkpoint: the account counts as zero
        try context.save()

        // Everyday 900 − 30 + 10; Savings 500 − 20; New 0.
        #expect(BalanceCalculator.combined(accounts: [everyday, savings, unanchored]) == 1_360)
        #expect(BalanceCalculator.combined(accounts: [savings]) == 480)
        #expect(BalanceCalculator.combined(accounts: []) == 0)
    }
}
