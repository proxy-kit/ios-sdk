import Foundation
import DeviceCheck
import CryptoKit

/// Attestation status
public enum AttestationStatus {
    case notStarted
    case inProgress
    case completed
    case failed(Error)
}

/// Protocol for attestation observers
public protocol AttestationObserver: AnyObject {
    func attestationDidUpdate(status: AttestationStatus)
    func attestationDidFail(error: Error)
}

/// Manages device attestation
public final class AttestationManager {
    private let appId: String
    private let sessionManager: SessionManager
    private let networkClient: NetworkClient
    private let logger: Logger
    private let deviceCheck = DCAppAttestService.shared
    
    private var observers = [AttestationObserver]()
    private let observerQueue = DispatchQueue(label: "io.proxykit.attestation.observers", attributes: .concurrent)
    private var attestationStatus: AttestationStatus = .notStarted {
        didSet {
            notifyObservers(status: attestationStatus)
        }
    }
    
    public init(appId: String, sessionManager: SessionManager, networkClient: NetworkClient, logger: Logger) {
        self.appId = appId
        self.sessionManager = sessionManager
        self.networkClient = networkClient
        self.logger = logger
    }
    
    /// Get current attestation status
    public var currentStatus: AttestationStatus {
        observerQueue.sync {
            attestationStatus
        }
    }
    
    /// Add an observer
    public func addObserver(_ observer: AttestationObserver) {
        observerQueue.async(flags: .barrier) {
            self.observers.append(observer)
        }
    }
    
    /// Remove an observer
    public func removeObserver(_ observer: AttestationObserver) {
        observerQueue.async(flags: .barrier) {
            self.observers.removeAll { $0 === observer }
        }
    }
    
    /// Perform attestation if needed
    public func attestIfNeeded() async throws {
        guard !sessionManager.hasValidSession else {
            logger.info("Valid session exists, skipping attestation")
            return
        }
        
        try await performAttestation()
    }
    
    /// Force attestation (useful for retry scenarios)
    public func performAttestation() async throws {
        #if targetEnvironment(simulator)
        logger.warning("DeviceCheck not available on simulator. Attestation will be skipped.")
        throw ProxyKitError.attestationFailed("Device attestation is not supported on simulator. Please run on a real device.")
        #else
        guard deviceCheck.isSupported else {
            throw ProxyKitError.attestationFailed("Device attestation not supported on this device")
        }
        #endif
        
        attestationStatus = .inProgress
        
        do {
            // Step 1: Get challenge from server
            let challenge = try await getChallenge()
            
            // Step 2: Generate key
            let keyId = try await generateKey()
            
            // Step 3: Attest key
            let attestation = try await attestKey(keyId: keyId, challenge: challenge.data)
            
            // Step 4: Verify with server
            let session = try await verifyAttestation(
                keyId: keyId,
                attestation: attestation,
                challenge: challenge.challenge
            )
            
            // Step 5: Save session
            try await sessionManager.saveSession(session)
            
            attestationStatus = .completed
            logger.info("Attestation completed successfully")
        } catch {
            attestationStatus = .failed(error)
            notifyObserversOfFailure(error: error)
            throw error
        }
    }
    
    private func getChallenge() async throws -> ChallengeResponse {
        let request = NetworkRequest(
            path: "/v1/attestation/challenge",
            method: .post,
            body: try JSONEncoder().encode(["appId": appId])
        )
        
        return try await networkClient.perform(request, responseType: ChallengeResponse.self)
    }
    
    private func generateKey() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            deviceCheck.generateKey { keyId, error in
                if let error = error {
                    let errorMessage = self.mapDeviceCheckError(error)
                    self.logger.error("DeviceCheck key generation failed: \(errorMessage)")
                    continuation.resume(throwing: ProxyKitError.attestationFailed(errorMessage))
                } else if let keyId = keyId {
                    continuation.resume(returning: keyId)
                } else {
                    continuation.resume(throwing: ProxyKitError.attestationFailed("Failed to generate key"))
                }
            }
        }
    }
    
    private func attestKey(keyId: String, challenge: Data) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            deviceCheck.attestKey(keyId, clientDataHash: challenge) { attestation, error in
                if let error = error {
                    let errorMessage = self.mapDeviceCheckError(error)
                    self.logger.error("DeviceCheck attestation failed: \(errorMessage)")
                    continuation.resume(throwing: ProxyKitError.attestationFailed(errorMessage))
                } else if let attestation = attestation {
                    continuation.resume(returning: attestation)
                } else {
                    continuation.resume(throwing: ProxyKitError.attestationFailed("Failed to attest key"))
                }
            }
        }
    }
    
    private func verifyAttestation(keyId: String, attestation: Data, challenge: String) async throws -> Session {
        let request = NetworkRequest(
            path: "/v1/attestation/verify",
            method: .post,
            body: try JSONEncoder().encode([
                "appId": appId,
                "keyId": keyId,
                "attestation": attestation.base64EncodedString(),
                "challenge": challenge
            ])
        )
        
        let response = try await networkClient.perform(request, responseType: VerifyResponse.self)
        
        return Session(
            token: response.sessionToken,
            expiresAt: response.expiresAt,
            appId: appId,
            keyId: keyId
        )
    }
    
    private func notifyObservers(status: AttestationStatus) {
        observerQueue.async {
            self.observers.forEach { observer in
                DispatchQueue.main.async {
                    observer.attestationDidUpdate(status: status)
                }
            }
        }
    }
    
    private func notifyObserversOfFailure(error: Error) {
        observerQueue.async {
            self.observers.forEach { observer in
                DispatchQueue.main.async {
                    observer.attestationDidFail(error: error)
                }
            }
        }
    }
    
    private func mapDeviceCheckError(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case 0:
            return "DeviceCheck is not supported on this device. Ensure you're running on a real device, not a simulator."
        case 1:
            return "This device has already been used with a different app instance."
        case 2:
            return "DeviceCheck service is temporarily unavailable. Please ensure you're running on a real device with iOS 14+ and that your app has the App Attest capability enabled."
        case 3:
            return "Invalid key ID provided."
        case 4:
            return "DeviceCheck request failed. Please check your network connection."
        default:
            return "DeviceCheck error: \(error.localizedDescription) (Code: \(nsError.code))"
        }
    }
}

// MARK: - Response Models

private struct ChallengeResponse: Codable {
    let challenge: String
    let expiresAt: Date
    
    var data: Data {
        // Create SHA256 hash of the challenge for clientDataHash
        let challengeData = Data(challenge.utf8)
        let hash = SHA256.hash(data: challengeData)
        return Data(hash)
    }
}

private struct VerifyResponse: Codable {
    let sessionToken: String
    let expiresAt: Date
}
