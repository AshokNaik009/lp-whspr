import AppIntents
import SwiftUI
import WidgetKit

@main
struct LeapWidgetBundle: WidgetBundle {
    var body: some Widget {
        DictateWidget()
        DictateControl()
    }
}

struct DictateEntry: TimelineEntry {
    let date: Date
}

struct DictateProvider: TimelineProvider {
    func placeholder(in context: Context) -> DictateEntry { DictateEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (DictateEntry) -> Void) { completion(DictateEntry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DictateEntry>) -> Void) {
        completion(Timeline(entries: [DictateEntry(date: .now)], policy: .never))
    }
}

struct DictateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LeapWhisperDictate", provider: DictateProvider()) { _ in
            DictateWidgetView()
                .widgetURL(AppGroup.sessionURL(startWithMode: nil))
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [.indigo, .blue], startPoint: .top, endPoint: .bottom)
                }
        }
        .configurationDisplayName("Dictate")
        .description("Start a Leap Whisper dictation.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct DictateWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "waveform").font(.title2)
            }
        case .accessoryRectangular:
            Label("Leap Whisper", systemImage: "waveform")
        default:
            VStack(spacing: 10) {
                Image(systemName: "mic.fill").font(.system(size: 36, weight: .semibold))
                Text("Dictate").font(.headline)
            }
            .foregroundStyle(.white)
        }
    }
}

struct DictateControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "LeapWhisperDictateControl") {
            ControlWidgetButton(action: StartDictationIntent()) {
                Label("Leap Whisper", systemImage: "waveform")
            }
        }
        .displayName("Leap Whisper")
        .description("Start dictation.")
    }
}
