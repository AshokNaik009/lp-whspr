import SwiftUI
import UIKit

struct HistoryView: View {
    @ObservedObject private var history = HistoryStore.shared
    @State private var query = ""
    @State private var confirmClear = false

    private var filtered: [DictationRecord] {
        guard !query.isEmpty else { return history.records }
        return history.records.filter {
            $0.finalText.localizedCaseInsensitiveContains(query) || $0.rawText.localizedCaseInsensitiveContains(query)
        }
    }

    private var grouped: [(Date, [DictationRecord])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
        return groups.sorted { $0.key > $1.key }
    }

    var body: some View {
        NavigationStack {
            List {
                if history.records.isEmpty {
                    ContentUnavailableView("No dictations yet", systemImage: "clock",
                                           description: Text("Everything you dictate from the app or keyboard shows up here."))
                }
                ForEach(grouped, id: \.0) { group in
                    let records = group.1
                    Section(group.0.formatted(.dateTime.weekday(.wide).day().month())) {
                        ForEach(records) { record in
                            NavigationLink(value: record) { HistoryRow(record: record) }
                                .swipeActions(edge: .leading) {
                                    Button { UIPasteboard.general.string = record.finalText } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
                                    }.tint(.blue)
                                }
                        }
                        .onDelete { offsets in history.delete(Set(offsets.map { records[$0].id })) }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search transcripts")
            .navigationTitle("History")
            .navigationDestination(for: DictationRecord.self) { HistoryDetailView(record: $0) }
            .toolbar {
                if !history.records.isEmpty {
                    Button("Clear", role: .destructive) { confirmClear = true }
                }
            }
            .confirmationDialog("Delete all history?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Delete all", role: .destructive) { history.clear() }
            }
        }
    }
}

private struct HistoryRow: View {
    let record: DictationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.finalText).lineLimit(3)
            HStack(spacing: 6) {
                Text(record.date, style: .time)
                Text("·")
                Text(record.modeName)
                Text("·")
                Text("\(record.wordCount) words")
                Spacer()
                Image(systemName: record.usedCloud ? "cloud" : "iphone")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct HistoryDetailView: View {
    let record: DictationRecord

    var body: some View {
        List {
            Section("Result") {
                Text(record.finalText).textSelection(.enabled)
                Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = record.finalText }
                ShareLink(item: record.finalText)
            }
            if record.rawText != record.finalText {
                Section("Original transcript") { Text(record.rawText).textSelection(.enabled) }
            }
            Section("Details") {
                LabeledContent("Mode", value: record.modeName)
                LabeledContent("Engine", value: record.engine)
                if let confidence = record.confidence {
                    LabeledContent("Local confidence", value: confidence.formatted(.percent.precision(.fractionLength(0))))
                }
                LabeledContent("Audio", value: String(format: "%.1f s", record.audioSeconds))
                LabeledContent("Processing", value: String(format: "%.1f s", record.processingSeconds))
                LabeledContent("Words", value: "\(record.wordCount)")
                LabeledContent("Date", value: record.date.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .navigationTitle("Dictation")
        .navigationBarTitleDisplayMode(.inline)
    }
}
