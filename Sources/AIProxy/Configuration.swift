import Foundation

/// SDK Configuration
public struct Configuration {
    public let appId: String
    public let environment: Environment
    public let logLevel: LogLevel
    public let baseURL: URL
    public let sessionTimeout: TimeInterval
    
    init(appId: String, environment: Environment, logLevel: LogLevel) {
        self.appId = appId
        self.environment = environment
        self.logLevel = logLevel
        self.baseURL = environment.baseURL
        self.sessionTimeout = 3600 // 1 hour
    }
}

/// SDK Environment
public enum Environment {
    case production
    case staging(URL? = nil)  // Allow optional custom staging URL
    case development
    case custom(URL)
    
    var baseURL: URL {
        switch self {
        case .production:
            return URL(string: "https://api.secureapikey.com")!
            // proxykit-api-4a469b12bf8a.herokuapp.com
        case .staging(let customURL):
            // Use custom URL if provided, otherwise use default staging URL
            return customURL ?? URL(string: "https://staging.aiproxy.io")!
        case .development:
            return URL(string: "http://localhost:3001")!
        case .custom(let url):
            return url
        }
    }
}


/// Configuration Builder
public final class ConfigurationBuilder {
    private var appId: String?
    private var environment: Environment = .production
    private var logLevel: LogLevel = .error
    
    public init() {}
    
    /// Set the app ID (required)
    public func withAppId(_ id: String) -> ConfigurationBuilder {
        self.appId = id
        return self
    }
    
    /// Set the environment (default: production)
    public func withEnvironment(_ env: Environment) -> ConfigurationBuilder {
        self.environment = env
        return self
    }
    
    /// Set the log level (default: error)
    public func withLogLevel(_ level: LogLevel) -> ConfigurationBuilder {
        self.logLevel = level
        return self
    }
    
    /// Build the configuration and initialize AIProxy
    public func build() throws {
        guard let appId = appId else {
            throw ConfigurationError.missingAppId
        }
        
        guard !appId.isEmpty else {
            throw ConfigurationError.invalidAppId
        }
        
        // Validate environment URLs
        try validateEnvironment(environment)
        
        let configuration = Configuration(
            appId: appId,
            environment: environment,
            logLevel: logLevel
        )
        
        try AIProxy.initialize(with: configuration)
    }
    
    private func validateEnvironment(_ environment: Environment) throws {
        switch environment {
        case .custom(let url):
            // Ensure custom URLs use HTTPS in production
            if url.scheme != "https" && url.scheme != "http" {
                throw ConfigurationError.invalidURL("URL must use HTTP or HTTPS scheme")
            }
            
            // Warn if using HTTP in production
            if url.scheme == "http" && !url.host!.contains("localhost") && !url.host!.contains("127.0.0.1") {
                print("Warning: Using HTTP for non-localhost URL is insecure")
            }
            
        case .staging(let customURL):
            if let url = customURL {
                // Apply same validation as custom URLs
                if url.scheme != "https" && url.scheme != "http" {
                    throw ConfigurationError.invalidURL("Staging URL must use HTTP or HTTPS scheme")
                }
            }
            
        default:
            break // Production and development URLs are pre-validated
        }
    }
}
