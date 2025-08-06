import Foundation
@testable import ProxyKitCore

class MockNetworkClient: NetworkClient {
    var performCallCount = 0
    var streamCallCount = 0
    var lastRequest: NetworkRequest?
    var mockResponse: Any?
    var shouldThrowError = false
    var errorToThrow: Error = AIProxyError.networkError(NSError(domain: "test", code: -1))
    
    init() {
        super.init(
            baseURL: URL(string: "https://test.com")!,
            urlSession: URLSession.shared,
            logger: Logger(level: .none)
        )
    }
    
    override func perform<T: Decodable>(_ request: NetworkRequest, responseType: T.Type) async throws -> T {
        performCallCount += 1
        lastRequest = request
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        if let response = mockResponse as? T {
            return response
        }
        
        throw AIProxyError.invalidResponse
    }
    
    override func stream(_ request: NetworkRequest) async throws -> AsyncThrowingStream<Data, Error> {
        streamCallCount += 1
        lastRequest = request
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return AsyncThrowingStream { continuation in
            if let data = mockResponse as? Data {
                continuation.yield(data)
            }
            continuation.finish()
        }
    }
    
    func reset() {
        performCallCount = 0
        streamCallCount = 0
        lastRequest = nil
        mockResponse = nil
        shouldThrowError = false
    }
}
