import SwiftData
import ZentriCore

/// The store reads the Insights screen is built from.
///
/// Grouped into one value so a test can make a single read throw — a healthy `ModelContext` cannot
/// be made to fail a fetch on demand — while the model reads the real store by default.
struct InsightsStoreReads {
    /// Every account, archived ones included; the transactions come through the active ones.
    var accounts: @MainActor () throws -> [Account]
    /// Every category, which is how the live `Other` fallback is resolved.
    var categories: @MainActor () throws -> [ZentriCore.Category]

    init(
        accounts: @escaping @MainActor () throws -> [Account],
        categories: @escaping @MainActor () throws -> [ZentriCore.Category]
    ) {
        self.accounts = accounts
        self.categories = categories
    }

    /// Reads every row of each kind from the supplied context.
    @MainActor
    init(context: ModelContext) {
        self.init(
            accounts: { try context.fetch(FetchDescriptor<Account>()) },
            categories: { try context.fetch(FetchDescriptor<ZentriCore.Category>()) }
        )
    }
}
