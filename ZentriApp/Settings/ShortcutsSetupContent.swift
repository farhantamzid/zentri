import SwiftUI

/// The Shortcuts setup guide: the steps, the test console, how ingestion has been going, and what
/// to check when it is not.
struct ShortcutsSetupContent: View {
    @State private var model: ShortcutsSetupModel
    private let dataRevision: Int

    init(model: ShortcutsSetupModel, dataRevision: Int) {
        _model = State(initialValue: model)
        self.dataRevision = dataRevision
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("A Shortcuts automation hands each bank message to Zentri, which reads it on this iPhone. iOS doesn't let apps create automations, so you build it once in the Shortcuts app.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)

                ShortcutsStepsCard()
                ShortcutsTestConsoleCard()
                ShortcutsHealthSection(model: model)
                ShortcutsTroubleshootingCard()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
        }
        .onAppear(perform: model.refresh)
        .onChange(of: dataRevision) {
            model.refresh()
        }
    }
}

#Preview {
    NavigationStack {
        ShortcutsSetupContent(model: ShortcutsSetupModel(fetchMessages: { [] }), dataRevision: 0)
            .navigationTitle("Shortcuts")
    }
    .background(Theme.canvas)
}
