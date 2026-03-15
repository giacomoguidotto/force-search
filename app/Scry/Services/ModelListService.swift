import Combine
import Foundation

final class ModelListService: ObservableObject {
    static let shared = ModelListService()

    @Published var models: [String] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    private var lastProvider: AIProviderType?
    private var lastAPIKey: String?

    private init() {}

    func fetchModels(for provider: AIProviderType, apiKey: String) async {
        // Skip if already loaded for this provider+key combo
        if provider == lastProvider, apiKey == lastAPIKey, !models.isEmpty {
            return
        }

        await MainActor.run {
            isLoading = true
            error = nil
        }

        let fetched: [String]
        switch provider {
        case .claude:
            fetched = await fetchClaudeModels(apiKey: apiKey)
        case .openai:
            fetched = await fetchOpenAIModels(apiKey: apiKey)
        case .ollama, .custom:
            fetched = []
        }

        await MainActor.run {
            models = fetched
            isLoading = false
            lastProvider = provider
            lastAPIKey = apiKey
        }
    }

    func clearCache() {
        models = []
        lastProvider = nil
        lastAPIKey = nil
        error = nil
    }

    // MARK: - Anthropic

    private func fetchClaudeModels(apiKey: String) async -> [String] {
        guard let url = URL(string: "https://api.anthropic.com/v1/models?limit=100") else { return [] }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                await MainActor.run { error = "API error \(http.statusCode)" }
                return []
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArray = json["data"] as? [[String: Any]] else {
                return []
            }
            return dataArray
                .compactMap { $0["id"] as? String }
                .sorted()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
            return []
        }
    }

    // MARK: - OpenAI

    private static let openAIChatPrefixes = ["gpt-", "o1", "o3", "o4", "chatgpt-"]
    private static let openAIExcludePatterns = [
        "realtime", "audio", "search", "transcribe",
    ]

    private func fetchOpenAIModels(apiKey: String) async -> [String] {
        guard let url = URL(string: "https://api.openai.com/v1/models") else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                await MainActor.run { error = "API error \(http.statusCode)" }
                return []
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArray = json["data"] as? [[String: Any]] else {
                return []
            }
            return dataArray
                .compactMap { $0["id"] as? String }
                .filter { id in
                    // Only chat-capable models
                    Self.openAIChatPrefixes.contains { id.hasPrefix($0) }
                }
                .filter { id in
                    // Exclude non-chat variants
                    !id.contains(":") // fine-tuned
                        && !Self.openAIExcludePatterns.contains(where: { id.contains($0) })
                }
                .sorted()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
            return []
        }
    }
}
