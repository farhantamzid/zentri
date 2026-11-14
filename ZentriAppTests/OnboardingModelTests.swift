import Foundation
import Testing
import ZentriCore
@testable import ZentriApp

/// The step the flow shows after `advances` Continues from the welcome screen.
@MainActor
private func model(advancedBy advances: Int) -> OnboardingModel {
    let model = OnboardingModel()
    for _ in 0..<advances {
        model.advance()
    }
    return model
}

@MainActor
@Test func accountStepNeedsANameAndAParsedNonNegativeBalance() {
    let model = model(advancedBy: 2)
    #expect(model.step == .account)
    #expect(!model.canContinue)

    model.accountName = "Everyday"
    #expect(!model.canContinue)

    model.openingBalanceText = "1000000"
    #expect(model.canContinue)
    #expect(model.openingBalance == 1_000_000)

    // Typed separators are accepted, so a balance copied from a statement still parses.
    model.openingBalanceText = "10,00,000.00"
    #expect(model.openingBalance == 1_000_000)
    #expect(model.canContinue)

    model.openingBalanceText = "0"
    #expect(model.canContinue)

    model.openingBalanceText = "-1"
    #expect(!model.canContinue)

    model.openingBalanceText = "abc"
    #expect(!model.canContinue)

    model.openingBalanceText = "1.2.3"
    #expect(!model.canContinue)

    model.openingBalanceText = "100"
    model.accountName = "   "
    #expect(!model.canContinue)
}

@MainActor
@Test func laterStepsContinueWithoutTheAccountValidation() {
    let model = model(advancedBy: 0)
    #expect(model.step == .welcome)
    #expect(model.canContinue)
    #expect(!model.canGoBack)

    model.advance()
    #expect(model.step == .currency)
    #expect(model.canContinue)
    #expect(model.canGoBack)
}

@MainActor
@Test func theRulesScreenIsPartOfTheFlowOnlyForTheRulesEngine() {
    let model = OnboardingModel()
    #expect(!model.steps.contains(.rules))
    #expect(model.stepCount == 6)

    model.parserMode = .rules
    #expect(model.steps.contains(.rules))
    #expect(model.stepCount == 7)

    model.advance()
    model.advance()
    model.advance()
    #expect(model.step == .parser)

    model.advance()
    #expect(model.step == .rules)
    #expect(model.stepNumber == 5)

    model.goBack()
    #expect(model.step == .parser)

    // Switching back to Hybrid removes the rules screen from the path that follows.
    model.parserMode = .hybrid
    model.advance()
    #expect(model.step == .shortcuts)
    #expect(model.stepNumber == 5)
}

@MainActor
@Test func theFaceIDStepIsTheLastStep() {
    let model = model(advancedBy: 5)
    #expect(model.step == .faceID)
    #expect(model.isLastStep)
    #expect(model.stepNumber == model.stepCount)

    // Advancing past the end stays put; the flow commits instead of moving on.
    model.advance()
    #expect(model.step == .faceID)
}

@MainActor
@Test func theMoneyFormatFollowsTheSelections() {
    let model = OnboardingModel()
    model.currencyCode = "BDT"
    model.numberGrouping = .indian

    #expect(model.moneyFormat(locale: Locale(identifier: "en_US")).currencyString(from: 1_000_000) == "৳10,00,000.00")

    model.numberGrouping = .western
    #expect(model.moneyFormat(locale: Locale(identifier: "en_US")).currencyString(from: 1_000_000) == "৳1,000,000.00")
}

@MainActor
@Test func effectiveSettingsCarryEverySelection() {
    let model = OnboardingModel()
    model.currencyCode = "BDT"
    model.numberGrouping = .indian
    model.parserMode = .rules
    model.faceIDEnabled = true

    let settings = model.effectiveSettings
    #expect(settings.currencyCode == "BDT")
    #expect(settings.numberGrouping == .indian)
    #expect(settings.parserMode == .rules)
    #expect(settings.faceIDEnabled)
}

@MainActor
@Test func theCurrencyListComesFromTheCatalog() {
    let model = OnboardingModel()
    #expect(model.currencyCodes == CurrencyCatalog.supportedCurrencyCodes)
    #expect(model.currencyCodes.contains("BDT"))
    #expect(model.currencyCode == AppSettings.defaultValue.currencyCode)
}
