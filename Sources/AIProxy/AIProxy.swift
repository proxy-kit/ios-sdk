import Foundation
import AIProxyCore

// Re-export public types from AIProxyCore
public typealias ChatMessage = AIProxyCore.ChatMessage
public typealias ChatResponse = AIProxyCore.ChatResponse
public typealias ChatStreamChunk = AIProxyCore.ChatStreamChunk
public typealias MessageRole = AIProxyCore.MessageRole
public typealias MessageContent = AIProxyCore.MessageContent
public typealias ContentPart = AIProxyCore.ContentPart
public typealias ImageDetail = AIProxyCore.ImageDetail
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
    private let openAIClient: OpenAIClient
    private let anthropicClient: AnthropicClient
    
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
        
        // Initialize provider clients
        self.openAIClient = OpenAIClient(
            networkClient: networkClient,
            sessionManager: sessionManager,
            attestationManager: attestationManager,
            logger: logger
        )
        
        self.anthropicClient = AnthropicClient(
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
    
    /// Access to OpenAI API
    public static var openai: OpenAIClient {
        get throws {
            guard let instance = shared else {
                throw AIProxyError.notConfigured
            }
            return instance.openAIClient
        }
    }
    
    /// Access to Anthropic API
    public static var anthropic: AnthropicClient {
        get throws {
            guard let instance = shared else {
                throw AIProxyError.notConfigured
            }
            return instance.anthropicClient
        }
    }
    
    /// Reset the SDK (useful for testing)
    public static func reset() {
        shared = nil
    }
    
    /// Clear the stored session and reset the SDK
    public static func clearSessionAndReset() async {
        // Clear the session if SDK is initialized
        if let instance = shared {
            await instance.sessionManager.clearSession()
        }
        // Reset the SDK
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
    
    /// Add an observer for attestation status changes
    public static func addAttestationObserver(_ observer: AttestationObserver) {
        guard let instance = shared else {
            logger.warning("Cannot add attestation observer: AIProxy not configured")
            return
        }
        instance.attestationManager.addObserver(observer)
    }
    
    /// Remove an attestation observer
    public static func removeAttestationObserver(_ observer: AttestationObserver) {
        guard let instance = shared else {
            return
        }
        instance.attestationManager.removeObserver(observer)
    }
    
    /// Get current attestation status
    public static var attestationStatus: AttestationStatus {
        guard let instance = shared else {
            return .notStarted
        }
        return instance.attestationManager.currentStatus
    }
    
    // Private logger for internal use
    private static let logger = Logger(level: .error)
}
