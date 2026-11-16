import SwiftUI
import ZentriCore

/// The first account: its name, an optional institution, and the balance it starts at.
///
/// Continue stays disabled until the name has content and the balance parses to zero or more, so a
/// half-filled account is never committed.
struct AccountStepView: View {
    @Bindable var model: OnboardingModel

    @FocusState private var focusedField: Field?

    /// The fields the keyboard controls address.
    private enum Field: Hashable {
        case name
        case institution
        case balance
    }

    var body: some View {
        OnboardingStepLayout(
            "Add your first account",
            message: "Zentri tracks this account from here. The opening balance is what it holds today, before any new messages arrive."
        ) {
            SectionCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Account name")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryInk)
                            // The field below carries the same title, so VoiceOver reads it once.
                            .accessibilityHidden(true)
                        TextField("Account name", text: $model.accountName, prompt: Text("Everyday"))
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .onSubmit(dismissKeyboard)
                            .focused($focusedField, equals: .name)
                            .accessibilityIdentifier("onboarding.account.name")
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Institution")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryInk)
                            // The field below carries the same title, so VoiceOver reads it once.
                            .accessibilityHidden(true)
                        TextField("Institution", text: $model.institutionName, prompt: Text("Optional"))
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .onSubmit(dismissKeyboard)
                            .focused($focusedField, equals: .institution)
                            .accessibilityIdentifier("onboarding.account.institution")
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Opening balance")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryInk)
                            // The field below carries the same title, so VoiceOver reads it once.
                            .accessibilityHidden(true)
                        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                            Text(CurrencyCatalog.symbol(for: model.currencyCode))
                                .foregroundStyle(Theme.secondaryInk)
                                .accessibilityHidden(true)
                            TextField("Opening balance", text: $model.openingBalanceText, prompt: Text("0.00"))
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .balance)
                                .accessibilityIdentifier("onboarding.account.balance")
                            // The decimal pad has no return key, so it gets an explicit way out that
                            // sits beside the amount and stays on screen above the keyboard. The
                            // other fields dismiss with the keyboard's Done key.
                            if focusedField == .balance {
                                Button("Done", action: dismissKeyboard)
                                    .buttonStyle(.bordered)
                                    .frame(minHeight: Theme.Layout.minimumTapTarget)
                                    .accessibilityIdentifier("onboarding.keyboard.done")
                            }
                        }
                    }

                    if !model.openingBalanceText.isEmpty && !model.isOpeningBalanceValid {
                        Text("Enter a balance of 0 or more.")
                            .font(.footnote)
                            .foregroundStyle(Theme.spending)
                    } else {
                        Text("Use 0 if you are not sure.")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryInk)
                    }
                }
            }

            SectionCard("Preview") {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    MoneyText(model.openingBalance ?? 0)
                        .font(.title2.bold())
                        .foregroundStyle(Theme.ink)
                    Text("This is the balance the account starts at.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
        }
    }

    /// Leaves the field, which closes the keyboard.
    private func dismissKeyboard() {
        focusedField = nil
    }
}

#Preview {
    ScrollView {
        AccountStepView(model: OnboardingModel())
    }
    .ambientBackground()
}
