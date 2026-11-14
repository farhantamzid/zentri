import Foundation
import Testing
@testable import ZentriCore

@Test func westernGrouping() {
    let f = MoneyFormat(currencyCode: "USD", grouping: .western, locale: Locale(identifier: "en_US"))
    #expect(f.numberString(from: Decimal(string: "1000000.00")!) == "1,000,000.00")
}

@Test func indianGrouping() {
    let f = MoneyFormat(currencyCode: "BDT", grouping: .indian, locale: Locale(identifier: "en_US"))
    #expect(f.numberString(from: Decimal(string: "1000000.00")!) == "10,00,000.00")
    #expect(f.numberString(from: Decimal(string: "100000.00")!) == "1,00,000.00")
}

@Test func bdtSymbol() {
    let f = MoneyFormat(currencyCode: "BDT", grouping: .western, locale: Locale(identifier: "en_US"))
    #expect(f.currencyString(from: 1000) == "৳1,000.00")
}

@Test func negativeAndZero() {
    let f = MoneyFormat(currencyCode: "USD", grouping: .western, locale: Locale(identifier: "en_US"))
    #expect(f.numberString(from: -1234.5) == "-1,234.50")
    #expect(f.numberString(from: 0) == "0.00")
}

@Test func largeValuesKeepGroupingExact() {
    let western = MoneyFormat(currencyCode: "USD", grouping: .western, locale: Locale(identifier: "en_US"))
    #expect(western.numberString(from: Decimal(string: "1234567890.12")!) == "1,234,567,890.12")
    #expect(western.numberString(from: Decimal(string: "999.5")!) == "999.50")

    let indian = MoneyFormat(currencyCode: "BDT", grouping: .indian, locale: Locale(identifier: "en_US"))
    #expect(indian.numberString(from: Decimal(string: "1234567890.12")!) == "1,23,45,67,890.12")
    #expect(indian.numberString(from: Decimal(string: "123456.78")!) == "1,23,456.78")
}

@Test func systemGroupingFollowsLocale() {
    let german = MoneyFormat(currencyCode: "EUR", grouping: .system, locale: Locale(identifier: "de_DE"))
    #expect(german.numberString(from: Decimal(string: "1000000.00")!) == "1.000.000,00")
    #expect(german.currencyString(from: 1000) == "€1.000,00")
}

@Test func explicitGroupingIgnoresLocaleDefaults() {
    let indianLocale = Locale(identifier: "en_IN")
    let westernInIndianLocale = MoneyFormat(currencyCode: "INR", grouping: .western, locale: indianLocale)
    #expect(westernInIndianLocale.numberString(from: Decimal(string: "1000000.00")!) == "1,000,000.00")
    #expect(westernInIndianLocale.currencyString(from: 1000) == "₹1,000.00")
}

@Test func catalogSymbolsMatchSpecification() {
    #expect(CurrencyCatalog.symbol(for: "BDT") == "৳")
    #expect(CurrencyCatalog.symbol(for: "USD") == "$")
    #expect(CurrencyCatalog.symbol(for: "EUR") == "€")
    #expect(CurrencyCatalog.symbol(for: "GBP") == "£")
    #expect(CurrencyCatalog.symbol(for: "MYR") == "RM")
    #expect(CurrencyCatalog.symbol(for: "INR") == "₹")
    #expect(CurrencyCatalog.symbol(for: "SGD") == "S$")
    #expect(CurrencyCatalog.symbol(for: "AUD") == "A$")
    #expect(CurrencyCatalog.symbol(for: "CAD") == "C$")
    #expect(CurrencyCatalog.symbol(for: "JPY") == "¥")
    #expect(CurrencyCatalog.symbol(for: "AED") == "د.إ")
    #expect(CurrencyCatalog.symbol(for: "usd") == "$")
    #expect(CurrencyCatalog.symbol(for: "XYZ") == "XYZ")
}
