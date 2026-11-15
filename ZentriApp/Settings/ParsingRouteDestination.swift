import SwiftUI

/// The screen for one ``ParsingRoute``.
struct ParsingRouteDestination: View {
    let route: ParsingRoute

    var body: some View {
        switch route {
        case .rules(let accountID):
            ParsingRulesView(accountID: accountID)
        case .tester:
            RuleTesterView()
        case .inbox:
            RawMessageInboxView()
        }
    }
}
