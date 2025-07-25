import Foundation

/// Session data model
public struct Session: Codable {
    public let token: String
    public let expiresAt: Date
    public let appId: String
    public let keyId: String? // iOS App Attest key ID for signing
    
    public var isExpired: Bool {
        Date() >= expiresAt
    }
    
    public var isValid: Bool {
        !isExpired && !token.isEmpty
    }
    
    public init(token: String, expiresAt: Date, appId: String, keyId: String? = nil) {
        self.token = token
        self.expiresAt = expiresAt
        self.appId = appId
        self.keyId = keyId
    }
}

/// Manages authentication sessions
public final class SessionManager {
    private let storage: SecureStorageProtocol
    private let networkClient: NetworkClient
    private let logger: Logger
    private let sessionKey = "aiproxy.session"
    
    private var currentSession: Session?
    private let sessionQueue = DispatchQueue(label: "io.aiproxy.session", attributes: .concurrent)
    
    public init(storage: SecureStorageProtocol, networkClient: NetworkClient, logger: Logger) {
        self.storage = storage
        self.networkClient = networkClient
        self.logger = logger
        self.loadStoredSession()
    }
    
    /// Get current valid session token
    public func getSessionToken() async throws -> String {
        return try sessionQueue.sync {
            if let session = currentSession, session.isValid {
                return session.token
            }
            throw AIProxyError.sessionExpired
        }
    }
    
    /// Get current session (includes keyId)
    public func getCurrentSession() async throws -> Session {
        return try sessionQueue.sync {
            if let session = currentSession, session.isValid {
                return session
            }
            throw AIProxyError.sessionExpired
        }
    }
    
    /// Save a new session
    public func saveSession(_ session: Session) async throws {
        try sessionQueue.sync(flags: .barrier) {
            currentSession = session
            
            do {
                let data = try JSONEncoder().encode(session)
                try storage.save(data, forKey: sessionKey)
                logger.info("Session saved successfully")
            } catch {
                logger.error("Failed to save session: \(error)")
                throw error
            }
        }
    }
    
    /// Clear current session
    public func clearSession() async {
        sessionQueue.sync(flags: .barrier) {
            currentSession = nil
            do {
                try storage.delete(forKey: sessionKey)
                logger.info("Session cleared")
            } catch {
                logger.error("Failed to clear session: \(error)")
            }
        }
    }
    
    /// Check if we have a valid session
    public var hasValidSession: Bool {
        sessionQueue.sync {
            currentSession?.isValid ?? false
        }
    }
    
    private func loadStoredSession() {
        sessionQueue.sync(flags: .barrier) {
            do {
                let data = try storage.load(forKey: sessionKey)
                let session = try JSONDecoder().decode(Session.self, from: data)
                if session.isValid {
                    currentSession = session
                    logger.info("Loaded valid session from storage")
                } else {
                    try? storage.delete(forKey: sessionKey)
                    logger.info("Cleared expired session from storage")
                }
            } catch {
                logger.debug("No stored session found")
            }
        }
    }
}