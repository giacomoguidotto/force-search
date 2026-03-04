import Foundation

final class DebugLogStore: ObservableObject {
    static let shared = DebugLogStore()

    struct Entry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let category: String
        let message: String
    }

    @Published private(set) var entries: [Entry] = []
    @Published var eventTapStatus: String = "Not initialized"
    private let maxEntries = 500

    private init() {}

    func log(_ category: String, _ message: String) {
        let entry = Entry(timestamp: Date(), category: category, message: message)
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
