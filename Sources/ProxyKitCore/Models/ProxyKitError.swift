import Foundation

/// Errors that can occur when using ProxyKit
public enum ProxyKitError: LocalizedError {
    case notConfigured
    case configurationError(String)
    case attestationFailed(String)
    case sessionExpired
    case networkError(Error)
    case invalidResponse(response: String)
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case providerError(code: String, message: String)
    case invalidAPIKey
    case appNotFound
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "ProxyKit not configured. Call ProxyKit.configure() first."
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .attestationFailed(let reason):
            return "Device attestation failed: \(reason)"
        case .sessionExpired:
            return "Session has expired. Please re-authenticate."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse(let response):
            return "Invalid response from server: \(response)"
        case .unauthorized:
            return "Unauthorized. Please check your app configuration."
        case .rateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limited. Try again in \(Int(retryAfter)) seconds."
            }
            return "Rate limited. Please try again later."
        case .providerError(let code, let message):
            return "Provider error (\(code)): \(message)"
        case .invalidAPIKey:
            return "Invalid or missing API key for the requested provider"
        case .appNotFound:
            return "App not found. Please check your app ID."
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

/// Configuration errors
public enum ConfigurationError: LocalizedError {
    case missingAppId
    case invalidAppId
    case invalidEnvironment
    case invalidURL(String)
    
    public var errorDescription: String? {
        switch self {
        case .missingAppId:
            return "App ID is required for configuration"
        case .invalidAppId:
            return "Invalid app ID format"
        case .invalidEnvironment:
            return "Invalid environment specified"
        case .invalidURL(let reason):
            return "Invalid URL: \(reason)"
        }
    }
}
