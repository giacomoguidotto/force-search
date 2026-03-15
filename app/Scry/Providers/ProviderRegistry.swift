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
        var result = settings.providerOrder.compactMap { id -> SearchProvider? in
            guard enabledSet.contains(id) else { return nil }
            // Skip AI from the normal list — it's appended conditionally below
            if id == "ai" { return nil }
            return providers[id]
        }

        // Append AI provider if enabled and configured
        let ollamaOrKeyed = settings.aiProviderType == .ollama || !settings.aiAPIKey.isEmpty
        if settings.aiEnabled, ollamaOrKeyed {
            result.append(aiProvider)
        }

        cachedEnabledProviders = result
        return result
    }

    /// All registered providers (unordered).
    func allProviders() -> [SearchProvider] {
        return Array(providers.values)
    }

    // MARK: - Private

    private let aiProvider = AISearchProvider()

    /// Returns the AI provider instance (for setting screenshot before search).
    var aiSearchProvider: AISearchProvider { aiProvider }

    private func registerDefaults() {
        register(GoogleSearchProvider())
        register(DuckDuckGoSearchProvider())
        register(WikipediaProvider())
        register(aiProvider)
    }

    private func observeSettings() {
        let settings = AppSettings.shared
        settings.$enabledProviders
            .merge(with: settings.$providerOrder)
            .sink { [weak self] _ in
                self?.cachedEnabledProviders = nil
            }
            .store(in: &cancellables)

        settings.$aiEnabled
            .merge(with: settings.$aiProviderType.map { _ in false })
            .sink { [weak self] _ in
                self?.cachedEnabledProviders = nil
            }
            .store(in: &cancellables)
    }
}
