import CoreGraphics
import Foundation

final class AISearchProvider: SearchProvider {
    let id = "ai"
    let name = "AI"
    let iconSymbolName = "sparkles"
    let supportsNativeRendering = true

    /// Set by AppDelegate before triggering search.
    var screenshotImage: CGImage?

    /// The current streaming response, observed by AIResultView.
    private(set) var currentResponse: LLMStreamingResponse?

    private let llmService = LLMService()

    /// Starts analysis and returns the streaming response immediately (no waiting).
    func startAnalysis(query: String) -> LLMStreamingResponse {
        let userQuery = query.isEmpty ? nil : query
        let response = llmService.analyzeImage(screenshotImage, query: userQuery)
        currentResponse = response
        return response
    }

    func search(query: String) async throws -> [SearchResult] {
        let response = startAnalysis(query: query)

        // Wait for the stream to complete
        while !response.isComplete {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }

        if let error = response.error {
            return [SearchResult(title: "Error", snippet: error, url: nil, imageURL: nil)]
        }

        return [SearchResult(title: "AI Analysis", snippet: response.text, url: nil, imageURL: nil)]
    }
}
