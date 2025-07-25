import Foundation

/// HTTP methods
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

/// Network request builder
struct NetworkRequest {
    let path: String
    let method: HTTPMethod
    let headers: [String: String]
    let body: Data?
    let queryItems: [URLQueryItem]?
    
    init(
        path: String,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        body: Data? = nil,
        queryItems: [URLQueryItem]? = nil
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.body = body
        self.queryItems = queryItems
    }
}

/// Network client for making HTTP requests
public final class NetworkClient {
    private let baseURL: URL
    private let urlSession: URLSession
    private let logger: Logger
    private let interceptorChain: InterceptorChain
    
    // Static date formatters for performance
    private static let iso8601FormatterWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let iso8601FormatterStandard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    public init(baseURL: URL, urlSession: URLSession, logger: Logger) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.logger = logger
        
        // Setup default interceptors
        self.interceptorChain = InterceptorChain(interceptors: [
            LoggingInterceptor(logger: logger),
            RetryInterceptor(maxRetries: 3, logger: logger)
        ])
    }
    
    /// Perform a network request
    func perform<T: Decodable>(_ request: NetworkRequest, responseType: T.Type) async throws -> T {
        let urlRequest = try buildURLRequest(from: request)
        let finalRequest = await interceptorChain.process(urlRequest)
        
        do {
            let (data, response) = try await urlSession.data(for: finalRequest)
            try validateResponse(response, data: data)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Try parsing with fractional seconds first
                if let date = Self.iso8601FormatterWithFractionalSeconds.date(from: dateString) {
                    return date
                }
                
                // Fallback to standard ISO8601 without fractional seconds
                if let date = Self.iso8601FormatterStandard.date(from: dateString) {
                    return date
                }
                
                throw DecodingError.dataCorruptedError(in: container,
                    debugDescription: "Expected date string to be ISO8601-formatted.")
            }
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.error("Network request failed: \(error)")
            throw mapError(error)
        }
    }
    
    /// Perform a streaming request
    func stream(_ request: NetworkRequest) async throws -> AsyncThrowingStream<Data, Error> {
        let urlRequest = try buildURLRequest(from: request)
        let finalRequest = await interceptorChain.process(urlRequest)
        
        return AsyncThrowingStream { continuation in
            let task = urlSession.dataTask(with: finalRequest) { data, response, error in
                if let error = error {
                    continuation.finish(throwing: self.mapError(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.finish(throwing: AIProxyError.invalidResponse)
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    continuation.finish(throwing: AIProxyError.invalidResponse)
                    return
                }
                
                // Handle streaming response
                // This is a simplified version - real implementation would handle SSE properly
                if let data = data {
                    continuation.yield(data)
                }
                continuation.finish()
            }
            
            task.resume()
        }
    }
    
    private func buildURLRequest(from request: NetworkRequest) throws -> URLRequest {
        var url = baseURL.appendingPathComponent(request.path)
        
        if let queryItems = request.queryItems {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryItems
            url = components?.url ?? url
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        
        // Default headers
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("AIProxy-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        // Custom headers
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        return urlRequest
    }
    
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIProxyError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw AIProxyError.unauthorized
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw AIProxyError.rateLimited(retryAfter: retryAfter)
        case 404:
            throw AIProxyError.appNotFound
        default:
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw AIProxyError.providerError(
                    code: errorResponse.code,
                    message: errorResponse.message
                )
            }
            throw AIProxyError.invalidResponse
        }
    }
    
    private func mapError(_ error: Error) -> Error {
        if let aiProxyError = error as? AIProxyError {
            return aiProxyError
        }
        
        if (error as NSError).domain == NSURLErrorDomain {
            return AIProxyError.networkError(error)
        }
        
        return AIProxyError.unknown(error)
    }
}

/// Error response from server
struct ErrorResponse: Codable {
    let code: String
    let message: String
}