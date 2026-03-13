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

    func search(query: String) async throws -> [SearchResult] {
        guard let image = screenshotImage else {
            return []
        }

        let response = llmService.analyzeImage(image, query: query.isEmpty ? nil : query)

        await MainActor.run {
            self.currentResponse = response
        }

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
