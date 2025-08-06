import Foundation
@testable import ProxyKitCore

class MockLogger: Logger {
    var debugMessages: [String] = []
    var infoMessages: [String] = []
    var warningMessages: [String] = []
    var errorMessages: [String] = []
    
    init() {
        super.init(level: .verbose)
    }
    
    override func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debugMessages.append(message)
    }
    
    override func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        infoMessages.append(message)
    }
    
    override func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        warningMessages.append(message)
    }
    
    override func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        errorMessages.append(message)
    }
    
    override func error(_ error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        errorMessages.append("Error: \(error.localizedDescription)")
    }
    
    func reset() {
        debugMessages.removeAll()
        infoMessages.removeAll()
        warningMessages.removeAll()
        errorMessages.removeAll()
    }
    
    var allMessages: [String] {
        debugMessages + infoMessages + warningMessages + errorMessages
    }
}
