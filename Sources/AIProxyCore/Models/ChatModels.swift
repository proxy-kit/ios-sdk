import Foundation

// MARK: - Provider Constants

/// Common AI provider names
public enum AIProvider: Equatable {
    case openai
    case anthropic
    case custom(String)

    public var rawValue: String {
        switch self {
        case .openai: return "openai"
        case .anthropic: return "anthropic"
        case .custom(let name): return name.lowercased()
        }
    }
}

// MARK: - Model Constants

/// OpenAI model names
public enum OpenAIModel: String {
    case gpt4 = "gpt-4"
    case gpt4Turbo = "gpt-4-turbo"
    case gpt4Vision = "gpt-4-vision-preview"
    case gpt35Turbo = "gpt-3.5-turbo"
    case gpt35Turbo16k = "gpt-3.5-turbo-16k"
}

/// Anthropic model names
public enum AnthropicModel: String {
    case claude3Opus = "claude-3-opus-20240229"
    case claude3Sonnet = "claude-3-sonnet-20240229"
    case claude3Haiku = "claude-3-haiku-20240307"
    case claude2 = "claude-2.1"
    case claudeInstant = "claude-instant-1.2"
}

/// Common chat models categorized by provider
public enum ChatModel: Equatable {
    case openai(OpenAIModel)
    case anthropic(AnthropicModel)
    case custom(provider: String, model: String)
    
    public var rawValue: String {
        switch self {
        case .openai(let model):
            return model.rawValue
        case .anthropic(let model):
            return model.rawValue
        case .custom(_, let model):
            return model
        }
    }

    public var provider: String {
        switch self {
        case .openai:
            return "openai"
        case .anthropic:
            return "anthropic"
        case .custom(let provider, _):
            return provider
        }
    }
}

// MARK: - Chat Messages

/// Role in a chat conversation
public enum MessageRole: String, Codable {
    case system
    case user
    case assistant
}

/// A message in a chat conversation
public struct ChatMessage: Codable {
    public let role: MessageRole
    public let content: String
    
    public init(role: MessageRole, content: String) {
        self.role = role
        self.content = content
    }
    
    /// Convenience factory methods
    public static func system(_ content: String) -> ChatMessage {
        ChatMessage(role: .system, content: content)
    }
    
    public static func user(_ content: String) -> ChatMessage {
        ChatMessage(role: .user, content: content)
    }
    
    public static func assistant(_ content: String) -> ChatMessage {
        ChatMessage(role: .assistant, content: content)
    }
}

// MARK: - Chat Request

/// Parameters for a chat completion request
public struct ChatRequest: Codable {
    public let model: String
    public let messages: [ChatMessage]
    public let temperature: Double?
    public let maxTokens: Int?
    public let stream: Bool
    
    public init(
        model: String,
        messages: [ChatMessage],
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        stream: Bool = false
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.stream = stream
    }
}

// MARK: - Chat Response

/// A chat completion response
public struct ChatResponse {
    public let id: String
    public let choices: [Choice]
    public let usage: Usage?
    
    public struct Choice {
        public let message: ChatMessage
        public let finishReason: String?
        public let index: Int
    }
    
    public struct Usage {
        public let promptTokens: Int
        public let completionTokens: Int
        public let totalTokens: Int
    }
}

// MARK: - Streaming

/// A chunk of a streaming chat response
public struct ChatStreamChunk {
    public let id: String
    public let delta: Delta
    public let finishReason: String?
    
    public struct Delta {
        public let content: String?
        public let role: MessageRole?
    }
}
