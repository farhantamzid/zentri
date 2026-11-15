import AppIntents
import Foundation
import SwiftData
import ZentriCore

/// Finds accounts for the capture action's account parameter.
///
/// Suggestions are the active accounts in picker order. Resolving a saved id also finds an archived
/// account, so a Shortcut configured before the account was archived reports it as unavailable at
/// capture time instead of quietly filing the message under another account. Both read the
/// process-wide container the app and the capture share.
struct AccountEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [AccountEntity] {
        let container = try AppComposition.sharedContainer()
        return try AccountLookup.accounts(withIDs: identifiers, in: container.mainContext)
            .map(AccountEntity.init(account:))
    }

    @MainActor
    func suggestedEntities() async throws -> [AccountEntity] {
        let container = try AppComposition.sharedContainer()
        return try AccountLookup.activeAccounts(in: container.mainContext)
            .map(AccountEntity.init(account:))
    }
}
