import XCTest
import Vision
@testable import Scry

final class AIProviderTests: XCTestCase {

    // MARK: - AIProviderType

    func testAIProviderTypeDisplayNames() {
        for provider in AIProviderType.allCases {
            XCTAssertFalse(provider.displayName.isEmpty)
        }
    }

    func testAIProviderTypeDefaultModels() {
        XCTAssertEqual(AIProviderType.claude.defaultModel, Constants.AIConfig.defaultClaudeModel)
        XCTAssertEqual(AIProviderType.openai.defaultModel, Constants.AIConfig.defaultOpenAIModel)
        XCTAssertFalse(AIProviderType.custom.defaultModel.isEmpty)
    }

    func testAIProviderTypeDefaultEndpoints() {
        XCTAssertTrue(AIProviderType.claude.defaultEndpoint.contains("anthropic.com"))
        XCTAssertTrue(AIProviderType.openai.defaultEndpoint.contains("openai.com"))
        XCTAssertTrue(AIProviderType.custom.defaultEndpoint.isEmpty)
    }

    func testAIProviderTypeCodable() throws {
        for provider in AIProviderType.allCases {
            let data = try JSONEncoder().encode(provider)
            let decoded = try JSONDecoder().decode(AIProviderType.self, from: data)
            XCTAssertEqual(provider, decoded)
        }
    }

    // MARK: - LLMService

    func testLLMServiceSystemPrompt() {
        XCTAssertFalse(LLMService.systemPrompt.isEmpty)
        XCTAssertTrue(LLMService.systemPrompt.contains("Scry"))
    }

    // MARK: - OCR Word Finding

    func testFindWordNearestCenterWithEmptyObservations() {
        let result = OCRService.findWordNearestCenter(observations: [])
        XCTAssertNil(result)
    }

    // MARK: - AISearchProvider

    func testAISearchProviderProperties() {
        let provider = AISearchProvider()
        XCTAssertEqual(provider.id, "ai")
        XCTAssertEqual(provider.name, "AI")
        XCTAssertTrue(provider.supportsNativeRendering)
        XCTAssertFalse(provider.iconSymbolName.isEmpty)
    }

    // MARK: - Constants

    func testScreenshotConstants() {
        XCTAssertGreaterThan(Constants.Screenshot.defaultRegionSize, 0)
        XCTAssertGreaterThanOrEqual(Constants.Screenshot.defaultRegionSize, Constants.Screenshot.minRegionSize)
        XCTAssertLessThanOrEqual(Constants.Screenshot.defaultRegionSize, Constants.Screenshot.maxRegionSize)
    }

    func testAIConstants() {
        XCTAssertFalse(Constants.AIConfig.defaultClaudeModel.isEmpty)
        XCTAssertFalse(Constants.AIConfig.defaultOpenAIModel.isEmpty)
        XCTAssertTrue(Constants.AIConfig.claudeEndpoint.contains("anthropic.com"))
        XCTAssertTrue(Constants.AIConfig.openAIEndpoint.contains("openai.com"))
        XCTAssertGreaterThan(Constants.AIConfig.maxTokens, 0)
    }
}
