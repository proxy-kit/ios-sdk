import Foundation
import ProxyKitCore

/// OpenAI client with chat.completions API
public final class OpenAIClient {
    /// Access to chat completions API
    public let chat: OpenAIChatNamespace
    
    init(networkClient: NetworkClient, sessionManager: SessionManager, attestationManager: AttestationManager, logger: Logger) {
        self.chat = OpenAIChatNamespace(
            networkClient: networkClient,
            sessionManager: sessionManager,
            attestationManager: attestationManager,
            logger: logger
        )
    }
}

/// Anthropic client with chat.completions API
public final class AnthropicClient {
    /// Access to chat completions API
    public let chat: AnthropicChatNamespace
    
    init(networkClient: NetworkClient, sessionManager: SessionManager, attestationManager: AttestationManager, logger: Logger) {
        self.chat = AnthropicChatNamespace(
            networkClient: networkClient,
            sessionManager: sessionManager,
            attestationManager: attestationManager,
            logger: logger
        )
    }
}

/// OpenAI chat namespace
public final class OpenAIChatNamespace {
    /// Access to completions API
    public let completions: ChatCompletions
    
    init(networkClient: NetworkClient, sessionManager: SessionManager, attestationManager: AttestationManager, logger: Logger) {
        self.completions = ChatCompletions(
            networkClient: networkClient,
            sessionManager: sessionManager,
            attestationManager: attestationManager,
            provider: .openai,
            logger: logger
        )
    }
}

/// Anthropic chat namespace
public final class AnthropicChatNamespace {
    /// Access to completions API
    public let completions: ChatCompletions
    
    init(networkClient: NetworkClient, sessionManager: SessionManager, attestationManager: AttestationManager, logger: Logger) {
        self.completions = ChatCompletions(
            networkClient: networkClient,
            sessionManager: sessionManager,
            attestationManager: attestationManager,
            provider: .anthropic,
            logger: logger
        )
    }
}
