import Charts
import SwiftUI

struct StatsView: View {
    @ObservedObject private var history = HistoryStore.shared

    var body: some View {
        let stats = history.stats
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(title: "Words dictated", value: stats.words.formatted(), systemImage: "text.word.spacing")
                        StatCard(title: "Time saved", value: Self.duration(minutes: stats.minutesSaved), systemImage: "hourglass",
                                 footnote: "vs typing at \(Int(DictationStats.typingWordsPerMinute)) WPM")
                        StatCard(title: "Speaking speed", value: "\(Int(stats.wordsPerMinute.rounded())) WPM", systemImage: "speedometer")
                        StatCard(title: "Streak", value: "\(stats.currentStreakDays) day\(stats.currentStreakDays == 1 ? "" : "s")", systemImage: "flame")
                        StatCard(title: "Dictations", value: stats.dictations.formatted(), systemImage: "waveform")
                        StatCard(title: "On-device", value: stats.onDeviceShare.formatted(.percent.precision(.fractionLength(0))),
                                 systemImage: "iphone", footnote: "\(stats.cloudCount) sent to Groq")
                        StatCard(title: "Audio recorded", value: Self.duration(minutes: stats.audioSeconds / 60), systemImage: "mic")
                        StatCard(title: "Avg. processing", value: String(format: "%.1f s", stats.averageProcessingSeconds), systemImage: "bolt")
                    }

                    GroupBox("Last 7 days") {
                        Chart(stats.wordsLast7Days, id: \.0) { item in
                            BarMark(x: .value("Day", item.0, unit: .day), y: .value("Words", item.1))
                                .foregroundStyle(.tint)
                        }
                        .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) } }
                        .frame(height: 160)
                    }

                    if !stats.wordsByMode.isEmpty {
                        GroupBox("Words by mode") {
                            ForEach(stats.wordsByMode, id: \.0) { item in
                                HStack {
                                    Text(item.0)
                                    Spacer()
                                    Text(item.1.formatted()).foregroundStyle(.secondary).monospacedDigit()
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Stats")
        }
    }

    static func duration(minutes: Double) -> String {
        if minutes < 1 { return "\(Int((minutes * 60).rounded())) s" }
        if minutes < 60 { return "\(Int(minutes.rounded())) min" }
        return String(format: "%.1f h", minutes / 60)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage).font(.jakarta(.caption)).foregroundStyle(.secondary)
            Text(value).font(.jakarta(.title2, .bold)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
            if let footnote { Text(footnote).font(.jakarta(.caption2)).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}
