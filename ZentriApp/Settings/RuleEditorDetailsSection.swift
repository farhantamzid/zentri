import SwiftUI
import ZentriCore

/// The rule's name, account, direction, priority, and switch.
struct RuleEditorDetailsSection: View {
    @Bindable var model: RuleEditorModel

    var body: some View {
        Section {
            TextField("Name", text: $model.name, prompt: Text("Debit — card ending 1234"))
                .accessibilityIdentifier("ruleEditor.name")

            Picker("Account", selection: $model.accountID) {
                ForEach(model.accounts) { account in
                    Text(account.name)
                        .tag(Optional(account.id))
                }
            }
            .accessibilityIdentifier("ruleEditor.account")

            Picker("Direction", selection: $model.direction) {
                ForEach(Direction.allCases, id: \.self) { direction in
                    Text(direction.displayName)
                        .tag(direction)
                }
            }
            .pickerStyle(.segmented)

            Stepper(value: $model.priority, in: -999...999) {
                LabeledContent("Priority") {
                    Text(model.priority, format: .number)
                        .monospacedDigit()
                }
            }

            Toggle("Enabled", isOn: $model.isEnabled)
        } footer: {
            Text("Debit rules record money leaving the account, credit rules money arriving. When several rules match, the lowest priority number runs first.")
        }
    }
}
