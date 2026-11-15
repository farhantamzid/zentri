import SwiftUI

/// The four-tab shell: Overview, Transactions, Insights, and Settings.
///
/// Each tab owns its `NavigationStack`, so pushing a detail in one tab never changes another. The
/// system tab bar supplies the Liquid Glass chrome; there is no custom bar and no menu.
struct RootTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.locale) private var locale

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                    NavigationStack {
                        switch tab {
                        case .overview:
                            OverviewView()
                        case .transactions:
                            TransactionsView()
                        default:
                            TabPlaceholderView(tab: tab)
                        }
                    }
                }
            }
        }
        .environment(\.moneyFormat, appState.moneyFormat(locale: locale))
        .task {
            // Covers leaving onboarding, when the root's launch task has already returned.
            await appState.retryPendingIngestion()
        }
    }
}
