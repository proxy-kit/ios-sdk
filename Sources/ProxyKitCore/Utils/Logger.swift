import Foundation
import os

/// Log levels
public enum LogLevel: Int {
    case none = 0
    case error = 1
    case warning = 2
    case info = 3
    case debug = 4
    case verbose = 5
    
    var shouldLog: Bool {
        self.rawValue > LogLevel.none.rawValue
    }
}

/// Internal logger for the SDK
public final class Logger {
    private let level: LogLevel
    private let subsystem = "io.proxykit.sdk"
    private let osLog: OSLog
    
    public init(level: LogLevel) {
        self.level = level
        self.osLog = OSLog(subsystem: subsystem, category: "ProxyKit")
    }
    
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, type: .debug, file: file, function: function, line: line)
    }
    
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, type: .info, file: file, function: function, line: line)
    }
    
    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, type: .default, file: file, function: function, line: line)
    }
    
    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, type: .error, file: file, function: function, line: line)
    }
    
    public func error(_ error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        log("Error: \(error.localizedDescription)", level: .error, type: .error, file: file, function: function, line: line)
    }
    
    private func log(_ message: String, level: LogLevel, type: OSLogType, file: String, function: String, line: Int) {
        guard level.rawValue <= self.level.rawValue else { return }
        
        let filename = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(filename):\(line)] \(function) - \(message)"
        
        os_log("%{public}@", log: osLog, type: type, logMessage)
    }
}
