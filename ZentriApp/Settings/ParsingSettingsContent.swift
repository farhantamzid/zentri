import SwiftUI
import ZentriCore

/// The engine picker with the model's status, and links to the rules, the tester, and the inbox.
struct ParsingSettingsContent: View {
    @State private var model: ParsingSettingsModel
    private let dataRevision: Int

    init(model: ParsingSettingsModel, dataRevision: Int) {
        _model = State(initialValue: model)
        self.dataRevision = dataRevision
    }

    var body: some View {
        Form {
            Section {
                Picker("Engine", selection: $model.parserMode) {
                    ForEach(ParserMode.allCases, id: \.self) { mode in
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(mode.displayName)
                                .foregroundStyle(Theme.ink)
                            Text(mode.detail)
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryInk)
                        }
                        .tag(mode)
                        .accessibilityIdentifier("parsing.engine.\(mode.rawValue)")
                    }
                }
                .pickerStyle(.inline)

                ParserAvailabilityView(availability: model.availability)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } header: {
                Text("Engine")
            } footer: {
                Text("The engine reads new messages and reprocessed ones. Hybrid falls back to your rules when Apple Intelligence is unavailable.")
            }

            ParsingSettingsLinks(model: model)
        }
        .scrollContentBackground(.hidden)
        .onAppear(perform: model.refresh)
        .onChange(of: dataRevision) {
            model.refresh()
        }
        .task {
            await model.checkAvailability()
        }
        .alert("Couldn't change the engine", item: $model.failureMessage) { _ in
        } message: { message in
            Text(message)
        }
        .sensoryFeedback(.success, trigger: model.savedCount)
    }
}
