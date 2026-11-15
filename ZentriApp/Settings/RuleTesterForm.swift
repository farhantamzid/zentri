import SwiftUI
import ZentriCore

/// The sample, the options, and the answers of the last run.
struct RuleTesterForm: View {
    @Bindable var model: RuleTesterModel

    var body: some View {
        Form {
            Section {
                TextField("Message", text: $model.text, prompt: Text("Paste a bank message"), axis: .vertical)
                    .lineLimit(3...)
                    .accessibilityIdentifier("tester.text")

                Picker("Account", selection: $model.accountID) {
                    Text("All accounts")
                        .tag(UUID?.none)
                    ForEach(model.accounts) { account in
                        Text(account.name)
                            .tag(Optional(account.id))
                    }
                }

                Toggle("Compare with AI", isOn: $model.comparesWithModel)
                    .accessibilityIdentifier("tester.compare")

                Button(action: model.startRun) {
                    Label("Test Message", systemImage: "play.fill")
                        .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget)
                        .contentShape(.rect)
                }
                .disabled(!model.canRun || model.state == .running)
                .accessibilityIdentifier("tester.run")
            } footer: {
                Text("Testing never saves anything. Compare with AI also asks Apple Intelligence, which can take several seconds; a slow answer is stopped after about 15 seconds.")
            }

            switch model.state {
            case .idle:
                EmptyView()
            case .running:
                Section {
                    ProgressView("Testing…")
                        .frame(maxWidth: .infinity)
                }
            case .finished(let comparison):
                if let result = comparison.ruleResult {
                    RuleTesterRulesSection(
                        result: result,
                        milliseconds: comparison.ruleMilliseconds,
                        matchingRuleIDs: comparison.matchingRuleIDs,
                        model: model
                    )
                }
                if let result = comparison.modelResult {
                    RuleTesterModelSection(
                        result: result,
                        milliseconds: comparison.modelMilliseconds,
                        isAvailable: comparison.modelAvailable ?? false
                    )
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}
