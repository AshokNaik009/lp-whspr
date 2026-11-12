import Foundation

struct DictationRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    var rawText: String
    var finalText: String
    var modeID: String
    var modeName: String
    var engine: String
    var usedCloud: Bool
    var confidence: Double?
    var audioSeconds: Double
    var processingSeconds: Double

    var wordCount: Int { finalText.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count }
}

struct DictationStats {
    var dictations = 0
    var words = 0
    var audioSeconds: Double = 0
    var cloudCount = 0
    var averageProcessingSeconds: Double = 0
    var currentStreakDays = 0
    var wordsByMode: [(String, Int)] = []
    var wordsLast7Days: [(Date, Int)] = []

    /// Typing speed used to estimate time saved; average phone typing is roughly 40 WPM.
    static let typingWordsPerMinute: Double = 40

    var wordsPerMinute: Double { audioSeconds > 0 ? Double(words) / (audioSeconds / 60) : 0 }
    var minutesSaved: Double { max(0, Double(words) / Self.typingWordsPerMinute - audioSeconds / 60) }
    var onDeviceShare: Double { dictations > 0 ? Double(dictations - cloudCount) / Double(dictations) : 0 }
}

@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()
    private static let limit = 2000

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

    var stats: DictationStats {
        var stats = DictationStats()
        stats.dictations = records.count
        var byMode: [String: Int] = [:]
        var processing: Double = 0
        for record in records {
            let words = record.wordCount
            stats.words += words
            stats.audioSeconds += record.audioSeconds
            if record.usedCloud { stats.cloudCount += 1 }
            byMode[record.modeName, default: 0] += words
            processing += record.processingSeconds
        }
        stats.averageProcessingSeconds = records.isEmpty ? 0 : processing / Double(records.count)
        stats.wordsByMode = byMode.sorted { $0.value > $1.value }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var wordsByDay: [Date: Int] = [:]
        for record in records {
            wordsByDay[calendar.startOfDay(for: record.date), default: 0] += record.wordCount
        }
        stats.wordsLast7Days = (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map { ($0, wordsByDay[$0] ?? 0) }
        }
        var day = wordsByDay[today] != nil ? today : calendar.date(byAdding: .day, value: -1, to: today)!
        while wordsByDay[day] != nil {
            stats.currentStreakDays += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return stats
    }

    private func save() {
        let snapshot = records
        let url = fileURL
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            }
        }
    }
}
