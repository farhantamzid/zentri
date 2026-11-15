import SwiftUI

/// Chooses the account a transaction belongs to, or says there is none to choose yet.
struct TransactionAccountPicker: View {
    @Binding var accountID: UUID?
    let accounts: [TransactionAccountOption]

    var body: some View {
        if accounts.isEmpty {
            LabeledContent("Account") {
                Text("Add an account in Settings first")
                    .foregroundStyle(Theme.secondaryInk)
            }
        } else {
            Picker("Account", selection: $accountID) {
                ForEach(accounts) { account in
                    Text(account.name).tag(Optional(account.id))
                }
            }
        }
    }
}
