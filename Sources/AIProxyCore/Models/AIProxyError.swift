import Foundation

/// Errors that can occur when using AIProxy
public enum AIProxyError: LocalizedError {
    case notConfigured
    case configurationError(String)
    case attestationFailed(String)
    case sessionExpired
    case networkError(Error)
    case invalidResponse
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case providerError(code: String, message: String)
    case invalidAPIKey
    case appNotFound
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AIProxy not configured. Call AIProxy.configure() first."
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .attestationFailed(let reason):
            return "Device attestation failed: \(reason)"
        case .sessionExpired:
            return "Session has expired. Please re-authenticate."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
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
    
    public var errorDescription: String? {
        switch self {
        case .missingAppId:
            return "App ID is required for configuration"
        case .invalidAppId:
            return "Invalid app ID format"
        case .invalidEnvironment:
            return "Invalid environment specified"
        }
    }
}