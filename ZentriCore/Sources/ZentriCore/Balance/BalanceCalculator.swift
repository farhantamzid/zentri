import Foundation

/// Computes account balances from the latest checkpoint plus the transactions recorded after it.
public enum BalanceCalculator {
    /// The balance of one account.
    ///
    /// The latest checkpoint anchors the balance; every transaction recorded after it is applied
    /// with its sign. Accounts without a checkpoint have a zero balance.
    public static func balance(
        accountID: UUID,
        checkpoints: [CheckpointValue],
        transactions: [TransactionValue]
    ) -> Decimal {
        guard let latest = latestCheckpoint(accountID: accountID, in: checkpoints) else { return 0 }
        return transactions.reduce(latest.amount) { balance, transaction in
            guard transaction.accountID == accountID, transaction.recordedAt > latest.recordedAt else {
                return balance
            }
            return balance + transaction.signedAmount
        }
    }

    /// The sum of the balances of the supplied accounts, such as the active accounts in the combined view.
    public static func combined(
        accountIDs: some Sequence<UUID>,
        checkpoints: [CheckpointValue],
        transactions: [TransactionValue]
    ) -> Decimal {
        accountIDs.reduce(Decimal.zero) { total, accountID in
            total + balance(accountID: accountID, checkpoints: checkpoints, transactions: transactions)
        }
    }

    /// The newest checkpoint for an account, preferring the later `recordedAt` and then the later `createdAt`.
    private static func latestCheckpoint(
        accountID: UUID,
        in checkpoints: [CheckpointValue]
    ) -> CheckpointValue? {
        checkpoints
            .filter { $0.accountID == accountID }
            .max { lhs, rhs in
                (lhs.recordedAt, lhs.createdAt) < (rhs.recordedAt, rhs.createdAt)
            }
    }
}
