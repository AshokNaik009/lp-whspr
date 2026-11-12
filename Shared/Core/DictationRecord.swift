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

extension DictationStats {
    init(records: [DictationRecord], now: Date = Date(), calendar: Calendar = .current) {
        self.init()
        dictations = records.count
        var byMode: [String: Int] = [:]
        var processing: Double = 0
        var wordsByDay: [Date: Int] = [:]
        for record in records {
            let words = record.wordCount
            self.words += words
            audioSeconds += record.audioSeconds
            if record.usedCloud { cloudCount += 1 }
            byMode[record.modeName, default: 0] += words
            processing += record.processingSeconds
            wordsByDay[calendar.startOfDay(for: record.date), default: 0] += words
        }
        averageProcessingSeconds = records.isEmpty ? 0 : processing / Double(records.count)
        wordsByMode = byMode.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }

        let today = calendar.startOfDay(for: now)
        wordsLast7Days = (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map { ($0, wordsByDay[$0] ?? 0) }
        }
        var day = wordsByDay[today] != nil ? today : calendar.date(byAdding: .day, value: -1, to: today)!
        while wordsByDay[day] != nil {
            currentStreakDays += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
    }
}
