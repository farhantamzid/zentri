import SwiftUI
import ZentriCore

/// The tester's form: the sample, the account, the comparison switch, and the answers.
struct RuleTesterContent: View {
    @State private var model: RuleTesterModel
    private let dataRevision: Int

    init(model: RuleTesterModel, dataRevision: Int) {
        _model = State(initialValue: model)
        self.dataRevision = dataRevision
    }

    var body: some View {
        RuleTesterStateView(model: model)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear(perform: model.refresh)
            .onChange(of: dataRevision) {
                model.refresh()
            }
            .onChange(of: model.comparesWithModel) {
                rerunIfShowingResults()
            }
            .sensoryFeedback(.success, trigger: model.comparison) { _, comparison in
                if case .transaction = comparison?.ruleResult { return true }
                return false
            }
    }

    /// A switched comparison applies to the answers on screen straight away.
    private func rerunIfShowingResults() {
        guard model.comparison != nil else { return }
        model.startRun()
    }
}
