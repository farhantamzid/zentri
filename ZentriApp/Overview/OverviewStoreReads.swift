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
    /// Every raw message.
    var messages: @MainActor () throws -> [RawMessage]
    /// Every category, which is how the live `Other` fallback is resolved.
    var categories: @MainActor () throws -> [ZentriCore.Category]

    /// Creates reads from supplied closures.
    init(
        accounts: @escaping @MainActor () throws -> [Account],
        messages: @escaping @MainActor () throws -> [RawMessage],
        categories: @escaping @MainActor () throws -> [ZentriCore.Category]
    ) {
        self.accounts = accounts
        self.messages = messages
        self.categories = categories
    }

    /// Reads every row of each kind from the supplied context.
    ///
    /// Main-actor isolated because a `ModelContext` may only be captured where it is used.
    @MainActor
    init(context: ModelContext) {
        self.init(
            accounts: { try context.fetch(FetchDescriptor<Account>()) },
            messages: { try context.fetch(FetchDescriptor<RawMessage>()) },
            categories: { try context.fetch(FetchDescriptor<ZentriCore.Category>()) }
        )
    }
}
