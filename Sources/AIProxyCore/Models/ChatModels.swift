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

/// Common model names for convenience
public enum ChatModel: Equatable {
    case gpt4
    case gpt4Turbo
    case gpt4Vision
    case gpt35Turbo
    case gpt35Turbo16k
    case claude3Opus
    case claude3Sonnet
    case claude3Haiku
    case claude2
    case claudeInstant
    case custom(String)

    public var rawValue: String {
        switch self {
        case .gpt4: return "gpt-4"
        case .gpt4Turbo: return "gpt-4-turbo"
        case .gpt4Vision: return "gpt-4-vision-preview"
        case .gpt35Turbo: return "gpt-3.5-turbo"
        case .gpt35Turbo16k: return "gpt-3.5-turbo-16k"
        case .claude3Opus: return "claude-3-opus-20240229"
        case .claude3Sonnet: return "claude-3-sonnet-20240229"
        case .claude3Haiku: return "claude-3-haiku-20240307"
        case .claude2: return "claude-2.1"
        case .claudeInstant: return "claude-instant-1.2"
        case .custom(let name): return name
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
