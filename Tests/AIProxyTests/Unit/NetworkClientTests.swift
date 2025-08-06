import XCTest
@testable import ProxyKitCore

final class NetworkClientTests: XCTestCase {
    var sut: NetworkClient!
    var mockURLSession: MockURLSession!
    var mockLogger: MockLogger!
    let baseURL = URL(string: "https://api.test.com")!
    
    override func setUp() {
        super.setUp()
        mockURLSession = MockURLSession()
        mockLogger = MockLogger()
        sut = NetworkClient(
            baseURL: baseURL,
            urlSession: mockURLSession,
            logger: mockLogger
        )
    }
    
    override func tearDown() {
        sut = nil
        mockURLSession = nil
        mockLogger = nil
        super.tearDown()
    }
    
    // MARK: - Request Building Tests
    
    func testBuildRequest_BasicGET() async throws {
        // Given
        let request = NetworkRequest(
            path: "/test",
            method: .get
        )
        mockURLSession.mockData = "{}".data(using: .utf8)!
        mockURLSession.mockResponse = HTTPURLResponse(
            url: baseURL.appendingPathComponent("/test"),
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        // When
        _ = try await sut.perform(request, responseType: EmptyResponse.self)
        
        // Then
        let capturedRequest = mockURLSession.lastRequest
        XCTAssertEqual(capturedRequest?.url?.absoluteString, "https://api.test.com/test")
        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Accept"), "application/json")
    }
    
    func testBuildRequest_POSTWithBody() async throws {
        // Given
        let body = ["key": "value"]
        let bodyData = try JSONEncoder().encode(body)
        let request = NetworkRequest(
            path: "/test",
            method: .post,
            body: bodyData
        )
        mockURLSession.mockData = "{}".data(using: .utf8)!
        mockURLSession.mockResponse = HTTPURLResponse(
            url: baseURL.appendingPathComponent("/test"),
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        // When
        _ = try await sut.perform(request, responseType: EmptyResponse.self)
        
        // Then
        let capturedRequest = mockURLSession.lastRequest
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.httpBody, bodyData)
    }
    
    func testBuildRequest_WithQueryItems() async throws {
        // Given
        let request = NetworkRequest(
            path: "/test",
            method: .get,
            queryItems: [
                URLQueryItem(name: "foo", value: "bar"),
                URLQueryItem(name: "baz", value: "qux")
            ]
        )
        mockURLSession.mockData = "{}".data(using: .utf8)!
        mockURLSession.mockResponse = HTTPURLResponse(
            url: baseURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        // When
        _ = try await sut.perform(request, responseType: EmptyResponse.self)
        
        // Then
        let capturedRequest = mockURLSession.lastRequest
        XCTAssertTrue(capturedRequest?.url?.absoluteString.contains("foo=bar") ?? false)
        XCTAssertTrue(capturedRequest?.url?.absoluteString.contains("baz=qux") ?? false)
    }
    
    // MARK: - Response Validation Tests
    
    func testValidateResponse_Success200() async throws {
        // Given
        let request = NetworkRequest(path: "/test")
        let responseData = TestResponse(message: "Success")
        mockURLSession.mockData = try JSONEncoder().encode(responseData)
        mockURLSession.mockResponse = HTTPURLResponse(
            url: baseURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        // When
        let result = try await sut.perform(request, responseType: TestResponse.self)
        
        // Then
        XCTAssertEqual(result.message, "Success")
    }
    
    func testValidateResponse_Unauthorized401() async {
        // Given
        let request = NetworkRequest(path: "/test")
        mockURLSession.mockData = "{}".data(using: .utf8)!
        mockURLSession.mockResponse = HTTPURLResponse(
            url: baseURL,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
        
        // When/Then
        do {
            _ = try await sut.perform(request, responseType: EmptyResponse.self)
            XCTFail("Expected unauthorized error")
        } catch {
            XCTAssertEqual(error as? AIProxyError, AIProxyError.unauthorized)
        }
    }
    
    func testValidateResponse_RateLimited429() async {
        // Given
        let request = NetworkRequest(path: "/test")
        mockURLSession.mockData = "{}".data(using: .utf8)!
        mockURLSession.mockResponse = HTTPURLResponse(
            url: baseURL,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "60"]
        )!
        
        // When/Then
        do {
            _ = try await sut.perform(request, responseType: EmptyResponse.self)
            XCTFail("Expected rate limited error")
        } catch AIProxyError.rateLimited(let retryAfter) {
            XCTAssertEqual(retryAfter, 60)
        } catch {
            XCTFail("Expected rate limited error, got: \(error)")
        }
    }
    
    func testValidateResponse_NotFound404() async {
        // Given
        let request = NetworkRequest(path: "/test")
        mockURLSession.mockData = "{}".data(using: .utf8)!
        mockURLSession.mockResponse = HTTPURLResponse(
            url: baseURL,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )!
        
        // When/Then
        do {
            _ = try await sut.perform(request, responseType: EmptyResponse.self)
            XCTFail("Expected app not found error")
        } catch {
            XCTAssertEqual(error as? AIProxyError, AIProxyError.appNotFound)
        }
    }
    
    func testValidateResponse_ProviderError() async {
        // Given
        let request = NetworkRequest(path: "/test")
        let errorResponse = ErrorResponse(code: "invalid_request", message: "Invalid parameters")
        mockURLSession.mockData = try! JSONEncoder().encode(errorResponse)
        mockURLSession.mockResponse = HTTPURLResponse(
            url: baseURL,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )!
        
        // When/Then
        do {
            _ = try await sut.perform(request, responseType: EmptyResponse.self)
            XCTFail("Expected provider error")
        } catch AIProxyError.providerError(let code, let message) {
            XCTAssertEqual(code, "invalid_request")
            XCTAssertEqual(message, "Invalid parameters")
        } catch {
            XCTFail("Expected provider error, got: \(error)")
        }
    }
    
    // MARK: - Error Mapping Tests
    
    func testMapError_NetworkError() async {
        // Given
        let request = NetworkRequest(path: "/test")
        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        mockURLSession.mockError = networkError
        
        // When/Then
        do {
            _ = try await sut.perform(request, responseType: EmptyResponse.self)
            XCTFail("Expected network error")
        } catch AIProxyError.networkError(let error) {
            XCTAssertEqual((error as NSError).code, NSURLErrorNotConnectedToInternet)
        } catch {
            XCTFail("Expected network error, got: \(error)")
        }
    }
}

// MARK: - Mock URLSession

class MockURLSession: URLSession {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    var lastRequest: URLRequest?
    
    override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        
        if let error = mockError {
            throw error
        }
        
        let data = mockData ?? Data()
        let response = mockResponse ?? HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        return (data, response)
    }
}

// MARK: - Test Models

struct EmptyResponse: Codable {}

struct TestResponse: Codable {
    let message: String
}
