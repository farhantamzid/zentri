import Foundation

/// Reads money amounts from message text deterministically, without the device locale.
///
/// The rules are fixed so the same message always produces the same value:
/// - Grouping separators are `,`, `.`, and any whitespace (including non-breaking spaces).
/// - When both `,` and `.` appear, the one that appears last is the decimal separator and the
///   other groups thousands, so `1,234.56` and `1.234,56` are both 1234.56.
/// - With a single separator and exactly three digits after it, the separator groups
///   thousands, so `12,500` is 12500. With one or two digits after it, it starts the
///   fraction, so `12,50` is 12.50.
/// - Grouping must be well formed: three-digit groups (or Indian two-digit groups), so
///   `1,23.45` and `1 2 3` are rejected rather than guessed.
/// - A leading currency symbol or label such as `RM` or `Avl Bal:`, and a trailing `CR`/`DR`
///   marker, are removed.
/// - Signs, parentheses, trailing text, an empty fraction, and more than two fraction digits
///   are rejected.
public enum AmountNormalizer {
    /// The characters that make an amount signed or parenthesised, which is never valid as a
    /// transaction magnitude.
    private static let rejectedCharacters: Set<Character> = ["-", "+", "(", ")", "−"]

    /// The largest digit count accepted. `Decimal` holds 38 digits exactly; this margin keeps
    /// every accepted amount exactly representable while rejecting absurd input quickly.
    private static let maximumDigitCount = 30

    /// Where a lone `,` or `.` sits in an amount.
    private enum Placement {
        /// The separator starts the fraction.
        case decimal(Int)
        /// The separator groups thousands and the amount has no fraction.
        case grouping
        /// The separator cannot be interpreted without guessing.
        case invalid
    }

    /// The decimal value of `raw`, or `nil` when it is not an unambiguous amount.
    public static func decimal(from raw: String?) -> Decimal? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !trimmed.contains(where: rejectedCharacters.contains) else { return nil }
        guard let numericText = numericText(from: trimmed) else { return nil }
        return value(from: numericText)
    }

    /// The characters between the first and last digit, with a prefix label and a `CR`/`DR`
    /// marker removed and whitespace runs turned into grouping separators.
    private static func numericText(from raw: String) -> [Character]? {
        let characters = Array(raw)
        guard let firstDigit = characters.firstIndex(where: isASCIIDigit),
              let lastDigit = characters.lastIndex(where: isASCIIDigit) else {
            return nil
        }

        // A rule may capture its currency symbol or label inside the amount group, e.g.
        // "RM12.50" or "Avl Bal: 1,234.50". Only characters that cannot be part of a number
        // are allowed before the first digit.
        let prefix = characters[..<firstDigit]
        for character in prefix where !character.isWhitespace {
            guard character.isLetter || character.isCurrencySymbol || character == "." || character == ":" else {
                return nil
            }
        }
        // A dot directly before the digits means the value had no integer part, e.g. ".50".
        if prefix.last(where: { !$0.isWhitespace }) == "." { return nil }

        // Balance captures often end with a credit/debit marker, e.g. "1,234.50 CR".
        let suffix = characters[(lastDigit + 1)...]
        if !suffix.isEmpty {
            let marker = String(suffix).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard marker == "CR" || marker == "DR" else { return nil }
        }

        var normalized: [Character] = []
        var pendingSpace = false
        for character in characters[firstDigit...lastDigit] {
            if character.isWhitespace {
                pendingSpace = true
                continue
            }
            if pendingSpace {
                normalized.append("_")
                pendingSpace = false
            }
            normalized.append(character)
        }
        return normalized
    }

    /// The value of a numeric string made of digits, `,`, `.`, and `_` (space grouping).
    private static func value(from characters: [Character]) -> Decimal? {
        guard characters.first.map(isASCIIDigit) == true,
              characters.last.map(isASCIIDigit) == true,
              characters.allSatisfy({ isASCIIDigit($0) || $0 == "," || $0 == "." || $0 == "_" }) else {
            return nil
        }

        let commaCount = characters.count(where: { $0 == "," })
        let dotCount = characters.count(where: { $0 == "." })

        var decimalIndex: Int?
        if commaCount > 0 && dotCount > 0 {
            guard let lastComma = characters.lastIndex(of: ","),
                  let lastDot = characters.lastIndex(of: ".") else {
                return nil
            }
            let separatorIndex = max(lastComma, lastDot)
            let separator = characters[separatorIndex]
            // The decimal separator may appear only once; the other separator groups.
            guard characters.count(where: { $0 == separator }) == 1 else { return nil }
            decimalIndex = separatorIndex
        } else if commaCount == 1 && dotCount == 0 {
            guard let index = characters.firstIndex(of: ",") else { return nil }
            switch placement(ofSeparatorAt: index, in: characters) {
            case .decimal(let position):
                decimalIndex = position
            case .grouping:
                decimalIndex = nil
            case .invalid:
                return nil
            }
        } else if dotCount == 1 && commaCount == 0 {
            guard let index = characters.firstIndex(of: ".") else { return nil }
            switch placement(ofSeparatorAt: index, in: characters) {
            case .decimal(let position):
                decimalIndex = position
            case .grouping:
                decimalIndex = nil
            case .invalid:
                return nil
            }
        } else if (commaCount == 0) != (dotCount == 0) {
            // One separator character repeats, so it only groups thousands.
            decimalIndex = nil
        } else if commaCount == 0 && dotCount == 0 {
            decimalIndex = nil
        } else {
            // Both separator characters repeat: the decimal separator is ambiguous.
            return nil
        }

        let integerCharacters: ArraySlice<Character>
        let fractionCharacters: ArraySlice<Character>
        if let decimalIndex {
            integerCharacters = characters[..<decimalIndex]
            fractionCharacters = characters[(decimalIndex + 1)...]
            guard (1...2).contains(fractionCharacters.count),
                  fractionCharacters.allSatisfy({ isASCIIDigit($0) }) else {
                return nil
            }
        } else {
            integerCharacters = characters[...]
            fractionCharacters = []
        }

        guard let groups = groupingGroups(in: integerCharacters) else { return nil }
        let digits = groups.joined() + String(fractionCharacters)
        guard digits.count <= maximumDigitCount else { return nil }

        var value = Decimal.zero
        for character in digits {
            guard let digit = character.wholeNumberValue else { return nil }
            value = value * 10 + Decimal(digit)
        }
        if !fractionCharacters.isEmpty {
            var divisor = Decimal(1)
            for _ in 0..<fractionCharacters.count {
                divisor *= 10
            }
            value /= divisor
        }
        return value
    }

    /// Whether the character is an ASCII digit. Only ASCII digits are accepted, so Arabic-Indic
    /// and other digit shapes are rejected instead of being read with the device locale.
    private static func isASCIIDigit(_ character: Character) -> Bool {
        character.isASCII && character.isNumber
    }

    /// Whether a lone `,` or `.` starts the fraction or groups thousands.
    private static func placement(ofSeparatorAt index: Int, in characters: [Character]) -> Placement {
        let fraction = characters[(index + 1)...]
        guard fraction.allSatisfy({ isASCIIDigit($0) }) else { return .invalid }
        switch fraction.count {
        case 1, 2:
            return .decimal(index)
        case 3:
            // Three digits read as thousands, as in "12,500", unless the integer part is only
            // zeros: "0,123" is not 123 and is rejected instead of guessed.
            let integerPart = characters[..<index]
            guard integerPart.contains(where: { isASCIIDigit($0) && $0 != "0" }) else { return .invalid }
            return .grouping
        default:
            return .invalid
        }
    }

    /// The digit groups of an integer part, validated as Western or Indian grouping.
    private static func groupingGroups(in characters: ArraySlice<Character>) -> [String]? {
        var groups: [String] = []
        var current = ""
        for character in characters {
            if isASCIIDigit(character) {
                current.append(character)
            } else {
                guard !current.isEmpty else { return nil }
                groups.append(current)
                current = ""
            }
        }
        guard !current.isEmpty else { return nil }
        groups.append(current)

        guard let first = groups.first else { return nil }
        if groups.count > 1 {
            guard (1...3).contains(first.count) else { return nil }
            let western = groups.dropFirst().allSatisfy { $0.count == 3 }
            let indian = groups.count > 2
                && groups.last?.count == 3
                && groups.dropFirst().dropLast().allSatisfy { $0.count == 2 }
            guard western || indian else { return nil }
        }
        return groups
    }
}
