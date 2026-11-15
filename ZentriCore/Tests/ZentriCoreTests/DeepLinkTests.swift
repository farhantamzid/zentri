import Foundation
import Testing
@testable import ZentriCore

@Test func eachDeepLinkRoundTripsThroughItsURL() {
    #expect(DeepLink.overview.url.absoluteString == "zentri://overview")
    #expect(DeepLink.transactions.url.absoluteString == "zentri://transactions")
    #expect(DeepLink.insights.url.absoluteString == "zentri://insights")
    for link in DeepLink.allCases {
        #expect(DeepLink(url: link.url) == link)
    }
}

@Test func deepLinksIgnoreSchemeCaseAndATrailingSlash() throws {
    #expect(DeepLink(url: try #require(URL(string: "ZENTRI://Insights"))) == .insights)
    #expect(DeepLink(url: try #require(URL(string: "zentri://transactions/"))) == .transactions)
}

@Test func unknownURLsAreNotDeepLinks() throws {
    for text in ["zentri://settings", "zentri://", "zentri://overview/extra", "https://overview", "other://insights"] {
        #expect(DeepLink(url: try #require(URL(string: text))) == nil, "\(text)")
    }
}
