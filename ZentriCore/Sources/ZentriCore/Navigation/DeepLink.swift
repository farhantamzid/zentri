import Foundation

/// A `zentri://` link a widget opens the app with.
///
/// The widgets and the app share this type so the URLs a widget sends are exactly the URLs the app
/// understands. Only these three destinations exist; anything else is not a deep link and the app
/// ignores it.
public enum DeepLink: String, CaseIterable, Sendable {
    case overview
    case transactions
    case insights

    /// The URL scheme the app declares.
    public static let scheme = "zentri"

    /// The link's URL, e.g. `zentri://overview`.
    public var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = rawValue
        // The components above are always valid, so the fallback is never reached.
        return components.url ?? URL(filePath: "/")
    }

    /// The deep link a URL names, or `nil` for any other URL.
    ///
    /// The scheme and host are matched without regard to case, as URL schemes and hosts are, and a
    /// bare trailing slash is accepted; any further path is not.
    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme,
              let host = url.host(percentEncoded: false)?.lowercased(),
              let link = DeepLink(rawValue: host),
              url.path(percentEncoded: false).isEmpty || url.path(percentEncoded: false) == "/"
        else { return nil }
        self = link
    }
}
