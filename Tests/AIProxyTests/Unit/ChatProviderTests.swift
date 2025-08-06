import XCTest
@testable import ProxyKitCore

final class ChatProviderTests: XCTestCase {
    var sut: ChatProvider!
    var mockNetworkClient: MockNetworkClient!
    var mockSessionManager: MockSessionManager!
    var mockLogger: MockLogger!
    
    override func setUp() {
        super.setUp()
        mockNetworkClient = MockNetworkClient()
        mockSessionManager = MockSessionManager()
        mockLogger = MockLogger()
        sut = ChatProvider(
            networkClient: mockNetworkClient,
            sessionManager: mockSessionManager,
            logger: mockLogger
        )
    }
    
    override func tearDown() {
        sut = nil
        mockNetworkClient = nil
        mockSessionManager = nil
        mockLogger = nil
        super.tearDown()
    }
    
    // MARK: - Create Completion Tests
    
    func testCreateCompletion_Success() async throws {
        // Given
        mockSessionManager.mockToken = "test-token"
        let mockResponse = ProxyResponse(
            id: "chat-123",
            choices: [
                ProxyResponse.Choice(
                    message: ProxyResponse.Choice.Message(
                        role: "assistant",
                        content: "Hello! How can I help you?"
                    ),
                    finishReason: "stop",
                    index: 0
                )
            ],
            usage: ProxyResponse.Usage(
                promptTokens: 10,
                completionTokens: 20,
                totalTokens: 30
            )
        )
        mockNetworkClient.mockResponse = mockResponse
        
        // When
        let response = try await sut.completions.create(
            provider: "openai",
            model: "gpt-4",
            messages: [
                .system("You are a helpful assistant"),
                .user("Hello!")
            ],
            temperature: 0.7,
            maxTokens: 100
        )
        
        // Then
        XCTAssertEqual(response.id, "chat-123")
        XCTAssertEqual(response.choices.count, 1)
        XCTAssertEqual(response.choices[0].message.content, "Hello! How can I help you?")
        XCTAssertEqual(response.choices[0].message.role, .assistant)
        XCTAssertEqual(response.usage?.totalTokens, 30)
        
        // Verify request
        XCTAssertEqual(mockNetworkClient.performCallCount, 1)
        XCTAssertEqual(mockNetworkClient.lastRequest?.path, "/v1/proxy/OPENAI/chat")
        XCTAssertEqual(mockNetworkClient.lastRequest?.method, .post)
        XCTAssertEqual(mockNetworkClient.lastRequest?.headers["Authorization"], "Bearer test-token")
    }
    
    func testCreateCompletion_NoSession() async {
        // Given
        mockSessionManager.shouldThrowError = true
        mockSessionManager.errorToThrow = AIProxyError.sessionExpired
        
        // When/Then
        do {
            _ = try await sut.completions.create(
                provider: "openai",
                model: "gpt-4",
                messages: [.user("Hello!")]
            )
            XCTFail("Expected session expired error")
        } catch {
            XCTAssertEqual(error as? AIProxyError, AIProxyError.sessionExpired)
        }
    }
    
    func testCreateCompletion_NetworkError() async {
        // Given
        mockSessionManager.mockToken = "test-token"
        mockNetworkClient.shouldThrowError = true
        mockNetworkClient.errorToThrow = AIProxyError.networkError(NSError(domain: "test", code: -1))
        
        // When/Then
        do {
            _ = try await sut.completions.create(
                provider: "openai",
                model: "gpt-4",
                messages: [.user("Hello!")]
            )
            XCTFail("Expected network error")
        } catch AIProxyError.networkError {
            // Expected
        } catch {
            XCTFail("Expected network error, got: \(error)")
        }
    }
    
    func testCreateCompletion_DifferentProviders() async throws {
        // Given
        mockSessionManager.mockToken = "test-token"
        mockNetworkClient.mockResponse = ProxyResponse(
            id: "test",
            choices: [],
            usage: nil
        )
        
        // Test OpenAI provider
        _ = try await sut.completions.create(
            provider: "openai",
            model: "gpt-4",
            messages: [.user("Test")]
        )
        XCTAssertEqual(mockNetworkClient.lastRequest?.path, "/v1/proxy/OPENAI/chat")
        
        // Test Anthropic provider
        _ = try await sut.completions.create(
            provider: "anthropic",
            model: "claude-3-opus-20240229",
            messages: [.user("Test")]
        )
        XCTAssertEqual(mockNetworkClient.lastRequest?.path, "/v1/proxy/ANTHROPIC/chat")
        
        // Test custom provider
        _ = try await sut.completions.create(
            provider: "custom-ai",
            model: "custom-model-v1",
            messages: [.user("Test")]
        )
        XCTAssertEqual(mockNetworkClient.lastRequest?.path, "/v1/proxy/CUSTOM-AI/chat")
    }
    
    // MARK: - Stream Completion Tests
    
    func testStreamCompletion_Success() async throws {
        // Given
        mockSessionManager.mockToken = "test-token"
        let streamData = """
        data: {"id":"1","content":"Hello"}\n
        data: {"id":"2","content":" World"}\n
        data: [DONE]\n
        """.data(using: .utf8)!
        mockNetworkClient.mockResponse = streamData
        
        // When
        let stream = try await sut.completions.stream(
            provider: "openai",
            model: "gpt-4",
            messages: [.user("Hello!")]
        )
        
        var chunks: [ChatStreamChunk] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }
        
        // Then
        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(chunks[0].delta.content, "Hello")
        XCTAssertEqual(chunks[1].delta.content, " World")
        
        // Verify request
        XCTAssertEqual(mockNetworkClient.streamCallCount, 1)
        XCTAssertNotNil(mockNetworkClient.lastRequest?.body)
        
        // Decode request body to verify stream flag
        if let requestBody = mockNetworkClient.lastRequest?.body,
           let request = try? JSONDecoder().decode(ChatRequest.self, from: requestBody) {
            XCTAssertTrue(request.stream)
        } else {
            XCTFail("Failed to decode request body")
        }
    }
}

// MARK: - Mock Session Manager

class MockSessionManager: SessionManager {
    var mockToken: String?
    var shouldThrowError = false
    var errorToThrow: Error = AIProxyError.sessionExpired
    var getTokenCallCount = 0
    
    init() {
        super.init(
            storage: MockSecureStorage(),
            networkClient: MockNetworkClient(),
            logger: MockLogger()
        )
    }
    
    override func getSessionToken() async throws -> String {
        getTokenCallCount += 1
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        guard let token = mockToken else {
            throw AIProxyError.sessionExpired
        }
        
        return token
    }
    
    override var hasValidSession: Bool {
        mockToken != nil && !shouldThrowError
    }
}

// MARK: - Internal Response Model for Testing

struct ProxyResponse: Codable {
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
