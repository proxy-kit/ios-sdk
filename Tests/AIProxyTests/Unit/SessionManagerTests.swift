import XCTest
@testable import AIProxyCore

final class SessionManagerTests: XCTestCase {
    var sut: SessionManager!
    var mockStorage: MockSecureStorage!
    var mockNetworkClient: MockNetworkClient!
    var mockLogger: MockLogger!
    
    override func setUp() {
        super.setUp()
        mockStorage = MockSecureStorage()
        mockNetworkClient = MockNetworkClient()
        mockLogger = MockLogger()
        sut = SessionManager(
            storage: mockStorage,
            networkClient: mockNetworkClient,
            logger: mockLogger
        )
    }
    
    override func tearDown() {
        sut = nil
        mockStorage = nil
        mockNetworkClient = nil
        mockLogger = nil
        super.tearDown()
    }
    
    // MARK: - Save Session Tests
    
    func testSaveSession_Success() async throws {
        // Given
        let session = Session(
            token: "test-token",
            expiresAt: Date().addingTimeInterval(3600),
            appId: "test-app"
        )
        
        // When
        try await sut.saveSession(session)
        
        // Then
        XCTAssertEqual(mockStorage.saveCallCount, 1)
        XCTAssertTrue(mockStorage.exists(forKey: "aiproxy.session"))
        XCTAssertTrue(mockLogger.infoMessages.contains("Session saved successfully"))
    }
    
    func testSaveSession_StorageError() async {
        // Given
        let session = Session(
            token: "test-token",
            expiresAt: Date().addingTimeInterval(3600),
            appId: "test-app"
        )
        mockStorage.shouldThrowError = true
        mockStorage.errorToThrow = KeychainError.unableToSave(-1)
        
        // When/Then
        do {
            try await sut.saveSession(session)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is KeychainError)
            XCTAssertTrue(mockLogger.errorMessages.contains { $0.contains("Failed to save session") })
        }
    }
    
    // MARK: - Get Session Token Tests
    
    func testGetSessionToken_ValidSession() async throws {
        // Given
        let session = Session(
            token: "valid-token",
            expiresAt: Date().addingTimeInterval(3600),
            appId: "test-app"
        )
        try await sut.saveSession(session)
        
        // When
        let token = try await sut.getSessionToken()
        
        // Then
        XCTAssertEqual(token, "valid-token")
    }
    
    func testGetSessionToken_ExpiredSession() async throws {
        // Given
        let session = Session(
            token: "expired-token",
            expiresAt: Date().addingTimeInterval(-3600), // Expired 1 hour ago
            appId: "test-app"
        )
        try await sut.saveSession(session)
        
        // When/Then
        do {
            _ = try await sut.getSessionToken()
            XCTFail("Expected sessionExpired error")
        } catch {
            XCTAssertEqual(error as? AIProxyError, AIProxyError.sessionExpired)
        }
    }
    
    func testGetSessionToken_NoSession() async {
        // When/Then
        do {
            _ = try await sut.getSessionToken()
            XCTFail("Expected sessionExpired error")
        } catch {
            XCTAssertEqual(error as? AIProxyError, AIProxyError.sessionExpired)
        }
    }
    
    // MARK: - Clear Session Tests
    
    func testClearSession() async throws {
        // Given
        let session = Session(
            token: "test-token",
            expiresAt: Date().addingTimeInterval(3600),
            appId: "test-app"
        )
        try await sut.saveSession(session)
        
        // When
        await sut.clearSession()
        
        // Then
        XCTAssertEqual(mockStorage.deleteCallCount, 1)
        XCTAssertFalse(mockStorage.exists(forKey: "aiproxy.session"))
        XCTAssertTrue(mockLogger.infoMessages.contains("Session cleared"))
    }
    
    func testClearSession_StorageError() async {
        // Given
        mockStorage.shouldThrowError = true
        mockStorage.errorToThrow = KeychainError.unableToDelete(-1)
        
        // When
        await sut.clearSession()
        
        // Then
        XCTAssertTrue(mockLogger.errorMessages.contains { $0.contains("Failed to clear session") })
    }
    
    // MARK: - Has Valid Session Tests
    
    func testHasValidSession_True() async throws {
        // Given
        let session = Session(
            token: "valid-token",
            expiresAt: Date().addingTimeInterval(3600),
            appId: "test-app"
        )
        try await sut.saveSession(session)
        
        // When
        let hasValid = sut.hasValidSession
        
        // Then
        XCTAssertTrue(hasValid)
    }
    
    func testHasValidSession_False_NoSession() {
        // When
        let hasValid = sut.hasValidSession
        
        // Then
        XCTAssertFalse(hasValid)
    }
    
    func testHasValidSession_False_ExpiredSession() async throws {
        // Given
        let session = Session(
            token: "expired-token",
            expiresAt: Date().addingTimeInterval(-3600),
            appId: "test-app"
        )
        try await sut.saveSession(session)
        
        // When
        let hasValid = sut.hasValidSession
        
        // Then
        XCTAssertFalse(hasValid)
    }
    
    // MARK: - Session Loading Tests
    
    func testInitLoadsStoredSession() throws {
        // Given
        let session = Session(
            token: "stored-token",
            expiresAt: Date().addingTimeInterval(3600),
            appId: "test-app"
        )
        let data = try JSONEncoder().encode(session)
        try mockStorage.save(data, forKey: "aiproxy.session")
        
        // When
        let newManager = SessionManager(
            storage: mockStorage,
            networkClient: mockNetworkClient,
            logger: mockLogger
        )
        
        // Then
        XCTAssertTrue(newManager.hasValidSession)
        XCTAssertTrue(mockLogger.infoMessages.contains("Loaded valid session from storage"))
    }
    
    func testInitClearsExpiredStoredSession() throws {
        // Given
        let session = Session(
            token: "expired-token",
            expiresAt: Date().addingTimeInterval(-3600),
            appId: "test-app"
        )
        let data = try JSONEncoder().encode(session)
        try mockStorage.save(data, forKey: "aiproxy.session")
        
        // When
        _ = SessionManager(
            storage: mockStorage,
            networkClient: mockNetworkClient,
            logger: mockLogger
        )
        
        // Then
        XCTAssertFalse(mockStorage.exists(forKey: "aiproxy.session"))
        XCTAssertTrue(mockLogger.infoMessages.contains("Cleared expired session from storage"))
    }
}