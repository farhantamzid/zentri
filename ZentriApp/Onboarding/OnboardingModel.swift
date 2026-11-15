import Foundation
import Observation
import SwiftData
import ZentriCore

/// The state of the first-run flow: which step is showing, what has been chosen, and whether the
/// setup can be committed.
///
/// The model owns every choice the flow collects and the validation behind Continue. It never
/// writes to the store itself: the flow hands it an `OnboardingCommitter`, and the model only keeps
/// what that commit produced, so the completion screen can show it before the app moves to the tabs.
@MainActor
@Observable
final class OnboardingModel {
    /// The step currently on screen.
    private(set) var step: OnboardingStep = .welcome
    /// The display currency. Changing it never converts stored amounts.
    var currencyCode = AppSettings.defaultValue.currencyCode
    /// How amounts are grouped for display.
    var numberGrouping = AppSettings.defaultValue.numberGrouping
    /// The first account's name.
    var accountName = ""
    /// The first account's institution, optional.
    var institutionName = ""
    /// The opening balance as typed; ``openingBalance`` parses it.
    var openingBalanceText = ""
    /// The parser engine new messages use.
    var parserMode = AppSettings.defaultValue.parserMode
    /// Whether the app should require Face ID. Off by default.
    var faceIDEnabled = false
    /// The on-device model's availability, once the check has run.
    private(set) var availability: ModelAvailability?
    /// The account the commit created, once setup has been saved.
    private(set) var committedAccount: Account?
    /// The settings the commit saved, once setup has been saved.
    private(set) var committedSettings: AppSettings?
    /// The opening balance the commit saved, once setup has been saved.
    private(set) var committedOpeningBalance = Decimal.zero
    /// Whether the last commit failed, so the footer can explain the retry.
    private(set) var commitFailed = false
    /// The locale that decides the separators a typed balance is read with.
    private let locale: Locale

    /// Creates the flow's state.
    ///
    /// - Parameter locale: The locale whose separators the decimal pad offers and ``openingBalance``
    ///   accepts. The app keeps the default; a test passes one to fix the separators.
    init(locale: Locale = .current) {
        self.locale = locale
    }

    /// The supported currencies in the order the picker shows them.
    var currencyCodes: [String] { CurrencyCatalog.supportedCurrencyCodes }

    /// The steps this run visits, in order.
    ///
    /// The rules screen is part of the flow only when Rules is the chosen engine, so switching to
    /// Hybrid on the parser step shortens the path that follows.
    var steps: [OnboardingStep] {
        OnboardingStep.allCases.filter { $0 != .rules || parserMode == .rules }
    }

    /// The position of the current step in ``steps``, counting from one.
    var stepNumber: Int {
        (steps.firstIndex(of: step) ?? 0) + 1
    }

    /// The number of steps this run visits.
    var stepCount: Int { steps.count }

    /// Whether Back has somewhere to go.
    var canGoBack: Bool {
        guard let index = steps.firstIndex(of: step) else { return false }
        return index > 0
    }

    /// Whether the face ID step is the one that commits.
    var isLastStep: Bool { step == steps.last }

    /// The opening balance, when the typed text is a number.
    var openingBalance: Decimal? {
        DecimalInput.decimal(from: openingBalanceText, locale: locale)
    }

    /// Whether the typed opening balance is a number of zero or more.
    var isOpeningBalanceValid: Bool {
        guard let openingBalance else { return false }
        return openingBalance >= 0
    }

    /// Whether the account step has everything it needs.
    var isAccountValid: Bool {
        !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isOpeningBalanceValid
    }

    /// Whether Continue may leave the current step.
    ///
    /// Only the account step has required input; every other step can be continued as it stands.
    var canContinue: Bool {
        step == .account ? isAccountValid : true
    }

    /// The settings the flow has collected, ready for the committer.
    var effectiveSettings: AppSettings {
        var settings = AppSettings.defaultValue
        settings.currencyCode = currencyCode
        settings.numberGrouping = numberGrouping
        settings.parserMode = parserMode
        settings.faceIDEnabled = faceIDEnabled
        return settings
    }

    /// The formatting every amount in the flow previews with.
    func moneyFormat(locale: Locale) -> MoneyFormat {
        MoneyFormat(currencyCode: currencyCode, grouping: numberGrouping, locale: locale)
    }

    /// Moves to the next step, staying put on the last one so the flow can commit instead.
    func advance() {
        let steps = steps
        guard let index = steps.firstIndex(of: step), index + 1 < steps.count else { return }
        step = steps[index + 1]
    }

    /// Moves to the previous step, staying put on the first one.
    func goBack() {
        let steps = steps
        guard let index = steps.firstIndex(of: step), index > 0 else { return }
        step = steps[index - 1]
    }

    /// Checks whether the on-device model can run here.
    ///
    /// Availability is informational: the answer never blocks Continue, and Rules always works.
    func checkParserAvailability() async {
        #if canImport(FoundationModels)
        availability = await FoundationModelsClient().availability()
        #else
        availability = .unavailable(String(localized: "Apple Intelligence isn't available on this device."))
        #endif
    }

    /// Creates the account, checkpoint, seeds, and settings, then shows the completion screen.
    ///
    /// A failure leaves the steps in place with ``commitFailed`` set, so the user can try again
    /// without losing what they entered.
    func commit(using committer: OnboardingCommitter, context: ModelContext) {
        guard let openingBalance else { return }
        commitFailed = false
        do {
            let account = try committer.commit(
                settings: effectiveSettings,
                accountName: accountName,
                institutionName: institutionName,
                openingBalance: openingBalance,
                faceIDEnabled: faceIDEnabled,
                context: context
            )
            committedOpeningBalance = openingBalance
            committedSettings = effectiveSettings
            committedAccount = account
        } catch {
            commitFailed = true
        }
    }
}
