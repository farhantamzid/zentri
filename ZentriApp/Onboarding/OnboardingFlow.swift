import SwiftUI
import ZentriCore

/// The first-run flow: welcome and privacy, currency, the first account, the parser engine, the
/// rules pointer, Shortcuts, and the optional Face ID lock, then the completion screen.
///
/// The setup is committed on the last Continue. The settings are adopted in memory only when the
/// completion screen's "Go to Overview" is tapped, so that screen stays visible until the user is
/// ready to leave it — and a failed commit leaves every step in place to try again.
struct OnboardingFlow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.locale) private var locale

    @State private var model = OnboardingModel()
    @State private var isKeyboardVisible = false

    var body: some View {
        NavigationStack {
            Group {
                if let account = model.committedAccount, let settings = model.committedSettings {
                    SetupCompleteView(
                        store: appState.settingsStore,
                        settings: settings,
                        accountName: account.name,
                        openingBalance: model.committedOpeningBalance
                    )
                } else {
                    OnboardingStepView(model: model)
                        .safeAreaInset(edge: .top, spacing: 0) {
                            OnboardingProgressBar(current: model.stepNumber, total: model.stepCount)
                        }
                        .safeAreaBar(edge: .bottom, spacing: 0) {
                            // A control bar: it reserves its height and gets the system's
                            // scroll-edge treatment over the step that scrolls beneath it.
                            OnboardingFooter(
                                canGoBack: model.canGoBack,
                                canContinue: model.canContinue,
                                errorMessage: model.commitFailed
                                    ? "Zentri couldn't finish setup. Try again."
                                    : nil,
                                onBack: model.goBack,
                                onContinue: continueTapped
                            )
                            // The keyboard covers the footer instead of pushing it up over the
                            // step's fields, so typing a value never puts a button where the next
                            // field is. The account step's Done button closes the keyboard and
                            // brings the footer back.
                            .ignoresSafeArea(.keyboard, edges: .bottom)
                            // Covered by the keyboard, the footer must not stay reachable to
                            // VoiceOver either, or a swipe lands on buttons nobody can see.
                            .accessibilityHidden(isKeyboardVisible)
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { Theme.canvas.ignoresSafeArea() }
            .toolbarVisibility(.hidden, for: .navigationBar)
        }
        .environment(\.moneyFormat, model.moneyFormat(locale: locale))
        .sensoryFeedback(.success, trigger: model.committedAccount?.id)
        .task {
            await model.checkParserAvailability()
        }
        .task {
            await trackKeyboard(on: UIResponder.keyboardWillShowNotification, visible: true)
        }
        .task {
            await trackKeyboard(on: UIResponder.keyboardWillHideNotification, visible: false)
        }
    }

    /// Follows the keyboard, which covers the footer while it is up. SwiftUI reports focus but not
    /// the keyboard itself, and the decimal pad's Done is the only way some fields close it.
    private func trackKeyboard(on name: Notification.Name, visible: Bool) async {
        for await _ in NotificationCenter.default.notifications(named: name).map({ _ in () }) {
            isKeyboardVisible = visible
        }
    }

    /// Moves to the next step, or commits the setup when the last step continues.
    private func continueTapped() {
        if model.isLastStep {
            model.commit(
                using: OnboardingCommitter(settingsRepository: appState.settingsStore.repository),
                context: appState.container.mainContext
            )
        } else {
            model.advance()
        }
    }
}
