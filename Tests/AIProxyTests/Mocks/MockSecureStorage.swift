import Foundation
@testable import ProxyKitCore

class MockSecureStorage: SecureStorageProtocol {
    var storage: [String: Data] = [:]
    var saveCallCount = 0
    var loadCallCount = 0
    var deleteCallCount = 0
    var shouldThrowError = false
    var errorToThrow: Error?
    
    func save(_ data: Data, forKey key: String) throws {
        saveCallCount += 1
        if shouldThrowError {
            throw errorToThrow ?? KeychainError.unableToSave(-1)
        }
        storage[key] = data
    }
    
    func load(forKey key: String) throws -> Data {
        loadCallCount += 1
        if shouldThrowError {
            throw errorToThrow ?? KeychainError.itemNotFound
        }
        guard let data = storage[key] else {
            throw KeychainError.itemNotFound
        }
        return data
    }
    
    func delete(forKey key: String) throws {
        deleteCallCount += 1
        if shouldThrowError {
            throw errorToThrow ?? KeychainError.unableToDelete(-1)
        }
        storage.removeValue(forKey: key)
    }
    
    func exists(forKey key: String) -> Bool {
        return storage[key] != nil
    }
    
    func reset() {
        storage.removeAll()
        saveCallCount = 0
        loadCallCount = 0
        deleteCallCount = 0
        shouldThrowError = false
        errorToThrow = nil
    }
}
