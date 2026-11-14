import CryptoKit
import Foundation

/// The message identity rules that keep a re-run Shortcut from recording a message twice.
///
/// Two checks work together. A fingerprint identifies a message exactly — its normalized text, the
/// sender, the account, and the minute it was received — so replaying the same automation is
/// idempotent. A recent-duplicate check catches the same message arriving with a new timestamp
/// inside ``recentDuplicateWindow``, which is what happens when an automation fires twice or the
/// message date arrives slightly late.
///
/// Everything here is pure: no store, no clock, and no locale-dependent comparison, so the same
/// input always produces the same answer.
public enum Dedupe {
    /// How far apart two copies of one message may be received and still count as the same message.
    ///
    /// The window is inclusive: two copies exactly this far apart are duplicates, one second more
    /// is a new message.
    public static let recentDuplicateWindow: TimeInterval = 120

    /// The character that separates the fingerprint's fields, so no field can absorb the next.
    private static let fieldSeparator = "\u{1F}"

    /// The lowercase hexadecimal digits used to write the digest.
    private static let hexDigits: [Character] = Array("0123456789abcdef")

    /// The SHA-256 identity of one message.
    ///
    /// The digest covers the whitespace-normalized text, the sender, the account, and the minute
    /// nearest `receivedAt`. Two copies of the same message that arrive within the same minute
    /// therefore hash identically — including copies a few seconds apart that straddle a minute
    /// boundary — while a message that merely looks similar does not. A boundary case that rounding
    /// cannot keep together is still caught by ``isRecentDuplicate(text:sender:accountID:receivedAt:existing:)``.
    ///
    /// - Parameters:
    ///   - text: The message text, normalized here so spacing and line endings do not matter.
    ///   - sender: The sender the Shortcut supplied, if any. Missing and blank are the same value.
    ///   - accountID: The resolved account. Passing `nil` is supported but weaker: two accounts'
    ///     identical messages then share a fingerprint.
    ///   - receivedAt: The message date, reduced to the minute nearest it.
    /// - Returns: 64 lowercase hexadecimal characters.
    public static func fingerprint(
        text: String,
        sender: String?,
        accountID: UUID?,
        receivedAt: Date
    ) -> String {
        let fields = [
            normalized(text),
            normalized(sender ?? ""),
            accountID?.uuidString ?? "",
            String(minute(nearest: receivedAt)),
        ]
        let digest = SHA256.hash(data: Data(fields.joined(separator: fieldSeparator).utf8))
        return hexString(of: digest)
    }

    /// Whether `text` repeats a message that is already stored.
    ///
    /// A repeat needs the same normalized text and the same sender, and a `receivedAt` within
    /// ``recentDuplicateWindow`` of the stored message. When the sender is unavailable for either
    /// message, the account takes its place, so two banks' messages cannot stand in for each other.
    ///
    /// - Parameters:
    ///   - text: The new message's text.
    ///   - sender: The new message's sender, if the caller has one.
    ///   - accountID: The new message's resolved account.
    ///   - receivedAt: The new message's date.
    ///   - existing: The messages worth comparing with, usually the recent archive. Rows the caller
    ///     is retrying must be left out so a message does not duplicate itself.
    /// - Returns: `true` when the message repeats a stored one.
    public static func isRecentDuplicate(
        text: String,
        sender: String?,
        accountID: UUID?,
        receivedAt: Date,
        existing: [DedupeCandidate]
    ) -> Bool {
        let expectedText = normalized(text)
        let expectedSender = folded(sender)
        let expectedAccount = accountID?.uuidString

        return existing.contains { candidate in
            guard normalized(candidate.text) == expectedText else { return false }
            guard abs(candidate.receivedAt.timeIntervalSince(receivedAt)) <= recentDuplicateWindow else {
                return false
            }
            if let expectedSender {
                return folded(candidate.sender) == expectedSender
            }
            return candidate.accountID?.uuidString == expectedAccount
        }
    }

    /// The minute nearest `date`, counted from the epoch.
    ///
    /// Integer minute arithmetic keeps the fingerprint independent of the device's calendar, time
    /// zone, and locale. Rounding rather than truncating means a copy of a message that arrives a
    /// few seconds after its original still lands in the same minute unless the two straddle the
    /// minute's midpoint.
    private static func minute(nearest date: Date) -> Int {
        Int((date.timeIntervalSince1970 / 60).rounded())
    }

    /// The text with runs of whitespace collapsed to single spaces and its ends trimmed.
    private static func normalized(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The sender reduced to a comparison key, or `nil` when it carries nothing.
    ///
    /// Case and padding are ignored because a Shortcut's sender text is user-maintained and
    /// "MYBANK" and "mybank" describe the same bank.
    private static func folded(_ sender: String?) -> String? {
        guard let sender else { return nil }
        let folded = normalized(sender).lowercased()
        return folded.isEmpty ? nil : folded
    }

    /// The digest as lowercase hexadecimal, without a formatter that could follow a locale.
    private static func hexString(of digest: SHA256Digest) -> String {
        digest.reduce(into: "") { result, byte in
            result.append(hexDigits[Int(byte >> 4)])
            result.append(hexDigits[Int(byte & 0x0F)])
        }
    }
}

/// One stored message, reduced to the fields the recent-duplicate check compares.
///
/// The type keeps ``Dedupe`` free of SwiftData: callers map their archive rows into these values.
public struct DedupeCandidate: Sendable, Equatable {
    /// The stored message's text.
    public let text: String
    /// The sender the message arrived with, when one was recorded.
    public let sender: String?
    /// The account the stored message was resolved to, when it is known.
    public let accountID: UUID?
    /// The stored message's date.
    public let receivedAt: Date

    public init(text: String, sender: String? = nil, accountID: UUID? = nil, receivedAt: Date) {
        self.text = text
        self.sender = sender
        self.accountID = accountID
        self.receivedAt = receivedAt
    }
}
