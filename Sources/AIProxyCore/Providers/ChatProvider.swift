import Foundation

/// Main chat provider
public final class ChatProvider {
    private let networkClient: NetworkClient
    private let sessionManager: SessionManager
    private let logger: Logger
    
    /// Completions API
    public let completions: ChatCompletions
    
    public init(networkClient: NetworkClient, sessionManager: SessionManager, logger: Logger) {
        self.networkClient = networkClient
        self.sessionManager = sessionManager
        self.logger = logger
        self.completions = ChatCompletions(
            networkClient: networkClient,
            sessionManager: sessionManager,
            logger: logger
        )
    }
}

/// Chat completions API
public final class ChatCompletions {
    private let networkClient: NetworkClient
    private let sessionManager: SessionManager
    private let logger: Logger
    
    init(networkClient: NetworkClient, sessionManager: SessionManager, logger: Logger) {
        self.networkClient = networkClient
        self.sessionManager = sessionManager
        self.logger = logger
    }
    
    /// Create a chat completion
    public func create(
        provider: String,
        model: String,
        messages: [ChatMessage],
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> ChatResponse {
        let request = ChatRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens,
            stream: false
        )
        
        return try await performRequest(request, provider: provider)
    }
    
    /// Create a chat completion with convenience overload using constants
    public func create(
        provider: AIProvider = AIProvider(AIProvider.openai),
        model: ChatModel,
        messages: [ChatMessage],
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> ChatResponse {
        return try await create(
            provider: provider.rawValue,
            model: model.rawValue,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }
    
    /// Create a streaming chat completion
    public func stream(
        provider: String,
        model: String,
        messages: [ChatMessage],
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> AsyncThrowingStream<ChatStreamChunk, Error> {
        let request = ChatRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens,
            stream: true
        )
        
        return try await performStreamingRequest(request, provider: provider)
    }
    
    /// Create a streaming chat completion with convenience overload
    public func stream(
        provider: AIProvider = AIProvider(AIProvider.openai),
        model: ChatModel,
        messages: [ChatMessage],
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> AsyncThrowingStream<ChatStreamChunk, Error> {
        return try await stream(
            provider: provider.rawValue,
            model: model.rawValue,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }
    
    private func performRequest(_ chatRequest: ChatRequest, provider: String) async throws -> ChatResponse {
        // Ensure we have a valid session
        let token = try await sessionManager.getSessionToken()
        
        // Create the network request
        let networkRequest = NetworkRequest(
            path: "/v1/proxy/\(provider.uppercased())/chat",
            method: .post,
            headers: ["Authorization": "Bearer \(token)"],
            body: try JSONEncoder().encode(chatRequest)
        )
        
        // Make the request
        let response = try await networkClient.perform(
            networkRequest,
            responseType: ProxyResponse.self
        )
        
        // Convert from proxy response to public response
        return ChatResponse(
            id: response.id,
            choices: response.choices.map { choice in
                ChatResponse.Choice(
                    message: ChatMessage(
                        role: MessageRole(rawValue: choice.message.role) ?? .assistant,
                        content: choice.message.content
                    ),
                    finishReason: choice.finishReason,
                    index: choice.index ?? 0
                )
            },
            usage: response.usage.map { usage in
                ChatResponse.Usage(
                    promptTokens: usage.promptTokens,
                    completionTokens: usage.completionTokens,
                    totalTokens: usage.totalTokens
                )
            }
        )
    }
    
    private func performStreamingRequest(_ chatRequest: ChatRequest, provider: String) async throws -> AsyncThrowingStream<ChatStreamChunk, Error> {
        // Ensure we have a valid session
        let token = try await sessionManager.getSessionToken()
        
        // Create the network request
        let networkRequest = NetworkRequest(
            path: "/v1/proxy/\(provider.uppercased())/chat",
            method: .post,
            headers: ["Authorization": "Bearer \(token)"],
            body: try JSONEncoder().encode(chatRequest)
        )
        
        // Get the stream
        let dataStream = try await networkClient.stream(networkRequest)
        
        // Transform the data stream to chat chunks
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await data in dataStream {
                        // Parse SSE data
                        if let chunk = parseSSEData(data) {
                            continuation.yield(chunk)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func parseSSEData(_ data: Data) -> ChatStreamChunk? {
        guard let string = String(data: data, encoding: .utf8) else { return nil }
        
        // Simple SSE parser - in production would be more robust
        let lines = string.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                if jsonString == "[DONE]" {
                    return nil
                }
                
                if let jsonData = jsonString.data(using: .utf8),
                   let json = try? JSONDecoder().decode(StreamChunkData.self, from: jsonData) {
                    return ChatStreamChunk(
                        id: json.id ?? UUID().uuidString,
                        delta: ChatStreamChunk.Delta(
                            content: json.content,
                            role: nil
                        ),
                        finishReason: nil
                    )
                }
            }
        }
        
        return nil
    }
}

// MARK: - Internal Response Models

private struct ProxyResponse: Codable {
    let id: String
    let choices: [Choice]
    let usage: Usage?
    
    struct Choice: Codable {
        let message: Message
        let finishReason: String?
        let index: Int?
        
        struct Message: Codable {
            let role: String
            let content: String
        }
    }
    
    struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
    }
}

private struct StreamChunkData: Codable {
    let id: String?
    let content: String?
}