import Foundation
import OSLog

/// Unified logging facade using Apple's os.log system
/// Provides categorized logging with automatic level filtering based on environment
final class Logger {
    // MARK: - Singleton

    static let shared = Logger()

    // MARK: - Private Properties

    private let subsystem: String
    private let minimumLevel: LogLevel

    private lazy var appLogger = os.Logger(subsystem: subsystem, category: "App")
    private lazy var networkLogger = os.Logger(subsystem: subsystem, category: "Network")
    private lazy var dataLogger = os.Logger(subsystem: subsystem, category: "Data")
    private lazy var uiLogger = os.Logger(subsystem: subsystem, category: "UI")
    private lazy var authLogger = os.Logger(subsystem: subsystem, category: "Auth")

    // MARK: - Initialization

    private init() {
        subsystem = Bundle.main.bundleIdentifier ?? "com.boilerplate.app"
        minimumLevel = AppEnvironment.current.loggingLevel
    }

    // MARK: - App Logging

    func app(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let context = formatContext(file: file, function: function, line: line)
        let formatted = "\(context) \(message)"
        LogBuffer.shared.append(category: "App", level: level, message: formatted)
        guard level >= minimumLevel else { return }
        osLog(to: appLogger, message: formatted, level: level)
    }

    // MARK: - Network Logging

    func network(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let context = formatContext(file: file, function: function, line: line)
        let formatted = "\(context) \(message)"
        LogBuffer.shared.append(category: "Network", level: level, message: formatted)
        guard level >= minimumLevel else { return }
        osLog(to: networkLogger, message: formatted, level: level)
    }

    // MARK: - Data Logging

    func data(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let context = formatContext(file: file, function: function, line: line)
        let formatted = "\(context) \(message)"
        LogBuffer.shared.append(category: "Data", level: level, message: formatted)
        guard level >= minimumLevel else { return }
        osLog(to: dataLogger, message: formatted, level: level)
    }

    // MARK: - UI Logging

    func ui(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let context = formatContext(file: file, function: function, line: line)
        let formatted = "\(context) \(message)"
        LogBuffer.shared.append(category: "UI", level: level, message: formatted)
        guard level >= minimumLevel else { return }
        osLog(to: uiLogger, message: formatted, level: level)
    }

    // MARK: - Auth Logging

    func auth(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let context = formatContext(file: file, function: function, line: line)
        let formatted = "\(context) \(message)"
        LogBuffer.shared.append(category: "Auth", level: level, message: formatted)
        guard level >= minimumLevel else { return }
        osLog(to: authLogger, message: formatted, level: level)
    }

    // MARK: - Error Logging

    func error(_ error: Error, context: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let fileContext = formatContext(file: file, function: function, line: line)
        let message: String
        if let context {
            message = "\(fileContext) \(context): \(error.localizedDescription)"
        } else {
            message = "\(fileContext) \(error.localizedDescription)"
        }
        LogBuffer.shared.append(category: "App", level: .error, message: message)
        osLog(to: appLogger, message: message, level: .error)
    }

    // MARK: - Private Methods

    private func osLog(to logger: os.Logger, message: String, level: LogLevel) {
        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }
    }

    private func formatContext(file: String, function: String, line: Int) -> String {
        let fileName = (file as NSString).lastPathComponent
        return "[\(fileName):\(line)]"
    }
}

// MARK: - Convenience Global Functions

func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.app(message, level: .debug, file: file, function: function, line: line)
}

func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.app(message, level: .info, file: file, function: function, line: line)
}

func logWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.app(message, level: .warning, file: file, function: function, line: line)
}

func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.app(message, level: .error, file: file, function: function, line: line)
}

func logError(_ error: Error, context: String? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(error, context: context, file: file, function: function, line: line)
}
