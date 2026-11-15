import SwiftUI

/// One account: its balance and when it was last recorded, with Set Balance, Edit, and Archive.
///
/// The detail reads the shared ``AccountsModel``, so a change made here shows at once in this
/// screen and in the list behind it.
struct AccountDetailView: View {
    let model: AccountsModel
    let accountID: UUID

    var body: some View {
        if let account = model.account(id: accountID) {
            AccountDetailForm(model: model, account: account)
                .navigationTitle(account.name)
        } else {
            ContentUnavailableView(
                "Account not found",
                systemImage: "building.columns",
                description: Text("This account is no longer in your data.")
            )
        }
    }
}
