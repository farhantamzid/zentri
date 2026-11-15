import Foundation

extension BalanceCalculator {
    /// The combined balance of stored accounts: each account's newest checkpoint plus the
    /// transactions recorded after it.
    ///
    /// This is the one mapping from SwiftData rows to balance values that every screen showing a
    /// balance uses, so the Overview hero and the Transactions balance can never disagree. The caller
    /// chooses which accounts count, for example only the active ones.
    @MainActor
    public static func combined(accounts: [Account]) -> Decimal {
        combined(
            accountIDs: accounts.map(\.id),
            checkpoints: accounts.flatMap(\.checkpoints).map {
                CheckpointValue(
                    accountID: $0.account.id,
                    amount: $0.amount,
                    recordedAt: $0.recordedAt,
                    createdAt: $0.createdAt
                )
            },
            transactions: accounts.flatMap(\.transactions).map {
                TransactionValue(
                    accountID: $0.account.id,
                    amount: $0.amount,
                    direction: $0.direction,
                    recordedAt: $0.recordedAt
                )
            }
        )
    }
}
