/// The currency symbols the app displays for its supported currencies.
public enum CurrencyCatalog {
    /// The currencies the app supports, keyed by ISO 4217 code.
    private static let symbols: [String: String] = [
        "AED": "د.إ",
        "AUD": "A$",
        "BDT": "৳",
        "CAD": "C$",
        "EUR": "€",
        "GBP": "£",
        "INR": "₹",
        "JPY": "¥",
        "MYR": "RM",
        "SGD": "S$",
        "USD": "$",
    ]

    /// The symbol for `currencyCode`, falling back to the uppercased code when unknown.
    public static func symbol(for currencyCode: String) -> String {
        let code = currencyCode.uppercased()
        return symbols[code] ?? code
    }
}
