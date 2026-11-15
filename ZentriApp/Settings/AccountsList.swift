import SwiftUI

/// The active accounts, which make up the combined balance, then the archived ones.
struct AccountsList: View {
    let active: [AccountListItem]
    let archived: [AccountListItem]

    var body: some View {
        List {
            Section {
                ForEach(active) { account in
                    NavigationLink(value: AccountRoute(accountID: account.id)) {
                        AccountRow(account: account)
                    }
                }
            } footer: {
                Text("The Overview balance adds up every active account.")
            }

            if !archived.isEmpty {
                Section {
                    ForEach(archived) { account in
                        NavigationLink(value: AccountRoute(accountID: account.id)) {
                            AccountRow(account: account)
                        }
                    }
                } header: {
                    Text("Archived")
                } footer: {
                    Text("Archived accounts keep their history but leave the balance and the account pickers.")
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}
