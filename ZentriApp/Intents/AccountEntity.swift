import AppIntents
import Foundation
import ZentriCore

/// An account the Shortcuts capture action can file messages under.
///
/// Only the id and the display name cross into Shortcuts; balances never leave the app.
struct AccountEntity: AppEntity, Identifiable, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Account", comment: "The Shortcuts name for a Zentri bank account.")
    )
    static let defaultQuery = AccountEntityQuery()

    let id: UUID
    let name: String

    /// The account's own name, shown as typed. It is built from a runtime value rather than a
    /// literal, so the string catalog never gains a bare `%@` key for it.
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(String.LocalizationValue(name)))
    }

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    init(account: Account) {
        self.init(id: account.id, name: account.name)
    }
}
