import Foundation

/// Main chat provider
public final class ChatProvider {
    private let networkClient: NetworkClient
    private let sessionManager: SessionManager
    private let attestationManager: AttestationManager
    private let provider: AIProvider
    private let logger: Logger
    
    /// Completions API
    public let completions: ChatCompletions
    
    public init(networkClient: NetworkClient, sessionManager: SessionManager, attestationManager: AttestationManager, provider: AIProvider, logger: Logger) {
        self.networkClient = networkClient
        self.sessionManager = sessionManager
        self.attestationManager = attestationManager
        self.provider = provider
        self.logger = logger
        self.completions = ChatCompletions(
            networkClient: networkClient,
            sessionManager: sessionManager,
            attestationManager: attestationManager,
            provider: provider,
            logger: logger
        )
    }
}

/// Chat completions API
public final class ChatCompletions {
    private let networkClient: NetworkClient
    private let sessionManager: SessionManager
    private let attestationManager: AttestationManager
    private let provider: AIProvider
    private let logger: Logger
    private let requestSigner: RequestSigner
    
    init(networkClient: NetworkClient, sessionManager: SessionManager, attestationManager: AttestationManager, provider: AIProvider, logger: Logger) {
        self.networkClient = networkClient
        self.sessionManager = sessionManager
        self.attestationManager = attestationManager
        self.provider = provider
        self.logger = logger
        self.requestSigner = RequestSigner(sessionManager: sessionManager, logger: logger)
    }
    
    /// Create a chat completion
    public func create(
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
        
        return try await performRequest(request, provider: provider.rawValue)
    }
    
    /// Create a chat completion with convenience overload using ChatModel enum
    public func create(
        model: ChatModel,
        messages: [ChatMessage],
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> ChatResponse {
        return try await create(
            model: model.rawValue,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }
    
    /// Create a streaming chat completion
    public func stream(
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
        
        return try await performStreamingRequest(request, provider: provider.rawValue)
    }
    
    /// Create a streaming chat completion with convenience overload using ChatModel enum
    public func stream(
        model: ChatModel,
        messages: [ChatMessage],
        temperature: Double? = nil,
        maxTokens: Int? = nil
    ) async throws -> AsyncThrowingStream<ChatStreamChunk, Error> {
        return try await stream(
            model: model.rawValue,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens
        )
    }
    
    private func performRequest(_ chatRequest: ChatRequest, provider: String) async throws -> ChatResponse {
        // Try to get session token, if expired, will throw sessionExpired error
        do {
            let token = try await sessionManager.getSessionToken()
            return try await executeRequest(chatRequest, provider: provider, token: token)
        } catch AIProxyError.sessionExpired {
            // Session expired, perform re-attestation
            logger.info("Session expired, performing re-attestation")
            
            // Clear the expired session
            await sessionManager.clearSession()
            
            // Perform new attestation
            try await attestationManager.performAttestation()
            
            // Get the new token
            let newToken = try await sessionManager.getSessionToken()
            
            // Retry the request with new token
            return try await executeRequest(chatRequest, provider: provider, token: newToken)
        }
    }
    
    private func executeRequest(_ chatRequest: ChatRequest, provider: String, token: String) async throws -> ChatResponse {
        // Get the current session to access keyId
        let session = try await sessionManager.getCurrentSession()
        
        // Create the request path and body
        let path = "/v1/proxy/\(provider.uppercased())/chat"
        
        // Use JSONEncoder with sorted keys for consistent hashing
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let body = try encoder.encode(chatRequest)
        
        // Sign the request if we have a keyId (iOS only)
        var headers = ["Authorization": "Bearer \(token)"]
        if let keyId = session.keyId {
            let signature = try await requestSigner.signRequest(
                method: "POST",
                path: path,
                body: body,
                keyId: keyId
            )
            
            // Add signature headers
            headers.merge(signature.headers) { _, new in new }
        }
        
        // Create the network request
        let networkRequest = NetworkRequest(
            path: path,
            method: .post,
            headers: headers,
            body: body
        )
        
        do {
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
        } catch AIProxyError.unauthorized {
            // If we get unauthorized even with a fresh token, throw sessionExpired
            // This will trigger re-attestation in the parent method
            throw AIProxyError.sessionExpired
        }
    }
    
    private func performStreamingRequest(_ chatRequest: ChatRequest, provider: String) async throws -> AsyncThrowingStream<ChatStreamChunk, Error> {
        // Try to get session token, if expired, will throw sessionExpired error
        do {
            let token = try await sessionManager.getSessionToken()
            return try await executeStreamingRequest(chatRequest, provider: provider, token: token)
        } catch AIProxyError.sessionExpired {
            // Session expired, perform re-attestation
            logger.info("Session expired, performing re-attestation")
            
            // Clear the expired session
            await sessionManager.clearSession()
            
            // Perform new attestation
            try await attestationManager.performAttestation()
            
            // Get the new token
            let newToken = try await sessionManager.getSessionToken()
            
            // Retry the request with new token
            return try await executeStreamingRequest(chatRequest, provider: provider, token: newToken)
        }
    }
    
    private func executeStreamingRequest(_ chatRequest: ChatRequest, provider: String, token: String) async throws -> AsyncThrowingStream<ChatStreamChunk, Error> {
        // Get the current session to access keyId
        let session = try await sessionManager.getCurrentSession()
        
        // Create the request path and body
        let path = "/v1/proxy/\(provider.uppercased())/chat"
        
        // Use JSONEncoder with sorted keys for consistent hashing
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let body = try encoder.encode(chatRequest)
        
        // Sign the request if we have a keyId (iOS only)
        var headers = ["Authorization": "Bearer \(token)"]
        if let keyId = session.keyId {
            let signature = try await requestSigner.signRequest(
                method: "POST",
                path: path,
                body: body,
                keyId: keyId
            )
            // Add signature headers
            headers.merge(signature.headers) { _, new in new }
        }
        
        // Create the network request
        let networkRequest = NetworkRequest(
            path: path,
            method: .post,
            headers: headers,
            body: body
        )
        
        // Get the stream
        let dataStream = try await networkClient.stream(networkRequest)
        
        // Transform the data stream to chat chunks
        return AsyncThrowingStream { continuation in
            Task {
                let parser = SSEParser()
                do {
                    for try await data in dataStream {
                        // Parse SSE events
                        let events = parser.parse(data)
                        
                        for event in events {
                            if event.isEndOfStream {
                                continuation.finish()
                                return
                            }
                            
                            // Try to parse as stream chunk
                            if let streamData = try? event.decode(StreamChunkResponse.self) {
                                let chunk = ChatStreamChunk(
                                    id: streamData.id ?? UUID().uuidString,
                                    delta: ChatStreamChunk.Delta(
                                        content: streamData.choices?.first?.delta?.content,
                                        role: streamData.choices?.first?.delta?.role.map { MessageRole(rawValue: $0) ?? .assistant }
                                    ),
                                    finishReason: streamData.choices?.first?.finishReason
                                )
                                continuation.yield(chunk)
                            }
                        }
                    }
                    continuation.finish()
                } catch AIProxyError.unauthorized {
                    // If we get unauthorized during streaming, finish with sessionExpired error
                    continuation.finish(throwing: AIProxyError.sessionExpired)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
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

private struct StreamChunkResponse: Codable {
    let id: String?
    let choices: [StreamChoice]?
    
    struct StreamChoice: Codable {
        let delta: StreamDelta?
        let finishReason: String?
        
        struct StreamDelta: Codable {
            let content: String?
            let role: String?
        }
    }
}

// MARK: - SSE Parser

/// Server-Sent Events (SSE) parser for streaming responses
private final class SSEParser {
    private var buffer = Data()
    private let decoder = JSONDecoder()
    
    /// Parse incoming data and yield SSE events
    func parse(_ data: Data) -> [SSEEvent] {
        buffer.append(data)
        
        var events: [SSEEvent] = []
        
        // Process buffer line by line
        while let lineRange = buffer.range(of: Data("\n\n".utf8)) {
            let eventData = buffer.subdata(in: 0..<lineRange.lowerBound)
            buffer.removeSubrange(0..<lineRange.upperBound)
            
            if let event = parseEvent(from: eventData) {
                events.append(event)
            }
        }
        
        // Also check for single newline boundaries
        var partialEvents: [SSEEvent] = []
        let lines = buffer.split(separator: UInt8(ascii: "\n"))
        
        for i in 0..<lines.count {
            if let event = parseLine(Data(lines[i])) {
                partialEvents.append(event)
                
                // Remove processed lines from buffer
                if i == lines.count - 1 {
                    // Keep last line in buffer if it doesn't end with newline
                    if buffer.last != UInt8(ascii: "\n") {
                        buffer = Data(lines[i])
                    } else {
                        buffer.removeAll()
                    }
                }
            }
        }
        
        return events + partialEvents
    }
    
    private func parseEvent(from data: Data) -> SSEEvent? {
        guard let string = String(data: data, encoding: .utf8) else { return nil }
        
        var eventType: String?
        var eventData: String?
        var eventId: String?
        var retry: Int?
        
        let lines = string.components(separatedBy: "\n")
        for line in lines {
            if line.isEmpty { continue }
            
            if line.hasPrefix("event:") {
                eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                let dataLine = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                if eventData == nil {
                    eventData = dataLine
                } else {
                    eventData! += "\n" + dataLine
                }
            } else if line.hasPrefix("id:") {
                eventId = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("retry:") {
                let retryString = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                retry = Int(retryString)
            }
        }
        
        if let data = eventData {
            return SSEEvent(
                type: eventType,
                data: data,
                id: eventId,
                retry: retry
            )
        }
        
        return nil
    }
    
    private func parseLine(_ data: Data) -> SSEEvent? {
        guard let string = String(data: data, encoding: .utf8) else { return nil }
        
        if string.hasPrefix("data:") {
            let dataContent = String(string.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            return SSEEvent(type: nil, data: dataContent, id: nil, retry: nil)
        }
        
        return nil
    }
    
    /// Reset the parser state
    func reset() {
        buffer.removeAll()
    }
}

/// Represents a Server-Sent Event
private struct SSEEvent {
    let type: String?
    let data: String
    let id: String?
    let retry: Int?
    
    /// Check if this is the end-of-stream marker
    var isEndOfStream: Bool {
        return data == "[DONE]"
    }
    
    /// Try to decode the data as a specific type
    func decode<T: Decodable>(_ type: T.Type) throws -> T? {
        guard !isEndOfStream else { return nil }
        guard let jsonData = data.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "SSE data is not valid UTF-8"
                )
            )
        }
        return try JSONDecoder().decode(type, from: jsonData)
    }
}
