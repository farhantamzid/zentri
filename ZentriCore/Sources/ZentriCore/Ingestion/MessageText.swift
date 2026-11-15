import Foundation

/// The text clean-ups ingestion, reprocessing, and the rule tester share, so a message reads the
/// same way wherever it is parsed.
///
/// The merchant clean-up patterns are not `Sendable`, so the type lives on the main actor with the
/// services that use it; the plain text helpers are `nonisolated` so off-main parsing can use them.
@MainActor
enum MessageText {
    /// The merchant shown when nothing is left after the message's noise is stripped.
    nonisolated static let unknownMerchant = "Unknown merchant"
    /// The largest number of trailing-noise removals tried on one merchant name.
    nonisolated private static let maximumMerchantCleanupPasses = 3

    /// The text handed to the parser.
    ///
    /// Line endings are unified and the outer whitespace is trimmed, but the message's own line
    /// breaks and inner spacing stay intact so a multi-line rule still matches. The original text is
    /// what the archive keeps.
    nonisolated static func normalizedForParsing(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The text with runs of whitespace collapsed to single spaces.
    nonisolated static func collapsedWhitespace(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The merchant for display and keyword matching, with trailing reference noise removed.
    ///
    /// A rule captures everything after its keyword, so "RM12.50 spent at KFC on 14/11/26 Ref 8891"
    /// can leave "KFC on 14/11/26 Ref 8891" as the merchant. Spec §10.2 asks for that noise to be
    /// stripped from the name the app shows and matches; the extracted value is kept on
    /// `merchantRaw` so nothing is lost. A name that is nothing but noise becomes
    /// ``unknownMerchant``.
    static func displayMerchant(from extracted: String) -> String {
        var value = extracted
        for _ in 0..<maximumMerchantCleanupPasses {
            let stripped = trimmingTrailingSeparators(strippingTrailingNoise(value))
            if stripped == value {
                break
            }
            value = stripped
        }
        return value.isEmpty ? unknownMerchant : value
    }

    /// Removes one trailing reference or date phrase, when the value ends with one.
    private static func strippingTrailingNoise(_ value: String) -> String {
        var result = value
        for pattern in [referenceNoise, numericDateNoise, namedDateNoise] {
            guard let range = result.firstRange(of: pattern) else { continue }
            result.removeSubrange(range)
        }
        return result
    }

    /// Removes trailing punctuation that separated a merchant from the noise removed from it.
    private static func trimmingTrailingSeparators(_ value: String) -> String {
        var result = value
        while let last = result.last, ",;:.-–—".contains(last) {
            result.removeLast()
        }
        return result
    }

    /// A trailing reference such as "Ref 12345", "REF: 8891-A", or "Reference no. 77".
    private static let referenceNoise = /(?i)[\s,;:.\-–—]*\bref(?:erence)?\s*(?:no\.?|number|#|id)?\s*[:#]?\s*[A-Za-z0-9][A-Za-z0-9\-\/_]*[\s,;:.\-–—]*$/

    /// A trailing numeric date such as "on 17/11/26" or "on 2026-11-17".
    private static let numericDateNoise = /(?i)[\s,;:.\-–—]*\bon\s+\d{1,4}[.\/-]\d{1,2}[.\/-]\d{1,4}[\s,;:.\-–—]*$/

    /// A trailing named date such as "on 17 Nov 2026".
    private static let namedDateNoise = /(?i)[\s,;:.\-–—]*\bon\s+\d{1,2}(?:st|nd|rd|th)?\s+[A-Za-z]{3,9}(?:\s+\d{2,4})?[\s,;:.\-–—]*$/
}
