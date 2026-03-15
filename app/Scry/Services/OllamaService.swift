import Combine
import Foundation

struct OllamaModel: Identifiable, Equatable {
    let name: String
    let supportsVision: Bool
    var id: String { name }
}

enum OllamaStatus: Equatable {
    case unknown
    case running
    case notRunning
    case error(String)

    var displayText: String {
        switch self {
        case .unknown: return "Checking..."
        case .running: return "Ollama is running"
        case .notRunning: return "Ollama is not running"
        case .error(let message): return "Error: \(message)"
        }
    }
}

final class OllamaService: ObservableObject {
    static let shared = OllamaService()

    @Published var availableModels: [OllamaModel] = []
    @Published var status: OllamaStatus = .unknown
    @Published var isLoading: Bool = false

    private let baseURL = Constants.AIConfig.ollamaBaseURL
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        session = URLSession(configuration: config)
    }

    func refreshModels() async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        guard let url = URL(string: "\(baseURL)/api/tags") else {
            await MainActor.run { status = .error("Invalid base URL") }
            return
        }

        do {
            let (data, _) = try await session.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let models = json["models"] as? [[String: Any]] else {
                await MainActor.run { status = .error("Unexpected response format") }
                return
            }

            var result: [OllamaModel] = []
            for model in models {
                guard let name = model["name"] as? String else { continue }
                let vision = await checkVisionSupport(modelName: name)
                result.append(OllamaModel(name: name, supportsVision: vision))
            }

            await MainActor.run {
                availableModels = result
                status = .running
            }
        } catch {
            await MainActor.run {
                availableModels = []
                if (error as NSError).code == NSURLErrorCannotConnectToHost
                    || (error as NSError).code == NSURLErrorTimedOut
                    || (error as NSError).code == NSURLErrorNetworkConnectionLost {
                    status = .notRunning
                } else {
                    status = .error(error.localizedDescription)
                }
            }
        }
    }

    /// Returns whether the selected model supports vision.
    func modelSupportsVision(_ modelName: String) -> Bool {
        availableModels.first { $0.name == modelName }?.supportsVision ?? false
    }

    // MARK: - Private

    private func checkVisionSupport(modelName: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/show") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["name": modelName])

        do {
            let (data, _) = try await session.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return false
            }
            // Check model_info for any key containing ".vision." — all vision models
            // (clip, mllama, qwen25vl, etc.) expose vision-related architecture keys.
            if let modelInfo = json["model_info"] as? [String: Any] {
                return modelInfo.keys.contains { $0.contains(".vision.") }
            }
            return false
        } catch {
            return false
        }
    }
}
