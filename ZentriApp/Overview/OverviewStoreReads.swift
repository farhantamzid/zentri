import SwiftData
import ZentriCore

/// The store reads the dashboard's summary is built from.
///
/// They are grouped into one value so a test can replace a single read with one that throws — a
/// healthy `ModelContext` cannot be made to fail a fetch on demand — while the model keeps reading
/// the real store by default.
struct OverviewStoreReads {
    /// Every account, archived ones included.
    var accounts: @MainActor () throws -> [Account]
    /// What the health card reports about the message archive.
    var health: @MainActor () throws -> IngestionHealth
    /// Every category, which is how the live `Other` fallback is resolved.
    var categories: @MainActor () throws -> [ZentriCore.Category]

    /// Creates reads from supplied closures.
    init(
        accounts: @escaping @MainActor () throws -> [Account],
        health: @escaping @MainActor () throws -> IngestionHealth,
        categories: @escaping @MainActor () throws -> [ZentriCore.Category]
    ) {
        self.accounts = accounts
        self.health = health
        self.categories = categories
    }

    /// Reads every account and category, and the archive's health, from the supplied context.
    ///
    /// Main-actor isolated because a `ModelContext` may only be captured where it is used.
    @MainActor
    init(context: ModelContext) {
        self.init(
            accounts: { try context.fetch(FetchDescriptor<Account>()) },
            health: { try IngestionHealth(context: context) },
            categories: { try context.fetch(FetchDescriptor<ZentriCore.Category>()) }
        )
    }
}
