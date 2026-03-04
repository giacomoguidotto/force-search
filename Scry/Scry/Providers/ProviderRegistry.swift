import Combine
import Foundation

final class ProviderRegistry {
    static let shared = ProviderRegistry()

    /// All registered providers, keyed by ID.
    private var providers: [String: SearchProvider] = [:]

    /// Cached ordered list of enabled providers, invalidated on settings change.
    private var cachedEnabledProviders: [SearchProvider]?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        registerDefaults()
        observeSettings()
    }

    /// Register a search provider.
    func register(_ provider: SearchProvider) {
        providers[provider.id] = provider
        cachedEnabledProviders = nil
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
        if let cached = cachedEnabledProviders {
            return cached
        }
        let settings = AppSettings.shared
        let enabledSet = Set(settings.enabledProviders)
        let result = settings.providerOrder.compactMap { id -> SearchProvider? in
            guard enabledSet.contains(id) else { return nil }
            return providers[id]
        }
        cachedEnabledProviders = result
        return result
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

    private func observeSettings() {
        let settings = AppSettings.shared
        settings.$enabledProviders
            .merge(with: settings.$providerOrder)
            .sink { [weak self] _ in
                self?.cachedEnabledProviders = nil
            }
            .store(in: &cancellables)
    }
}
