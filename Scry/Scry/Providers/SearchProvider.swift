import AppKit

/// A single search result returned by native providers.
struct SearchResult {
    let title: String
    let snippet: String
    let url: URL?
    let imageURL: URL?
}

/// A setting that a provider exposes for user configuration.
struct ProviderSetting {
    let key: String
    let name: String
    let defaultValue: Any
}

/// Protocol for pluggable search backends.
/// Web-based providers (Google, DuckDuckGo) return a URL + optional CSS injection.
/// Native providers (Wikipedia) return structured SearchResult data.
protocol SearchProvider {
    /// Unique identifier (e.g. "google", "duckduckgo", "wikipedia").
    var id: String { get }

    /// Human-readable name for display.
    var name: String { get }

    /// SF Symbol name for the provider icon.
    var iconSymbolName: String { get }

    /// Whether this provider renders results natively (vs. WKWebView).
    var supportsNativeRendering: Bool { get }

    /// For web-based providers: return the search URL for the given query.
    func searchURL(for query: String) -> URL?

    /// For native providers: return structured results.
    func search(query: String) async throws -> [SearchResult]

    /// CSS to inject into WKWebView (for cleanup/theming).
    var injectedCSS: String? { get }

    /// JavaScript to inject into WKWebView after page load.
    var injectedJS: String? { get }

    /// Provider-specific configurable settings.
    var configurableSettings: [ProviderSetting] { get }
}

// Default implementations
extension SearchProvider {
    var supportsNativeRendering: Bool { false }

    func searchURL(for query: String) -> URL? { nil }

    func search(query: String) async throws -> [SearchResult] { [] }

    var injectedCSS: String? { nil }
    var injectedJS: String? { nil }

    var configurableSettings: [ProviderSetting] { [] }
}
