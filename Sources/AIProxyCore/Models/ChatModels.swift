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

/// Detail level for images
public enum ImageDetail: String, Codable {
    case auto
    case low
    case high
}

/// Content part of a multi-modal message
public enum ContentPart: Codable {
    case text(String)
    case imageUrl(url: String, detail: ImageDetail?)
    case imageBase64(data: String, mimeType: String)
    
    // Custom encoding/decoding for proper JSON structure
    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageUrl = "image_url"
    }
    
    private enum ImageUrlKeys: String, CodingKey {
        case url
        case detail
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
            
        case .imageUrl(let url, let detail):
            try container.encode("image_url", forKey: .type)
            var imageUrlContainer = container.nestedContainer(keyedBy: ImageUrlKeys.self, forKey: .imageUrl)
            try imageUrlContainer.encode(url, forKey: .url)
            if let detail = detail {
                try imageUrlContainer.encode(detail, forKey: .detail)
            }
            
        case .imageBase64(let data, let mimeType):
            try container.encode("image_url", forKey: .type)
            var imageUrlContainer = container.nestedContainer(keyedBy: ImageUrlKeys.self, forKey: .imageUrl)
            let dataUrl = "data:\(mimeType);base64,\(data)"
            try imageUrlContainer.encode(dataUrl, forKey: .url)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
            
        case "image_url":
            let imageUrlContainer = try container.nestedContainer(keyedBy: ImageUrlKeys.self, forKey: .imageUrl)
            let url = try imageUrlContainer.decode(String.self, forKey: .url)
            let detail = try imageUrlContainer.decodeIfPresent(ImageDetail.self, forKey: .detail)
            
            // Check if it's a data URL
            if url.hasPrefix("data:") {
                // Extract MIME type and base64 data
                let components = url.components(separatedBy: ";base64,")
                if components.count == 2 {
                    let mimeType = components[0].replacingOccurrences(of: "data:", with: "")
                    let data = components[1]
                    self = .imageBase64(data: data, mimeType: mimeType)
                } else {
                    self = .imageUrl(url: url, detail: detail)
                }
            } else {
                self = .imageUrl(url: url, detail: detail)
            }
            
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown content type: \(type)")
        }
    }
}

/// Message content that can be either a string or an array of content parts
public enum MessageContent: Codable {
    case string(String)
    case parts([ContentPart])
    
    // Automatic encoding/decoding based on content
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let text):
            try container.encode(text)
        case .parts(let parts):
            try container.encode(parts)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .string(text)
        } else if let parts = try? container.decode([ContentPart].self) {
            self = .parts(parts)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Content must be either a string or an array of content parts")
        }
    }
    
    /// Convenience initializers
    public static func text(_ text: String) -> MessageContent {
        .string(text)
    }
    
    public static func multiModal(_ parts: [ContentPart]) -> MessageContent {
        .parts(parts)
    }
}

/// A message in a chat conversation
public struct ChatMessage: Codable {
    public let role: MessageRole
    public let content: MessageContent
    
    public init(role: MessageRole, content: MessageContent) {
        self.role = role
        self.content = content
    }
    
    /// Convenience initializer for string content
    public init(role: MessageRole, content: String) {
        self.role = role
        self.content = .string(content)
    }
    
    /// Convenience initializer for multi-modal content
    public init(role: MessageRole, content: [ContentPart]) {
        self.role = role
        self.content = .parts(content)
    }
    
    /// Convenience factory methods
    public static func system(_ content: String) -> ChatMessage {
        ChatMessage(role: .system, content: content)
    }
    
    public static func user(_ content: String) -> ChatMessage {
        ChatMessage(role: .user, content: content)
    }
    
    public static func user(_ content: [ContentPart]) -> ChatMessage {
        ChatMessage(role: .user, content: content)
    }
    
    public static func assistant(_ content: String) -> ChatMessage {
        ChatMessage(role: .assistant, content: content)
    }
    
    public static func assistant(_ content: [ContentPart]) -> ChatMessage {
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
