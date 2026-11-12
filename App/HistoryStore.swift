import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()
    private static let limit = 2000
    private static let keyboardLimit = 50

    @Published private(set) var records: [DictationRecord] = []

    private let fileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("history.json")
    }()

    private init() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([DictationRecord].self, from: data) {
            records = decoded
        }
        publishRecent()
    }

    func add(_ record: DictationRecord) {
        records.insert(record, at: 0)
        if records.count > Self.limit { records.removeLast(records.count - Self.limit) }
        save()
    }

    func delete(_ ids: Set<UUID>) {
        records.removeAll { ids.contains($0.id) }
        save()
    }

    func clear() {
        records.removeAll()
        save()
    }

    var stats: DictationStats { DictationStats(records: records) }

    private func publishRecent() {
        SharedStore.recentHistory = records.prefix(Self.keyboardLimit).map {
            RecentDictation(id: $0.id, date: $0.date, text: $0.finalText, modeName: $0.modeName)
        }
    }

    private func save() {
        publishRecent()
        let snapshot = records
        let url = fileURL
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            }
        }
    }
}
