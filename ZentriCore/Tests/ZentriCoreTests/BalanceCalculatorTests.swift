import Foundation
import Testing
@testable import ZentriCore

@Test func openingBalancePlusDebit() {
    let accountID = UUID()
    let t0 = Date(timeIntervalSince1970: 1_000)
    let checkpoints = [CheckpointValue(accountID: accountID, amount: 1000, recordedAt: t0, createdAt: t0)]
    let transactions = [TransactionValue(accountID: accountID, amount: 200, direction: .debit, recordedAt: t0.addingTimeInterval(10))]
    #expect(BalanceCalculator.balance(accountID: accountID, checkpoints: checkpoints, transactions: transactions) == 800)
}

@Test func smsCheckpointSupersedesPriorMath() {
    let accountID = UUID()
    let t0 = Date(timeIntervalSince1970: 1_000)
    let checkpoints = [
        CheckpointValue(accountID: accountID, amount: 1000, recordedAt: t0, createdAt: t0),
        CheckpointValue(accountID: accountID, amount: 500, recordedAt: t0.addingTimeInterval(20), createdAt: t0.addingTimeInterval(20)),
    ]
    let transactions = [
        TransactionValue(accountID: accountID, amount: 200, direction: .debit, recordedAt: t0.addingTimeInterval(10)),
        TransactionValue(accountID: accountID, amount: 50, direction: .credit, recordedAt: t0.addingTimeInterval(30)),
    ]
    #expect(BalanceCalculator.balance(accountID: accountID, checkpoints: checkpoints, transactions: transactions) == 550)
}

@Test func noCheckpointIsZeroAndTiesUseCreationOrder() {
    let accountID = UUID()
    let t0 = Date(timeIntervalSince1970: 1_000)
    #expect(BalanceCalculator.balance(accountID: accountID, checkpoints: [], transactions: []) == 0)
    let older = CheckpointValue(accountID: accountID, amount: 100, recordedAt: t0, createdAt: t0)
    let newer = CheckpointValue(accountID: accountID, amount: 300, recordedAt: t0, createdAt: t0.addingTimeInterval(1))
    #expect(BalanceCalculator.balance(accountID: accountID, checkpoints: [newer, older], transactions: []) == 300)
}

@Test func transactionAtCheckpointTimeIsExcluded() {
    let accountID = UUID()
    let t0 = Date(timeIntervalSince1970: 1_000)
    let checkpoints = [CheckpointValue(accountID: accountID, amount: 1000, recordedAt: t0, createdAt: t0)]
    let transactions = [
        TransactionValue(accountID: accountID, amount: 200, direction: .debit, recordedAt: t0),
        TransactionValue(accountID: accountID, amount: 25, direction: .credit, recordedAt: t0),
    ]
    let balance = BalanceCalculator.balance(accountID: accountID, checkpoints: checkpoints, transactions: transactions)
    #expect(balance == 1000)
}

@Test func balanceIgnoresOtherAccounts() {
    let accountID = UUID()
    let otherAccountID = UUID()
    let t0 = Date(timeIntervalSince1970: 1_000)
    let checkpoints = [
        CheckpointValue(accountID: accountID, amount: 1000, recordedAt: t0, createdAt: t0),
        CheckpointValue(
            accountID: otherAccountID, amount: 5000,
            recordedAt: t0.addingTimeInterval(30), createdAt: t0.addingTimeInterval(30)
        ),
    ]
    let transactions = [
        TransactionValue(accountID: accountID, amount: 200, direction: .debit, recordedAt: t0.addingTimeInterval(10)),
        TransactionValue(
            accountID: otherAccountID, amount: 900, direction: .credit,
            recordedAt: t0.addingTimeInterval(40)
        ),
    ]
    let accountBalance = BalanceCalculator.balance(
        accountID: accountID, checkpoints: checkpoints, transactions: transactions
    )
    let otherBalance = BalanceCalculator.balance(
        accountID: otherAccountID, checkpoints: checkpoints, transactions: transactions
    )
    #expect(accountBalance == 800)
    #expect(otherBalance == 5900)
}

@Test func combinedSumsOnlySuppliedAccounts() {
    let checkingID = UUID()
    let savingsID = UUID()
    let archivedID = UUID()
    let t0 = Date(timeIntervalSince1970: 1_000)
    let checkpoints = [
        CheckpointValue(accountID: checkingID, amount: 1000, recordedAt: t0, createdAt: t0),
        CheckpointValue(accountID: savingsID, amount: 4000, recordedAt: t0, createdAt: t0),
        CheckpointValue(accountID: archivedID, amount: 9000, recordedAt: t0, createdAt: t0),
    ]
    let transactions = [
        TransactionValue(accountID: checkingID, amount: 250, direction: .debit, recordedAt: t0.addingTimeInterval(10)),
        TransactionValue(accountID: savingsID, amount: 500, direction: .credit, recordedAt: t0.addingTimeInterval(10)),
    ]
    let combined = BalanceCalculator.combined(
        accountIDs: [checkingID, savingsID], checkpoints: checkpoints, transactions: transactions
    )
    #expect(combined == 5250)
    #expect(
        BalanceCalculator.combined(accountIDs: [UUID](), checkpoints: checkpoints, transactions: transactions) == 0
    )
}
