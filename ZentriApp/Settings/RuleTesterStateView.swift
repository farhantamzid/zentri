import SwiftUI

/// Chooses what the tester shows: nothing yet, the failure, or the form.
struct RuleTesterStateView: View {
    let model: RuleTesterModel

    var body: some View {
        switch model.loadState {
        case .loading:
            Color.clear
        case .failed:
            SettingsFailureState(title: "Can't load your rules", onRetry: model.refresh)
        case .loaded:
            RuleTesterForm(model: model)
        }
    }
}
