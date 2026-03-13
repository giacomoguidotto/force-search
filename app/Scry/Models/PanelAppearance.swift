import Foundation
import AppKit

enum Theme: String, CaseIterable, Codable {
    case system
    case light
    case dark

    var appearanceName: NSAppearance.Name? {
        switch self {
        case .system: return nil
        case .light: return .aqua
        case .dark: return .darkAqua
        }
    }
}

enum LinkTarget: String, CaseIterable, Codable {
    case defaultBrowser
    case safari
    case chrome

    var displayName: String {
        switch self {
        case .defaultBrowser: return "Default Browser"
        case .safari: return "Safari"
        case .chrome: return "Google Chrome"
        }
    }

    var bundleIdentifier: String? {
        switch self {
        case .defaultBrowser: return nil
        case .safari: return "com.apple.Safari"
        case .chrome: return "com.google.Chrome"
        }
    }
}

enum AIProviderType: String, CaseIterable, Codable {
    case claude
    case openai
    case custom

    var displayName: String {
        switch self {
        case .claude: return "Claude (Anthropic)"
        case .openai: return "OpenAI"
        case .custom: return "Custom (OpenAI-compatible)"
        }
    }

    var defaultModel: String {
        switch self {
        case .claude: return Constants.AIConfig.defaultClaudeModel
        case .openai: return Constants.AIConfig.defaultOpenAIModel
        case .custom: return Constants.AIConfig.defaultOpenAIModel
        }
    }

    var defaultEndpoint: String {
        switch self {
        case .claude: return Constants.AIConfig.claudeEndpoint
        case .openai: return Constants.AIConfig.openAIEndpoint
        case .custom: return ""
        }
    }
}

enum MenuBarIconStyle: String, CaseIterable, Codable {
    case magnifyingGlass
    case spark
    case text

    var symbolName: String {
        switch self {
        case .magnifyingGlass: return "magnifyingglass"
        case .spark: return "sparkle.magnifyingglass"
        case .text: return "character.cursor.ibeam"
        }
    }
}
