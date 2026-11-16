import SwiftUI
import ZentriCore

/// The last screen of setup: what was created, and the button that enters the app.
///
/// The account, checkpoint, and settings are already saved when this appears. Tapping "Go to
/// Overview" adopts the settings in memory, which is what swaps the root from onboarding to the
/// tabs — so this screen stays visible until the user is ready to leave it.
struct SetupCompleteView: View {
    private let store: SettingsStore
    private let settings: AppSettings
    private let accountName: String
    private let openingBalance: Decimal

    @State private var finishFailed = false

    init(store: SettingsStore, settings: AppSettings, accountName: String, openingBalance: Decimal) {
        self.store = store
        self.settings = settings
        self.accountName = accountName
        self.openingBalance = openingBalance
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "checkmark.seal")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)

                Text("You're all set")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.ink)

                Text("Zentri created \(accountName) with this opening balance.")
                    .font(.body)
                    .foregroundStyle(Theme.secondaryInk)
                    .multilineTextAlignment(.center)

                SectionCard {
                    VStack(spacing: Theme.Spacing.xs) {
                        MoneyText(openingBalance)
                            .font(.largeTitle.bold())
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .accessibilityIdentifier("setupComplete.balance")
                        Text("Opening balance")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryInk)
                    }
                    .frame(maxWidth: .infinity)
                }

                Button("Go to Overview", action: enterApp)
                    .prominentButtonStyle()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, minHeight: Theme.Layout.minimumTapTarget)
                    .accessibilityIdentifier("setupComplete.continue")

                if finishFailed {
                    Text("Zentri couldn't finish setup. Try again.")
                        .font(.footnote)
                        .foregroundStyle(Theme.spending)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .ambientBackground()
    }

    /// Adopts the saved settings, which lets the root show the tabs.
    private func enterApp() {
        do {
            try store.completeOnboarding(settings)
            finishFailed = false
        } catch {
            finishFailed = true
        }
    }
}

#Preview {
    SetupCompleteView(
        store: SettingsStore(repository: InMemorySettingsRepository()),
        settings: .defaultValue,
        accountName: "Everyday",
        openingBalance: 1_000_000
    )
    .environment(\.moneyFormat, MoneyFormat(currencyCode: "BDT", grouping: .indian))
}
