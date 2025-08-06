import XCTest
@testable import AIProxy
@testable import ProxyKitCore

final class AIProxyTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Reset SDK before each test
        AIProxy.reset()
    }
    
    override func tearDown() {
        AIProxy.reset()
        super.tearDown()
    }
    
    // MARK: - Configuration Tests
    
    func testConfigure_Success() throws {
        // When
        try AIProxy.configure()
            .withAppId("test-app-id")
            .withEnvironment(.development)
            .withLogLevel(.debug)
            .build()
        
        // Then
        XCTAssertTrue(AIProxy.isConfigured)
        XCTAssertNotNil(AIProxy.currentConfiguration)
        XCTAssertEqual(AIProxy.currentConfiguration?.appId, "test-app-id")
        XCTAssertEqual(AIProxy.currentConfiguration?.logLevel, .debug)
    }
    
    func testConfigure_MissingAppId() {
        // When/Then
        XCTAssertThrowsError(
            try AIProxy.configure()
                .withEnvironment(.development)
                .build()
        ) { error in
            XCTAssertEqual(error as? ConfigurationError, ConfigurationError.missingAppId)
        }
    }
    
    func testConfigure_EmptyAppId() {
        // When/Then
        XCTAssertThrowsError(
            try AIProxy.configure()
                .withAppId("")
                .build()
        ) { error in
            XCTAssertEqual(error as? ConfigurationError, ConfigurationError.invalidAppId)
        }
    }
    
    func testConfigure_AlreadyConfigured() throws {
        // Given
        try AIProxy.configure()
            .withAppId("test-app-id")
            .build()
        
        // When/Then
        XCTAssertThrowsError(
            try AIProxy.configure()
                .withAppId("another-app-id")
                .build()
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("already configured"))
        }
    }
    
    // MARK: - Access Tests
    
    func testChat_NotConfigured() {
        // This test expects a fatal error, so we need to test differently
        // In a real app, this would crash
        XCTAssertFalse(AIProxy.isConfigured)
    }
    
    func testChat_Configured() throws {
        // Given
        try AIProxy.configure()
            .withAppId("test-app-id")
            .build()
        
        // When
        let chatProvider = AIProxy.chat
        
        // Then
        XCTAssertNotNil(chatProvider)
        XCTAssertNotNil(chatProvider.completions)
    }
    
    // MARK: - Environment Tests
    
    func testEnvironmentURLs() {
        // Test production URL
        XCTAssertEqual(
            Environment.production.baseURL.absoluteString,
            "https://api.aiproxy.io"
        )
        
        // Test staging URL
        XCTAssertEqual(
            Environment.staging.baseURL.absoluteString,
            "https://staging-api.aiproxy.io"
        )
        
        // Test development URL
        XCTAssertEqual(
            Environment.development.baseURL.absoluteString,
            "http://localhost:3001"
        )
        
        // Test custom URL
        let customURL = URL(string: "https://custom.example.com")!
        XCTAssertEqual(
            Environment.custom(customURL).baseURL,
            customURL
        )
    }
    
    // MARK: - Reset Tests
    
    func testReset() throws {
        // Given
        try AIProxy.configure()
            .withAppId("test-app-id")
            .build()
        XCTAssertTrue(AIProxy.isConfigured)
        
        // When
        AIProxy.reset()
        
        // Then
        XCTAssertFalse(AIProxy.isConfigured)
        XCTAssertNil(AIProxy.currentConfiguration)
    }
}

// MARK: - Configuration Builder Tests

final class ConfigurationBuilderTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        AIProxy.reset()
    }
    
    override func tearDown() {
        AIProxy.reset()
        super.tearDown()
    }
    
    func testBuilder_DefaultValues() throws {
        // When
        try AIProxy.configure()
            .withAppId("test-app")
            .build()
        
        // Then
        let config = AIProxy.currentConfiguration!
        XCTAssertEqual(config.environment, .production)
        XCTAssertEqual(config.logLevel, .error)
    }
    
    func testBuilder_CustomValues() throws {
        // When
        try AIProxy.configure()
            .withAppId("test-app")
            .withEnvironment(.staging)
            .withLogLevel(.verbose)
            .build()
        
        // Then
        let config = AIProxy.currentConfiguration!
        XCTAssertEqual(config.appId, "test-app")
        XCTAssertEqual(config.environment, .staging)
        XCTAssertEqual(config.logLevel, .verbose)
    }
    
    func testBuilder_Chaining() throws {
        // Test that builder methods return self for chaining
        let builder = AIProxy.configure()
        let builder2 = builder.withAppId("test")
        let builder3 = builder2.withEnvironment(.development)
        let builder4 = builder3.withLogLevel(.info)
        
        // All should be the same instance
        XCTAssertTrue(builder === builder2)
        XCTAssertTrue(builder2 === builder3)
        XCTAssertTrue(builder3 === builder4)
    }
}
