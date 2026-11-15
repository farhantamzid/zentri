import SwiftUI
import ZentriCore

/// The Appearance form: currency with its confirmation, grouping with its preview, and Face ID.
struct AppearanceSettingsForm: View {
    @State private var model: AppearanceSettingsModel

    init(model: AppearanceSettingsModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        Form {
            Section {
                Picker("Currency", selection: $model.currencyCode) {
                    ForEach(model.currencyCodes, id: \.self) { code in
                        CurrencyOptionLabel(code: code)
                            .tag(code)
                    }
                }
                // A menu rather than a pushed list: picking only stages the currency, so the
                // confirmation has to appear on this screen, which a pushed list would cover.
                .pickerStyle(.menu)
                .accessibilityIdentifier("appearance.currency")
                .confirmationDialog(
                    "Change the currency?",
                    item: $model.pendingCurrencyCode,
                    titleVisibility: .visible
                ) { code in
                    Button("Change to \(code)") {
                        confirmCurrencyChange(to: code)
                    }
                    Button("Cancel", role: .cancel, action: model.cancelCurrencyChange)
                } message: { _ in
                    Text("Amounts are not converted.")
                }
            } footer: {
                Text("The currency only changes the symbol in front of every amount.")
            }

            Section {
                Picker("Number grouping", selection: $model.numberGrouping) {
                    ForEach(NumberGrouping.allCases, id: \.self) { grouping in
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(grouping.title)
                                .foregroundStyle(Theme.ink)
                            Text(grouping.detail)
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryInk)
                        }
                        .tag(grouping)
                        .accessibilityIdentifier("appearance.grouping.\(grouping.rawValue)")
                    }
                }
                .pickerStyle(.inline)

                LabeledContent("Preview") {
                    MoneyText(1_000_000)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("appearance.preview")
            } header: {
                Text("Number grouping")
            }

            Section {
                Toggle("Require Face ID", isOn: $model.faceIDEnabled)
                    .disabled(model.isCheckingFaceID)
                    .frame(minHeight: Theme.Layout.minimumTapTarget)
                    .accessibilityIdentifier("appearance.faceID")
            } header: {
                Text("Security")
            } footer: {
                if let message = model.faceIDMessage {
                    Text(message)
                        .foregroundStyle(Theme.spending)
                        .accessibilityIdentifier("appearance.faceID.message")
                } else {
                    Text("Zentri asks for Face ID when it opens and covers your data in the app switcher.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .alert("Couldn't save your settings", item: $model.failureMessage) { _ in
        } message: { message in
            Text(message)
        }
        .sensoryFeedback(.success, trigger: model.savedCount)
    }

    private func confirmCurrencyChange(to code: String) {
        Task { await model.confirmCurrencyChange(to: code) }
    }
}
