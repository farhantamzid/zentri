import SwiftUI

/// One account in the list: its name and institution, and its balance.
///
/// VoiceOver hears the row as one element. The layout stacks at accessibility text sizes so the
/// balance never has to share a line with a long account name.
struct AccountRow: View {
    let account: AccountListItem

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Theme.Spacing.md))
        layout {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(account.name)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                if let institutionName = account.institutionName {
                    Text(institutionName)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
            Spacer(minLength: 0)
            MoneyText(account.balance)
                .font(.body)
                .foregroundStyle(Theme.ink)
        }
        .frame(minHeight: Theme.Layout.minimumTapTarget)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("accounts.row")
    }
}

#Preview {
    List {
        AccountRow(
            account: AccountListItem(
                id: UUID(),
                name: "Everyday",
                institutionName: "City Bank",
                balance: 1_004_750,
                asOf: .now,
                isArchived: false
            )
        )
    }
}
