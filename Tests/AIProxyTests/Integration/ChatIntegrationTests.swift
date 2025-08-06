import XCTest
@testable import AIProxy
@testable import ProxyKitCore

/// Integration tests that test the full flow of the SDK
/// These tests use mocks but test the real integration between components
/// Note: Real device attestation requires iOS device/simulator, so these tests
/// simulate the attestation flow with mocks
final class ChatIntegrationTests: XCTestCase {
    var mockServer: MockAPIServer!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Reset SDK
        AIProxy.reset()
        
        // Setup mock server
        mockServer = MockAPIServer()
        await mockServer.start()
        
        // Configure SDK with mock server
        try AIProxy.configure()
            .withAppId("test-app-123")
            .withEnvironment(.custom(mockServer.baseURL))
            .withLogLevel(.debug)
            .build()
    }
    
    override func tearDown() async throws {
        await mockServer.stop()
        AIProxy.reset()
        try await super.tearDown()
    }
    
    // MARK: - Full Flow Tests
    
    func testFullChatFlow_Success() async throws {
        // Given
        // Setup mock server responses
        mockServer.setupChallengeEndpoint(appId: "test-app-123")
        mockServer.setupVerifyEndpoint(sessionToken: "mock-session-token")
        mockServer.setupChatEndpoint(
            response: ChatResponse(
                id: "chat-123",
                choices: [
                    ChatResponse.Choice(
                        message: ChatMessage(role: .assistant, content: "Hello from mock!"),
                        finishReason: "stop",
                        index: 0
                    )
                ],
                usage: ChatResponse.Usage(
                    promptTokens: 10,
                    completionTokens: 20,
                    totalTokens: 30
                )
            )
        )
        
        // When
        let response = try await AIProxy.chat.completions.create(
            provider: "openai",
            model: "gpt-4",
            messages: [
                .system("You are a helpful assistant"),
                .user("Hello!")
            ],
            temperature: 0.7
        )
        
        // Then
        XCTAssertEqual(response.choices.count, 1)
        XCTAssertEqual(response.choices[0].message.content, "Hello from mock!")
        XCTAssertEqual(response.usage?.totalTokens, 30)
        
        // Verify the flow
        XCTAssertEqual(mockServer.requestLog.count, 3)
        XCTAssertTrue(mockServer.requestLog[0].path.contains("challenge"))
        XCTAssertTrue(mockServer.requestLog[1].path.contains("verify"))
        XCTAssertTrue(mockServer.requestLog[2].path.contains("chat"))
    }
    
    func testChatFlow_SessionReuse() async throws {
        // Given
        mockServer.setupChallengeEndpoint(appId: "test-app-123")
        mockServer.setupVerifyEndpoint(sessionToken: "mock-session-token")
        mockServer.setupChatEndpoint(
            response: ChatResponse(
                id: "chat-1",
                choices: [
                    ChatResponse.Choice(
                        message: ChatMessage(role: .assistant, content: "First response"),
                        finishReason: "stop",
                        index: 0
                    )
                ],
                usage: nil
            )
        )
        
        // When - First request (should trigger attestation)
        let response1 = try await AIProxy.chat.completions.create(
            model: .gpt4,
            messages: [.user("First message")]
        )
        
        // Update mock response for second request
        mockServer.setupChatEndpoint(
            response: ChatResponse(
                id: "chat-2",
                choices: [
                    ChatResponse.Choice(
                        message: ChatMessage(role: .assistant, content: "Second response"),
                        finishReason: "stop",
                        index: 0
                    )
                ],
                usage: nil
            )
        )
        
        // Second request (should reuse session)
        let response2 = try await AIProxy.chat.completions.create(
            model: .gpt4,
            messages: [.user("Second message")]
        )
        
        // Then
        XCTAssertEqual(response1.choices[0].message.content, "First response")
        XCTAssertEqual(response2.choices[0].message.content, "Second response")
        
        // Verify only one attestation flow
        let challengeRequests = mockServer.requestLog.filter { $0.path.contains("challenge") }
        let verifyRequests = mockServer.requestLog.filter { $0.path.contains("verify") }
        XCTAssertEqual(challengeRequests.count, 1, "Should only attestate once")
        XCTAssertEqual(verifyRequests.count, 1, "Should only verify once")
    }
    
    func testChatFlow_ErrorHandling() async throws {
        // Given
        mockServer.setupChallengeEndpoint(appId: "test-app-123")
        mockServer.setupVerifyEndpoint(sessionToken: "mock-session-token")
        mockServer.setupErrorResponse(
            path: "/v1/proxy/OPENAI/chat",
            statusCode: 429,
            headers: ["Retry-After": "60"]
        )
        
        // When/Then
        do {
            _ = try await AIProxy.chat.completions.create(
                model: .gpt4,
                messages: [.user("Test")]
            )
            XCTFail("Expected rate limit error")
        } catch AIProxyError.rateLimited(let retryAfter) {
            XCTAssertEqual(retryAfter, 60)
        } catch {
            XCTFail("Expected rate limit error, got: \(error)")
        }
    }
    
    func testStreamingChat_Success() async throws {
        // Given
        mockServer.setupChallengeEndpoint(appId: "test-app-123")
        mockServer.setupVerifyEndpoint(sessionToken: "mock-session-token")
        mockServer.setupStreamingChatEndpoint(chunks: [
            "Hello",
            " from",
            " streaming",
            " mock!"
        ])
        
        // When
        let stream = try await AIProxy.chat.completions.stream(
            model: .gpt4,
            messages: [.user("Hello streaming!")]
        )
        
        var fullContent = ""
        for try await chunk in stream {
            if let content = chunk.delta.content {
                fullContent += content
            }
        }
        
        // Then
        XCTAssertEqual(fullContent, "Hello from streaming mock!")
    }
}

// MARK: - Mock API Server

/// Simple mock server for integration testing
@available(iOS 13.0, *)
actor MockAPIServer {
    private var responses: [String: MockResponse] = [:]
    private(set) var requestLog: [LoggedRequest] = []
    let baseURL = URL(string: "http://localhost:8080")!
    
    struct MockResponse {
        let statusCode: Int
        let headers: [String: String]
        let body: Data
    }
    
    struct LoggedRequest {
        let path: String
        let method: String
        let headers: [String: String]
        let body: Data?
    }
    
    func start() async {
        // In a real implementation, this would start an HTTP server
        // For testing, we'll just prepare responses
        responses.removeAll()
        requestLog.removeAll()
    }
    
    func stop() async {
        responses.removeAll()
        requestLog.removeAll()
    }
    
    func setupChallengeEndpoint(appId: String) {
        let response = [
            "challenge": "mock-challenge-\(UUID().uuidString)",
            "expiresAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(300))
        ]
        let data = try! JSONEncoder().encode(response)
        responses["/v1/attestation/challenge"] = MockResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: data
        )
    }
    
    func setupVerifyEndpoint(sessionToken: String) {
        let response = [
            "sessionToken": sessionToken,
            "expiresAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
        ]
        let data = try! JSONEncoder().encode(response)
        responses["/v1/attestation/verify"] = MockResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: data
        )
    }
    
    func setupChatEndpoint(response: ChatResponse) {
        let data = try! JSONEncoder().encode(response)
        responses["/v1/proxy/OPENAI/chat"] = MockResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: data
        )
    }
    
    func setupStreamingChatEndpoint(chunks: [String]) {
        var streamData = ""
        for (index, chunk) in chunks.enumerated() {
            streamData += "data: {\"id\":\"\(index)\",\"content\":\"\(chunk)\"}\n\n"
        }
        streamData += "data: [DONE]\n\n"
        
        responses["/v1/proxy/OPENAI/chat"] = MockResponse(
            statusCode: 200,
            headers: ["Content-Type": "text/event-stream"],
            body: streamData.data(using: .utf8)!
        )
    }
    
    func setupErrorResponse(path: String, statusCode: Int, headers: [String: String] = [:]) {
        let errorBody = ["error": ["code": "test_error", "message": "Test error"]]
        let data = try! JSONEncoder().encode(errorBody)
        responses[path] = MockResponse(
            statusCode: statusCode,
            headers: headers.merging(["Content-Type": "application/json"]) { _, new in new },
            body: data
        )
    }
    
    // Log request for verification
    func logRequest(path: String, method: String, headers: [String: String], body: Data?) {
        requestLog.append(LoggedRequest(
            path: path,
            method: method,
            headers: headers,
            body: body
        ))
    }
}
