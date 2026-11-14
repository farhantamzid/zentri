import Foundation
import Testing
@testable import ZentriCore

@Test func amountFormats() {
    #expect(AmountNormalizer.decimal(from: "RM1,234.56") == Decimal(string: "1234.56"))
    #expect(AmountNormalizer.decimal(from: "1.234,56") == Decimal(string: "1234.56"))
    #expect(AmountNormalizer.decimal(from: "12,500") == Decimal(string: "12500"))
    #expect(AmountNormalizer.decimal(from: "12,50") == Decimal(string: "12.50"))
    #expect(AmountNormalizer.decimal(from: "1\u{00A0}234.00") == Decimal(string: "1234.00"))
    #expect(AmountNormalizer.decimal(from: "-12.50") == nil)
    #expect(AmountNormalizer.decimal(from: "abc") == nil)
}

@Test func currencySymbolsAndLabelsAreStripped() {
    #expect(AmountNormalizer.decimal(from: "$1,234.50") == Decimal(string: "1234.50"))
    #expect(AmountNormalizer.decimal(from: "৳1,000.00") == Decimal(string: "1000.00"))
    #expect(AmountNormalizer.decimal(from: "RM 12.50") == Decimal(string: "12.50"))
    #expect(AmountNormalizer.decimal(from: " MYR 12.50 ") == Decimal(string: "12.50"))
    #expect(AmountNormalizer.decimal(from: "Avl Bal: RM1,234.50") == Decimal(string: "1234.50"))
    #expect(AmountNormalizer.decimal(from: "Available Balance 1,234.50") == Decimal(string: "1234.50"))
}

@Test func unicodeSpacesActAsGroupingSeparators() {
    #expect(AmountNormalizer.decimal(from: "1\u{00A0}234\u{00A0}567.89") == Decimal(string: "1234567.89"))
    #expect(AmountNormalizer.decimal(from: "1\u{202F}234.00") == Decimal(string: "1234.00"))
    #expect(AmountNormalizer.decimal(from: "1\u{2009}234.00") == Decimal(string: "1234.00"))
}

@Test func groupingVariants() {
    #expect(AmountNormalizer.decimal(from: "1,234,567.89") == Decimal(string: "1234567.89"))
    #expect(AmountNormalizer.decimal(from: "1.234.567,89") == Decimal(string: "1234567.89"))
    #expect(AmountNormalizer.decimal(from: "1,234") == Decimal(string: "1234"))
    #expect(AmountNormalizer.decimal(from: "1.234") == Decimal(string: "1234"))
    // Indian grouping is unambiguous, so the amount is still read exactly.
    #expect(AmountNormalizer.decimal(from: "10,00,000.00") == Decimal(string: "1000000.00"))
    #expect(AmountNormalizer.decimal(from: "1,23,456.78") == Decimal(string: "123456.78"))
}

@Test func creditDebitMarkersAreRemoved() {
    #expect(AmountNormalizer.decimal(from: "1,234.50 CR") == Decimal(string: "1234.50"))
    #expect(AmountNormalizer.decimal(from: "1,234.50dr") == Decimal(string: "1234.50"))
    #expect(AmountNormalizer.decimal(from: "1,234.50 XYZ") == nil)
}

@Test func rejectsAmbiguousOrMalformedInput() {
    #expect(AmountNormalizer.decimal(from: "") == nil)
    #expect(AmountNormalizer.decimal(from: "   ") == nil)
    #expect(AmountNormalizer.decimal(from: "+12.50") == nil)
    #expect(AmountNormalizer.decimal(from: "(12.50)") == nil)
    #expect(AmountNormalizer.decimal(from: "12.50-") == nil)
    #expect(AmountNormalizer.decimal(from: "12.") == nil)
    #expect(AmountNormalizer.decimal(from: ".50") == nil)
    #expect(AmountNormalizer.decimal(from: "12..50") == nil)
    #expect(AmountNormalizer.decimal(from: "1,,234") == nil)
    #expect(AmountNormalizer.decimal(from: "1,23.45") == nil)
    #expect(AmountNormalizer.decimal(from: "1,234.567") == nil)
    #expect(AmountNormalizer.decimal(from: "1 2 3") == nil)
    #expect(AmountNormalizer.decimal(from: "12abc") == nil)
    #expect(AmountNormalizer.decimal(from: "0.123") == nil)
    #expect(AmountNormalizer.decimal(from: "12,3456") == nil)
    #expect(AmountNormalizer.decimal(from: nil) == nil)
}

@Test func zeroAndLeadingZeroAmounts() {
    #expect(AmountNormalizer.decimal(from: "0.00") == Decimal(string: "0.00"))
    #expect(AmountNormalizer.decimal(from: "0,50") == Decimal(string: "0.50"))
    #expect(AmountNormalizer.decimal(from: "0.5") == Decimal(string: "0.5"))
    #expect(AmountNormalizer.decimal(from: "00012.50") == Decimal(string: "12.50"))
}

@Test func rejectsAbsurdlyLongDigitStrings() {
    #expect(AmountNormalizer.decimal(from: String(repeating: "9", count: 40)) == nil)
    #expect(AmountNormalizer.decimal(from: String(repeating: "9", count: 20_000)) == nil)
}
