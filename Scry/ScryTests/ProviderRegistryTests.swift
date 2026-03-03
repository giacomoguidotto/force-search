import XCTest
@testable import Scry

final class ProviderRegistryTests: XCTestCase {

    func testDefaultProvidersRegistered() {
        let registry = ProviderRegistry.shared
        XCTAssertNotNil(registry.provider(for: "google"))
        XCTAssertNotNil(registry.provider(for: "duckduckgo"))
        XCTAssertNotNil(registry.provider(for: "wikipedia"))
    }

    func testGoogleProviderURL() {
        let google = GoogleSearchProvider()
        let url = google.searchURL(for: "hello world")
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("google.com"))
        XCTAssertTrue(url!.absoluteString.contains("hello%20world"))
        XCTAssertTrue(url!.absoluteString.contains("igu=1"))
    }

    func testDuckDuckGoProviderURL() {
        let ddg = DuckDuckGoSearchProvider()
        let url = ddg.searchURL(for: "swift programming")
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("duckduckgo.com"))
        XCTAssertTrue(url!.absoluteString.contains("swift%20programming"))
    }

    func testWikipediaProviderURL() {
        let wiki = WikipediaProvider()
        let url = wiki.searchURL(for: "Albert Einstein")
        XCTAssertNotNil(url)
        let urlString = url!.absoluteString
        XCTAssertTrue(urlString.contains("wikipedia.org"))
        // URLComponents encodes spaces as + in query parameters
        XCTAssertTrue(urlString.contains("titles=Albert+Einstein") || urlString.contains("titles=Albert%20Einstein"),
            "Expected query in URL, got: \(urlString)")
    }

    func testWikipediaIsNativeRendering() {
        let wiki = WikipediaProvider()
        XCTAssertTrue(wiki.supportsNativeRendering)
    }

    func testGoogleIsNotNativeRendering() {
        let google = GoogleSearchProvider()
        XCTAssertFalse(google.supportsNativeRendering)
    }

    func testGoogleHasInjectedCSS() {
        let google = GoogleSearchProvider()
        XCTAssertNotNil(google.injectedCSS)
    }

    func testEnabledProvidersRespectsSettings() {
        let registry = ProviderRegistry.shared
        let settings = AppSettings.shared

        let original = settings.enabledProviders
        defer { settings.enabledProviders = original }

        settings.enabledProviders = ["google", "wikipedia"]
        let enabled = registry.enabledProviders()
        let ids = enabled.map { $0.id }

        XCTAssertTrue(ids.contains("google"))
        XCTAssertTrue(ids.contains("wikipedia"))
        XCTAssertFalse(ids.contains("duckduckgo"))
    }
}
