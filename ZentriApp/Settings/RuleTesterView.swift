import SwiftUI

/// Settings › Parsing › Rule Tester.
///
/// This view only supplies what the content needs from the app's shared state; everything else lives
/// in ``RuleTesterContent``.
struct RuleTesterView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        RuleTesterContent(
            model: RuleTesterModel(
                context: appState.container.mainContext,
                tester: appState.makeRuleTesterService()
            ),
            dataRevision: appState.dataRevision
        )
        .background { Theme.canvas.ignoresSafeArea() }
        .navigationTitle("Rule Tester")
    }
}
