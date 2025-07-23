import Foundation

// MARK: - Provider Constants

/// Common AI provider names
public struct AIProvider {
    public static let openai = "openai"
    public static let anthropic = "anthropic"
    
    // Allow any string for forward compatibility
    public let rawValue: String
    
    public init(_ provider: String) {
        self.rawValue = provider.lowercased()
    }
}

// MARK: - Model Constants

/// Common model names for convenience
public struct ChatModel {
    // OpenAI Models
    public static let gpt4 = "gpt-4"
    public static let gpt4Turbo = "gpt-4-turbo"
    public static let gpt4Vision = "gpt-4-vision-preview"
    public static let gpt35Turbo = "gpt-3.5-turbo"
    public static let gpt35Turbo16k = "gpt-3.5-turbo-16k"
    
    // Anthropic Models  
    public static let claude3Opus = "claude-3-opus-20240229"
    public static let claude3Sonnet = "claude-3-sonnet-20240229"
    public static let claude3Haiku = "claude-3-haiku-20240307"
    public static let claude2 = "claude-2.1"
    public static let claudeInstant = "claude-instant-1.2"
    
    // The actual model string
    public let rawValue: String
    
    public init(_ model: String) {
        self.rawValue = model
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