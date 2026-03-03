import Foundation

final class ProviderRegistry {
    static let shared = ProviderRegistry()

    /// All registered providers, keyed by ID.
    private var providers: [String: SearchProvider] = [:]

    private init() {
        registerDefaults()
    }

    /// Register a search provider.
    func register(_ provider: SearchProvider) {
        providers[provider.id] = provider
    }

    /// Get a provider by ID.
    func provider(for id: String) -> SearchProvider? {
        return providers[id]
    }

    /// All registered provider IDs.
    var allProviderIDs: [String] {
        return Array(providers.keys)
    }

    /// Returns the ordered list of enabled providers based on current settings.
    func enabledProviders() -> [SearchProvider] {
        let settings = AppSettings.shared
        return settings.providerOrder.compactMap { id in
            guard settings.enabledProviders.contains(id) else { return nil }
            return providers[id]
        }
    }

    /// All registered providers (unordered).
    func allProviders() -> [SearchProvider] {
        return Array(providers.values)
    }

    // MARK: - Private

    private func registerDefaults() {
        register(GoogleSearchProvider())
        register(DuckDuckGoSearchProvider())
        register(WikipediaProvider())
    }
}
