import Testing
@testable import ZentriCore

/// The picker reads the supported currencies from the catalog, so its order must be stable and
/// alphabetical rather than mirroring the symbol table's declaration order.
@Test func supportedCurrencyCodesAreAlphabetical() {
    #expect(CurrencyCatalog.supportedCurrencyCodes == CurrencyCatalog.supportedCurrencyCodes.sorted())
}

@Test func supportedCurrencyCodesCoverEveryCatalogSymbol() {
    #expect(CurrencyCatalog.supportedCurrencyCodes == [
        "AED", "AUD", "BDT", "CAD", "EUR", "GBP", "INR", "JPY", "MYR", "SGD", "USD",
    ])
    // Every listed code has its own symbol, and the list matches the symbol table exactly.
    #expect(CurrencyCatalog.supportedCurrencyCodes.count == 11)
    #expect(CurrencyCatalog.symbol(for: "BDT") == "৳")
    #expect(CurrencyCatalog.supportedCurrencyCodes.allSatisfy { CurrencyCatalog.symbol(for: $0) != $0 })
}
