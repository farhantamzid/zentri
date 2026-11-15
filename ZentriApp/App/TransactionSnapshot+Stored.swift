import ZentriCore

extension TransactionSnapshot {
    /// The insights projection of a stored transaction, with its category styling resolved.
    ///
    /// A transaction without a category takes the live `Other` category when the store has one, so
    /// uncategorized spend still appears in the totals with the app's current styling for it; without
    /// one it keeps `TransactionSnapshot`'s defaults. The Overview and Insights both map rows this
    /// way, so their totals can never disagree.
    init(stored transaction: ZentriCore.Transaction, fallback: ZentriCore.Category?) {
        guard let category = transaction.category ?? fallback else {
            self.init(
                id: transaction.id,
                accountID: transaction.account.id,
                amount: transaction.amount,
                direction: transaction.direction,
                occurredAt: transaction.occurredAt,
                merchant: transaction.merchantDisplay,
                isTransfer: transaction.isTransfer
            )
            return
        }
        self.init(
            id: transaction.id,
            accountID: transaction.account.id,
            amount: transaction.amount,
            direction: transaction.direction,
            occurredAt: transaction.occurredAt,
            merchant: transaction.merchantDisplay,
            categoryID: category.id,
            categoryName: category.name,
            symbolName: category.symbolName,
            colorToken: category.colorToken,
            isTransfer: transaction.isTransfer
        )
    }
}
