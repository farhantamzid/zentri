import Foundation
import Testing
@testable import ZentriCore

@Test func validPatternWithAnAmountGroupPasses() throws {
    let regex = try RegexValidator.validate(pattern: #"RM(?<amount>[\d.,]+) spent at (?<merchant>.+)"#).get()
    #expect(RegexValidator.hasAmountGroup(regex))
    #expect(RegexValidator.validateRule(pattern: #"RM(?<amount>[\d.,]+)"#) == nil)
}

@Test func invalidSyntaxIsReportedAsSyntax() {
    let result = RegexValidator.validate(pattern: #"RM(?<amount>[\d.,]+"#)
    guard case .failure(.invalidSyntax(let detail)) = result else {
        Issue.record("An unbalanced group was accepted: \(result)")
        return
    }
    #expect(!detail.isEmpty)
    #expect(RegexValidator.validateRule(pattern: #"RM(?<amount>[\d.,]+"#)?.isInvalidSyntax == true)
}

@Test func missingAmountGroupCompilesButIsNotARule() throws {
    let regex = try RegexValidator.validate(pattern: #"spent at (?<merchant>.+)"#).get()
    #expect(!RegexValidator.hasAmountGroup(regex))
    #expect(RegexValidator.validateRule(pattern: #"spent at (?<merchant>.+)"#) == .missingAmountGroup)
}

@Test func amountGroupNameMustMatchExactly() throws {
    // `amounts` is a different group; the parser reads `amount` only.
    let regex = try RegexValidator.validate(pattern: #"RM(?<amounts>\d+)"#).get()
    #expect(!RegexValidator.hasAmountGroup(regex))
}

@Test(arguments: ["", "   ", "\n\t"])
func emptyPatternIsRejected(pattern: String) {
    let result = RegexValidator.validate(pattern: pattern)
    guard case .failure(.emptyPattern) = result else {
        Issue.record("An empty pattern was accepted: \(result)")
        return
    }
    #expect(RegexValidator.validateRule(pattern: pattern) == .emptyPattern)
}

private extension RegexValidationError {
    var isInvalidSyntax: Bool {
        if case .invalidSyntax = self { return true }
        return false
    }
}
