import Foundation
import AIProxy
@_exported import AIProxyCore

/// ProxyKit - A per-instance contextual chat interface over AIProxy
public final class ProxyKit {
    public struct ChatOverrides {
        public var model: ChatModel?
        public var systemPrompt: String?
        public init(model: ChatModel? = nil, systemPrompt: String? = nil) {
            self.model = model
            self.systemPrompt = systemPrompt
        }
    }
    
    private var messages: [ChatMessage]
    private let defaultSystemPrompt: String
    private let defaultModel: ChatModel

    /// Create a new ProxyKit chat context
    /// - Parameters:
    ///   - systemPrompt: The initial system prompt (default: "You are a helpful assistant")
    ///   - model: The default chat model to use (default: .gpt4)
    public init(
        model: ChatModel = .openai(.gpt4),
        systemPrompt: String = "You are a helpful assistant"
    ) {
        self.defaultSystemPrompt = systemPrompt
        self.defaultModel = model
        self.messages = []
    }

    /// Send a message, maintaining context within this ProxyKit instance
    /// - Parameters:
    ///   - message: The user's message
    ///   - overrides: Optional overrides for the chat model and system prompt for this call
    /// - Returns: The assistant's reply
    @discardableResult
    public func chat(
        message: String,
        overrides: ChatOverrides = ChatOverrides()
    ) async throws -> String {
        let model = overrides.model ?? defaultModel

        // Add system prompt if starting a new session
        if messages.isEmpty {
            let prompt = overrides.systemPrompt ?? defaultSystemPrompt
            messages.append(.system(prompt))
        }

        // Add the current user message
        messages.append(.user(message))

        let response = try await AIProxy.chat.completions.create(
            provider: model.provider,
            model: model.rawValue,
            messages: messages
        )

        guard let assistantMessage = response.choices.first?.message.content else {
            throw AIProxyError.providerError(code: "no_response", message: "No assistant message received.")
        }

        // Update conversation context
        messages.append(.assistant(assistantMessage))
        
        return assistantMessage
    }

    /// Reset the conversation context for this ProxyKit instance
    public func reset() {
        messages.removeAll()
    }

    /// Global configuration for ProxyKit (forwards to AIProxy)
    /// - Parameter appid: The application ID required for configuration
    public static func configure(appid: String) -> Error? {
        do {
            try AIProxy.configure()
                .withAppId(appid)
                .build()
            return nil
        }
        catch {
            return error
        }
    }
}
