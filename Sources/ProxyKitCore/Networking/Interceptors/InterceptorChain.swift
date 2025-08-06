import Foundation

/// Protocol for request interceptors
protocol RequestInterceptor {
    func intercept(_ request: URLRequest, next: @escaping (URLRequest) async throws -> URLRequest) async throws -> URLRequest
}

/// Chain of responsibility for processing requests
final class InterceptorChain {
    private let interceptors: [RequestInterceptor]
    
    init(interceptors: [RequestInterceptor]) {
        self.interceptors = interceptors
    }
    
    func process(_ request: URLRequest) async -> URLRequest {
        var processedRequest = request
        
        for interceptor in interceptors {
            do {
                processedRequest = try await interceptor.intercept(processedRequest) { req in
                    return req
                }
            } catch {
                // Log error but continue processing
                print("Interceptor error: \(error)")
            }
        }
        
        return processedRequest
    }
}

/// Logging interceptor
struct LoggingInterceptor: RequestInterceptor {
    let logger: Logger
    
    func intercept(_ request: URLRequest, next: @escaping (URLRequest) async throws -> URLRequest) async throws -> URLRequest {
        logger.debug("Request: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
        
        if let headers = request.allHTTPHeaderFields {
            logger.debug("Headers: \(headers)")
        }
        
        if let body = request.httpBody {
            logger.debug("Body: \(String(data: body, encoding: .utf8) ?? "Binary data")")
        }
        
        return try await next(request)
    }
}

/// Retry interceptor
struct RetryInterceptor: RequestInterceptor {
    let maxRetries: Int
    let logger: Logger
    
    func intercept(_ request: URLRequest, next: @escaping (URLRequest) async throws -> URLRequest) async throws -> URLRequest {
        // In a real implementation, this would handle retries
        // For now, just pass through
        return try await next(request)
    }
}

/// Auth interceptor - adds session token to requests
struct AuthInterceptor: RequestInterceptor {
    let sessionManager: SessionManager
    let logger: Logger
    
    func intercept(_ request: URLRequest, next: @escaping (URLRequest) async throws -> URLRequest) async throws -> URLRequest {
        var modifiedRequest = request
        
        do {
            let token = try await sessionManager.getSessionToken()
            modifiedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            logger.debug("Added auth token to request")
        } catch {
            logger.debug("No valid session token available")
        }
        
        return try await next(modifiedRequest)
    }
}