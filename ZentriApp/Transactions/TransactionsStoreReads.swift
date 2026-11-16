import SwiftData
import ZentriCore

/// The store reads the Transactions list is built from.
///
/// Grouped into one value so a test can make a single read throw — a healthy `ModelContext` cannot
/// be made to fail a fetch on demand — while the model reads the real store by default.
struct TransactionsStoreReads {
    /// Every transaction.
    var transactions: @MainActor () throws -> [ZentriCore.Transaction]
    /// Every account, archived ones included.
    var accounts: @MainActor () throws -> [Account]
    /// Every category.
    var categories: @MainActor () throws -> [ZentriCore.Category]
    /// Every parsing rule, which is how a matched rule's name is shown.
    var parsingRules: @MainActor () throws -> [ParsingRule]

    init(
        transactions: @escaping @MainActor () throws -> [ZentriCore.Transaction],
        accounts: @escaping @MainActor () throws -> [Account],
        categories: @escaping @MainActor () throws -> [ZentriCore.Category],
        parsingRules: @escaping @MainActor () throws -> [ParsingRule]
    ) {
        self.transactions = transactions
        self.accounts = accounts
        self.categories = categories
        self.parsingRules = parsingRules
    }

    /// Reads every row of each kind from the supplied context.
    ///
    /// Each list row carries its message's text for search, so the messages are fetched with the
    /// transactions in one batch rather than faulted in one by one.
    @MainActor
    init(context: ModelContext) {
        self.init(
            transactions: { try context.fetch(Self.transactionsDescriptor) },
            accounts: { try context.fetch(FetchDescriptor<Account>()) },
            categories: { try context.fetch(FetchDescriptor<ZentriCore.Category>()) },
            parsingRules: { try context.fetch(FetchDescriptor<ParsingRule>()) }
        )
    }

    /// Every transaction, with its raw message prefetched.
    static var transactionsDescriptor: FetchDescriptor<ZentriCore.Transaction> {
        var descriptor = FetchDescriptor<ZentriCore.Transaction>()
        descriptor.relationshipKeyPathsForPrefetching = [\.rawMessage]
        return descriptor
    }
}
