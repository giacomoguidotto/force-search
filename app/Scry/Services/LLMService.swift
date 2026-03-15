import AppKit
import Combine
import Foundation

final class LLMStreamingResponse: ObservableObject {
    @Published var text: String = ""
    @Published var isComplete: Bool = false
    @Published var error: String?

    fileprivate var task: Task<Void, Never>?

    func cancel() {
        task?.cancel()
        task = nil
    }
}

final class LLMService {
    private let debugLog = DebugLogStore.shared

    static let systemPrompt = """
        You are a helpful assistant embedded in a macOS app called Scry. The user \
        force-clicked on something on their screen and you are seeing a screenshot of \
        the region around their cursor. If the screenshot contains text, explain its \
        meaning or provide useful context. If it shows a UI element, icon, or image, \
        describe what you see. Be concise and helpful. Respond in 2-4 sentences.
        """

    /// Starts a streaming LLM analysis, optionally including a screenshot.
    func analyzeImage(_ image: CGImage?, query: String? = nil) -> LLMStreamingResponse {
        let response = LLMStreamingResponse()
        let settings = AppSettings.shared

        let providerType = settings.aiProviderType

        if providerType != .ollama, settings.aiAPIKey.isEmpty {
            response.error = "No API key configured. Open Preferences → AI to set one."
            response.isComplete = true
            return response
        }

        // Encode image when available; skip for text-only Ollama models or nil image
        let imageData: String?
        if let image = image {
            imageData = jpegBase64(from: image)
        } else {
            imageData = nil
        }

        let model = settings.aiModel
        let apiKey = settings.aiAPIKey

        guard let url = URL(string: endpointURL(for: providerType, settings: settings)) else {
            response.error = "Invalid endpoint URL."
            response.isComplete = true
            return response
        }

        let userPrompt = query ?? "What is this?"

        response.task = Task {
            do {
                let request = try buildRequest(RequestConfig(
                    url: url,
                    providerType: providerType,
                    model: model,
                    apiKey: apiKey,
                    imageBase64: imageData,
                    userPrompt: userPrompt
                ))

                let (bytes, httpResponse) = try await URLSession.shared.bytes(for: request)

                if let http = httpResponse as? HTTPURLResponse, http.statusCode != 200 {
                    var body = ""
                    for try await line in bytes.lines {
                        body += line
                        if body.count > 500 { break }
                    }
                    await MainActor.run {
                        response.error = "API error \(http.statusCode): \(body)"
                        response.isComplete = true
                    }
                    return
                }

                for try await line in bytes.lines {
                    if Task.isCancelled { break }
                    if let text = parseSSELine(line, providerType: providerType) {
                        await MainActor.run {
                            response.text += text
                        }
                    }
                }

                await MainActor.run {
                    response.isComplete = true
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        response.error = error.localizedDescription
                        response.isComplete = true
                    }
                }
            }
        }

        return response
    }

    // MARK: - Endpoint Resolution

    private func endpointURL(for provider: AIProviderType, settings: AppSettings) -> String {
        switch provider {
        case .claude: return Constants.AIConfig.claudeEndpoint
        case .openai: return Constants.AIConfig.openAIEndpoint
        case .ollama: return Constants.AIConfig.ollamaEndpoint
        case .custom: return settings.aiCustomEndpoint
        }
    }

    // MARK: - Request Building

    private struct RequestConfig {
        let url: URL
        let providerType: AIProviderType
        let model: String
        let apiKey: String
        let imageBase64: String?
        let userPrompt: String
    }

    private func buildRequest(_ config: RequestConfig) throws -> URLRequest {
        var request = URLRequest(url: config.url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Set auth headers
        switch config.providerType {
        case .claude:
            request.setValue(config.apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .ollama:
            break // No auth header for local Ollama
        case .openai, .custom:
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }

        // Build request body
        let body: Data
        switch config.providerType {
        case .claude:
            let payload: [String: Any] = [
                "model": config.model,
                "max_tokens": Constants.AIConfig.maxTokens,
                "stream": true,
                "system": Self.systemPrompt,
                "messages": [
                    [
                        "role": "user",
                        "content": [
                            [
                                "type": "image",
                                "source": [
                                    "type": "base64",
                                    "media_type": "image/jpeg",
                                    "data": config.imageBase64 ?? "",
                                ],
                            ],
                            [
                                "type": "text",
                                "text": config.userPrompt,
                            ],
                        ],
                    ],
                ],
            ]
            body = try JSONSerialization.data(withJSONObject: payload)

        case .openai, .ollama, .custom:
            var userContent: Any
            if let imageBase64 = config.imageBase64 {
                userContent = [
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/jpeg;base64,\(imageBase64)",
                        ],
                    ],
                    [
                        "type": "text",
                        "text": config.userPrompt,
                    ],
                ] as [[String: Any]]
            } else {
                userContent = config.userPrompt
            }

            let payload: [String: Any] = [
                "model": config.model,
                "max_tokens": Constants.AIConfig.maxTokens,
                "stream": true,
                "messages": [
                    [
                        "role": "system",
                        "content": Self.systemPrompt,
                    ],
                    [
                        "role": "user",
                        "content": userContent,
                    ],
                ],
            ]
            body = try JSONSerialization.data(withJSONObject: payload)
        }

        request.httpBody = body
        return request
    }

    // MARK: - SSE Parsing

    private func parseSSELine(_ line: String, providerType: AIProviderType) -> String? {
        guard line.hasPrefix("data: ") else { return nil }
        let jsonStr = String(line.dropFirst(6))

        if jsonStr == "[DONE]" { return nil }

        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        switch providerType {
        case .claude:
            // Anthropic: {"type":"content_block_delta","delta":{"type":"text_delta","text":"..."}}
            if let delta = json["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                return text
            }
        case .openai, .ollama, .custom:
            // OpenAI-compatible: {"choices":[{"delta":{"content":"..."}}]}
            if let choices = json["choices"] as? [[String: Any]],
               let delta = choices.first?["delta"] as? [String: Any],
               let content = delta["content"] as? String {
                return content
            }
        }

        return nil
    }

    // MARK: - Image Encoding

    private func jpegBase64(from cgImage: CGImage) -> String? {
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        guard let tiff = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return nil
        }
        return jpeg.base64EncodedString()
    }
}
