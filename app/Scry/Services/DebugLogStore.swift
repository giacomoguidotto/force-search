import Foundation

enum LogLevel: Int, Comparable, CaseIterable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    var label: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERROR"
        }
    }

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

final class DebugLogStore: ObservableObject {
    static let shared = DebugLogStore()

    struct Entry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let category: String
        let level: LogLevel
        let message: String

        var formatted: String {
            let tf = Self.formatter
            return "\(tf.string(from: timestamp))  [\(level.label)]  \(category)  \(message)"
        }

        private static let formatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss.SSS"
            return f
        }()
    }

    @Published private(set) var entries: [Entry] = []
    @Published var eventTapStatus: String = "Not initialized"
    @Published var filterLevel: LogLevel = .info
    private let maxEntries = 500

    var filteredEntries: [Entry] {
        entries.filter { $0.level >= filterLevel }
    }

    var formattedAll: String {
        filteredEntries.map(\.formatted).joined(separator: "\n")
    }

    private init() {}

    func log(_ category: String, _ message: String, level: LogLevel = .info) {
        let entry = Entry(timestamp: Date(), category: category, level: level, message: message)
        if Thread.isMainThread {
            append(entry)
        } else {
            DispatchQueue.main.async { self.append(entry) }
        }
    }

    func clear() {
        entries.removeAll()
    }

    private func append(_ entry: Entry) {
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }
}
