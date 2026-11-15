import SwiftUI

/// Settings › Parsing › Rules, for every account or for one.
///
/// This view only supplies what the content needs from the app's shared state; everything else lives
/// in ``ParsingRulesContent``.
struct ParsingRulesView: View {
    let accountID: UUID?

    @Environment(AppState.self) private var appState

    var body: some View {
        ParsingRulesContent(
            model: ParsingRulesModel(
                accountID: accountID,
                context: appState.container.mainContext,
                service: appState.makeParsingRuleMutationService(),
                reprocessFailures: appState.reprocessFailures,
                onMutation: appState.mutate
            ),
            tester: appState.makeRuleTesterService(),
            dataRevision: appState.dataRevision
        )
        .background { Theme.canvas.ignoresSafeArea() }
        .navigationTitle("Rules")
    }
}
