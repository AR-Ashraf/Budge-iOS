import Foundation

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let category: String
    let level: LogLevel
    let message: String

    var levelIcon: String {
        switch level {
        case .debug: return "D"
        case .info: return "I"
        case .warning: return "W"
        case .error: return "E"
        }
    }

    var formatted: String {
        let time = Self.timeFormatter.string(from: timestamp)
        return "[\(time)] [\(levelIcon)/\(category)] \(message)"
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}

final class LogBuffer: @unchecked Sendable {
    static let shared = LogBuffer()

    private let queue = DispatchQueue(label: "com.boilerplate.logbuffer", attributes: .concurrent)
    private var entries: [LogEntry] = []
    private let maxEntries = 500

    var onChange: (() -> Void)?

    private init() {
        entries.reserveCapacity(maxEntries)
    }

    func append(category: String, level: LogLevel, message: String) {
        let entry = LogEntry(timestamp: Date(), category: category, level: level, message: message)
        queue.async(flags: .barrier) {
            self.entries.append(entry)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
            DispatchQueue.main.async {
                self.onChange?()
            }
        }
    }

    func getEntries() -> [LogEntry] {
        queue.sync { entries }
    }

    func clear() {
        queue.async(flags: .barrier) {
            self.entries.removeAll()
            DispatchQueue.main.async {
                self.onChange?()
            }
        }
    }
}
