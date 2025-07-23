import XCTest

/// Main test suite entry point
/// Individual test files are organized by component:
/// - Unit/AIProxyTests.swift - Core SDK configuration tests
/// - Unit/SessionManagerTests.swift - Session management tests
/// - Unit/NetworkClientTests.swift - Network layer tests
/// - Unit/ChatProviderTests.swift - Chat API tests
/// - Integration/ChatIntegrationTests.swift - Full flow integration tests
final class AIProxyTestSuite: XCTestCase {
    func testSuiteInfo() {
        print("""
        AIProxy SDK Test Suite
        ======================
        
        Unit Tests:
        - AIProxy configuration and initialization
        - Session management with secure storage
        - Network client with error handling
        - Chat provider with streaming support
        
        Integration Tests:
        - Full attestation and chat flow
        - Session reuse
        - Error handling
        - Streaming responses
        
        Mock Objects:
        - MockSecureStorage - In-memory keychain
        - MockNetworkClient - Network response mocking
        - MockLogger - Log capture for testing
        - MockSessionManager - Session state mocking
        """)
    }
}
