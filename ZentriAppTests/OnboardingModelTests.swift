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
@Test func effectiveSettingsCarryEverySelection() async {
    let model = OnboardingModel(biometric: StubBiometrics(results: [true]))
    model.currencyCode = "BDT"
    model.numberGrouping = .indian
    model.parserMode = .rules
    await model.setFaceIDEnabled(true)

    let settings = model.effectiveSettings
    #expect(settings.currencyCode == "BDT")
    #expect(settings.numberGrouping == .indian)
    #expect(settings.parserMode == .rules)
    #expect(settings.faceIDEnabled)
}

@MainActor
@Test func aCommaDecimalLocaleReadsTheDecimalPadInputAsOneAndAHalf() {
    // The decimal pad offers the locale's separator, so de_DE types 1,5 rather than 1.5. Reading it
    // through a fixed `.` locale would silently turn it into fifteen.
    let model = OnboardingModel(locale: Locale(identifier: "de_DE"))
    model.accountName = "Everyday"
    model.openingBalanceText = "1,5"

    #expect(model.openingBalance == Decimal(string: "1.5", locale: Locale(identifier: "en_US_POSIX")))
    #expect(model.canContinue)
}

@MainActor
@Test func aCommaDecimalLocaleReadsAGroupedAmountCopiedFromAStatement() {
    // de_DE groups with `.` and separates with `,`, so this is a thousand and fifty cents. Dropping
    // the comma instead would parse 1.00050 — a thousand-fold error.
    let model = OnboardingModel(locale: Locale(identifier: "de_DE"))
    model.accountName = "Everyday"
    model.openingBalanceText = "1.000,50"

    #expect(model.openingBalance == Decimal(string: "1000.5", locale: Locale(identifier: "en_US_POSIX")))
    #expect(model.canContinue)
}

@MainActor
@Test func aCommaGroupingLocaleStillReadsIndianGroupedAmounts() {
    // en_US groups with `,` and separates with `.`, so the Indian grouping the existing test types
    // still parses to a million.
    let model = OnboardingModel(locale: Locale(identifier: "en_US"))
    model.accountName = "Everyday"
    model.openingBalanceText = "10,00,000.00"

    #expect(model.openingBalance == 1_000_000)
    #expect(model.canContinue)
}

@MainActor
@Test func theCurrencyListComesFromTheCatalog() {
    let model = OnboardingModel()
    #expect(model.currencyCodes == CurrencyCatalog.supportedCurrencyCodes)
    #expect(model.currencyCodes.contains("BDT"))
    #expect(model.currencyCode == AppSettings.defaultValue.currencyCode)
}

@MainActor
@Test func turningFaceIDOnDuringSetupNeedsAPassingCheck() async {
    let biometric = StubBiometrics(results: [true])
    let model = OnboardingModel(biometric: biometric)

    await model.setFaceIDEnabled(true)

    #expect(biometric.authenticateCount == 1)
    #expect(model.faceIDEnabled)
    #expect(model.faceIDMessage == nil)
    #expect(model.effectiveSettings.faceIDEnabled)
}

@MainActor
@Test func aFailedCheckDuringSetupLeavesFaceIDOffAndSaysWhy() async {
    let model = OnboardingModel(biometric: StubBiometrics(results: [false]))

    await model.setFaceIDEnabled(true)

    #expect(!model.faceIDEnabled)
    #expect(model.faceIDMessage != nil)
    #expect(!model.effectiveSettings.faceIDEnabled)
}

@MainActor
@Test func aDeviceThatCannotCheckItsOwnerCannotTurnFaceIDOnDuringSetup() async {
    let biometric = StubBiometrics(isAvailable: false)
    let model = OnboardingModel(biometric: biometric)

    await model.setFaceIDEnabled(true)

    #expect(biometric.authenticateCount == 0)
    #expect(!model.faceIDEnabled)
    #expect(model.faceIDMessage != nil)
}

@MainActor
@Test func turningFaceIDOffDuringSetupNeedsNoCheck() async {
    let biometric = StubBiometrics(results: [true])
    let model = OnboardingModel(biometric: biometric)
    await model.setFaceIDEnabled(true)

    await model.setFaceIDEnabled(false)

    #expect(biometric.authenticateCount == 1)
    #expect(!model.faceIDEnabled)
    #expect(model.faceIDMessage == nil)
}
