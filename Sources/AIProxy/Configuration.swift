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
    case staging
    case development
    case custom(URL)
    
    var baseURL: URL {
        switch self {
        case .production:
            return URL(string: "https://api.aiproxy.io")!
        case .staging:
            return URL(string: "https://staging-api.aiproxy.io")!
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
        
        let configuration = Configuration(
            appId: appId,
            environment: environment,
            logLevel: logLevel
        )
        
        try AIProxy.initialize(with: configuration)
    }
}