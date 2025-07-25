import Foundation
import CryptoKit
import DeviceCheck

/// Handles request signing for authentication
public final class RequestSigner {
    private let sessionManager: SessionManager
    private let logger: Logger
    private let deviceCheck = DCAppAttestService.shared
    
    public init(sessionManager: SessionManager, logger: Logger) {
        self.sessionManager = sessionManager
        self.logger = logger
    }
    
    /// Sign a request with App Attest assertion
    public func signRequest(
        method: String,
        path: String,
        body: Data?,
        keyId: String
    ) async throws -> RequestSignature {
        logger.debug("Starting request signing for keyId: \(keyId)")
        
        // Generate timestamp and nonce
        let timestamp = Int(Date().timeIntervalSince1970)
        let nonce = generateNonce()
        
        // Create the data to sign
        let dataToSign = createDataToSign(
            method: method,
            path: path,
            body: body,
            timestamp: timestamp,
            nonce: nonce
        )
        
        // Hash the data
        let hash = SHA256.hash(data: dataToSign)
        let clientDataHash = Data(hash)
        
        // Generate assertion using App Attest
        let assertion = try await generateAssertion(
            keyId: keyId,
            clientDataHash: clientDataHash
        )
        
        logger.debug("Request signed with App Attest assertion")
        
        return RequestSignature(
            timestamp: timestamp,
            nonce: nonce,
            signature: assertion.base64EncodedString(),
            platform: "ios",
            keyId: keyId
        )
    }
    
    private func generateNonce() -> String {
        // Generate 16 random bytes
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }
    
    private func createDataToSign(
        method: String,
        path: String,
        body: Data?,
        timestamp: Int,
        nonce: String
    ) -> Data {
        // Create canonical request format
        var components = [String]()
        components.append(method.uppercased())
        components.append(path)
        components.append(String(timestamp))
        components.append(nonce)
        
        // Add body hash if present
        if let body = body {
            let bodyHash = SHA256.hash(data: body)
            let bodyHashHex = bodyHash.compactMap { String(format: "%02x", $0) }.joined()
            components.append(bodyHashHex)
        } else {
            components.append("")
        }
        
        let canonicalRequest = components.joined(separator: "\n")
        return Data(canonicalRequest.utf8)
    }
    
    private func generateAssertion(
        keyId: String,
        clientDataHash: Data
    ) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            deviceCheck.generateAssertion(keyId, clientDataHash: clientDataHash) { assertion, error in
                if let error = error {
                    self.logger.error("Failed to generate assertion: \(error.localizedDescription)")
                    continuation.resume(throwing: AIProxyError.attestationFailed(error.localizedDescription))
                } else if let assertion = assertion {
                    self.logger.debug("Successfully generated assertion")
                    continuation.resume(returning: assertion)
                } else {
                    continuation.resume(throwing: AIProxyError.attestationFailed("Failed to generate assertion"))
                }
            }
        }
    }
}

/// Request signature data
public struct RequestSignature {
    public let timestamp: Int
    public let nonce: String
    public let signature: String
    public let platform: String
    public let keyId: String
    
    /// Convert to headers for the request
    public var headers: [String: String] {
        return [
            "X-Request-Timestamp": String(timestamp),
            "X-Request-Nonce": nonce,
            "X-Request-Signature": signature,
            "X-Platform": platform,
            "X-Key-Id": keyId
        ]
    }
}