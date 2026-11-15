import SwiftUI

/// The account detail's form and the sheets it opens.
struct AccountDetailForm: View {
    let model: AccountsModel
    let account: AccountListItem

    @State private var isSettingBalance = false
    @State private var isEditing = false
    @State private var isChangingArchive = false
    @State private var changeCount = 0
    @State private var failureMessage: LocalizedStringResource?

    var body: some View {
        Form {
            Section {
                LabeledContent("Balance") {
                    MoneyText(account.balance)
                        .foregroundStyle(Theme.ink)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("accounts.detail.balance")

                if let asOf = account.asOf {
                    LabeledContent("Recorded") {
                        Text(asOf, format: .dateTime.day().month().year().hour().minute())
                    }
                }

                LabeledContent("Institution") {
                    Text(account.institutionName ?? String(localized: "None"))
                }

                LabeledContent("Status") {
                    Text(account.isArchived ? "Archived" : "Active")
                }
            } footer: {
                Text("The balance is the last recorded balance plus every transaction since.")
            }

            Section {
                Button("Set Balance", systemImage: "equal.circle", action: startSettingBalance)
                    .accessibilityIdentifier("accounts.detail.setBalance")
                Button("Edit Name and Institution", systemImage: "pencil", action: startEditing)
                    .accessibilityIdentifier("accounts.detail.edit")
            }

            Section {
                NavigationLink(value: ParsingRoute.rules(accountID: account.id)) {
                    Label("Parsing Rules", systemImage: "list.bullet.rectangle")
                }
                .accessibilityIdentifier("accounts.detail.rules")
            } footer: {
                Text("The patterns that read this account's bank messages.")
            }

            Section {
                Button(
                    account.isArchived ? "Unarchive Account" : "Archive Account",
                    systemImage: account.isArchived ? "tray.and.arrow.up" : "archivebox",
                    action: toggleArchive
                )
                .disabled(isChangingArchive)
                .accessibilityIdentifier("accounts.detail.archive")
            } footer: {
                Text(
                    account.isArchived
                        ? "Unarchiving adds this account back into the Overview balance."
                        : "Archiving removes this account from the Overview balance and the pickers. Its transactions stay in your history."
                )
            }
        }
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $isSettingBalance) {
            SetBalanceView(account: account, onSave: setBalance)
        }
        .sheet(isPresented: $isEditing) {
            AccountEditorView(account: account, onSave: rename)
        }
        .alert("Couldn't update the account", item: $failureMessage) { _ in
        } message: { message in
            Text(message)
        }
        .sensoryFeedback(.success, trigger: changeCount)
    }

    private func startSettingBalance() {
        isSettingBalance = true
    }

    private func startEditing() {
        isEditing = true
    }

    private func toggleArchive() {
        isChangingArchive = true
        let archive = !account.isArchived
        let id = account.id
        Task {
            do {
                try await model.setArchived(archive, id: id)
                changeCount += 1
            } catch {
                failureMessage = SettingsErrorMessage.message(for: error)
            }
            isChangingArchive = false
        }
    }

    private func setBalance(amount: Decimal, date: Date) async throws {
        try await model.setBalance(id: account.id, amount: amount, at: date)
        changeCount += 1
    }

    private func rename(name: String, institutionName: String, openingBalance: Decimal?) async throws {
        try await model.rename(id: account.id, name: name, institutionName: institutionName)
        changeCount += 1
    }
}
