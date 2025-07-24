import Foundation
import AIProxyCore

// Re-export public types from AIProxyCore
public typealias ChatMessage = AIProxyCore.ChatMessage
public typealias ChatResponse = AIProxyCore.ChatResponse
public typealias ChatStreamChunk = AIProxyCore.ChatStreamChunk
public typealias MessageRole = AIProxyCore.MessageRole
public typealias AIProxyError = AIProxyCore.AIProxyError
public typealias ConfigurationError = AIProxyCore.ConfigurationError
public typealias AttestationStatus = AIProxyCore.AttestationStatus
public typealias AttestationObserver = AIProxyCore.AttestationObserver
public typealias LogLevel = AIProxyCore.LogLevel

// Re-export the new flexible types
public typealias ChatModel = AIProxyCore.ChatModel
public typealias AIProvider = AIProxyCore.AIProvider

/// Main entry point for the AIProxy SDK
/// Uses the Facade pattern to provide a simple, unified interface
public final class AIProxy {
    private static var shared: AIProxy?
    private let configuration: Configuration
    private let attestationManager: AttestationManager
    private let sessionManager: SessionManager
    private let networkClient: NetworkClient
    private let chatProvider: ChatProvider
    
    /// Private initializer - use configure() to initialize
    init(configuration: Configuration) throws {
        self.configuration = configuration
        
        // Initialize core components
        let logger = Logger(level: configuration.logLevel)
        let storage = SecureStorage()
        let urlSession = URLSession(configuration: .default)
        
        self.networkClient = NetworkClient(
            baseURL: configuration.baseURL,
            urlSession: urlSession,
            logger: logger
        )
        
        self.sessionManager = SessionManager(
            storage: storage,
            networkClient: networkClient,
            logger: logger
        )
        
        self.attestationManager = AttestationManager(
            appId: configuration.appId,
            sessionManager: sessionManager,
            networkClient: networkClient,
            logger: logger
        )
        
        self.chatProvider = ChatProvider(
            networkClient: networkClient,
            sessionManager: sessionManager,
            attestationManager: attestationManager,
            logger: logger
        )
        
        logger.info("AIProxy initialized with app ID: \(configuration.appId)")
        
        // Perform initial attestation in the background
        Task {
            do {
                try await attestationManager.attestIfNeeded()
                logger.info("Initial attestation completed")
            } catch {
                logger.error("Initial attestation failed: \(error)")
                // Don't throw - attestation will be retried on first API call
            }
        }
    }
    
    /// Configure the SDK with builder pattern
    public static func configure() -> ConfigurationBuilder {
        return ConfigurationBuilder()
    }
    
    /// Initialize with configuration (called by builder)
    static func initialize(with configuration: Configuration) throws {
        guard shared == nil else {
            throw AIProxyError.configurationError("AIProxy is already configured")
        }
        
        shared = try AIProxy(configuration: configuration)
    }
    
    /// Access to chat completions API
    public static var chat: ChatProvider {
        guard let instance = shared else {
            fatalError("AIProxy not configured. Call AIProxy.configure() first.")
        }
        return instance.chatProvider
    }
    
    /// Reset the SDK (useful for testing)
    public static func reset() {
        shared = nil
    }
    
    /// Get current configuration
    public static var currentConfiguration: Configuration? {
        return shared?.configuration
    }
    
    /// Check if SDK is configured
    public static var isConfigured: Bool {
        return shared != nil
    }
}
