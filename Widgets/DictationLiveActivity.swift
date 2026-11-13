import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Dynamic Island and Lock Screen presence while the microphone is on (spec 009, FR-009-4 and FR-009-5).
struct DictationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DictationActivityAttributes.self) { context in
            HStack(spacing: 12) {
                DictationSymbol(phase: context.state.phase).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.phase.title).font(.headline)
                    DictationDetail(state: context.state).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                DictationButtons(phase: context.state.phase)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8))
            .activitySystemActionForegroundColor(.white)
            .foregroundStyle(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DictationSymbol(phase: context.state.phase).font(.title2).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    DictationDetail(state: context.state).font(.title3.monospacedDigit()).padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.phase.title).font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DictationButtons(phase: context.state.phase)
                }
            } compactLeading: {
                DictationSymbol(phase: context.state.phase)
            } compactTrailing: {
                // The island only appears when both sides have something to show.
                switch context.state.phase {
                case .recording: DictationTimer(since: context.state.since).frame(width: 44)
                case .transcribing: Image(systemName: "ellipsis").foregroundStyle(.secondary)
                case .ready: Text("Ready").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
            } minimal: {
                DictationSymbol(phase: context.state.phase)
            }
        }
    }
}

private extension DictationActivityAttributes.ContentState.Phase {
    var title: String {
        switch self {
        case .recording: return "Listening"
        case .transcribing: return "Transcribing…"
        case .ready: return "Mic is ready"
        }
    }

    var tint: Color {
        self == .recording ? Color(red: 1.0, green: 0.36, blue: 0.52) : Color(red: 0.56, green: 0.47, blue: 1.0)
    }
}

private struct DictationSymbol: View {
    let phase: DictationActivityAttributes.ContentState.Phase

    var body: some View {
        Image(systemName: phase == .transcribing ? "sparkles" : phase == .recording ? "waveform" : "mic.fill")
            .foregroundStyle(phase.tint)
    }
}

/// Counts up on its own; the app doesn't push an update every second.
private struct DictationTimer: View {
    let since: Date

    var body: some View {
        Text(timerInterval: since...Date.distantFuture, countsDown: false)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
    }
}

private struct DictationDetail: View {
    let state: DictationActivityAttributes.ContentState

    var body: some View {
        switch state.phase {
        case .recording: DictationTimer(since: state.since)
        case .transcribing: Text("Almost there")
        case .ready: Text("Tap the keyboard mic")
        }
    }
}

private struct DictationButtons: View {
    let phase: DictationActivityAttributes.ContentState.Phase

    var body: some View {
        HStack(spacing: 10) {
            switch phase {
            case .recording:
                Button(intent: ToggleDictationIntent()) { Label("Stop", systemImage: "stop.fill") }
                    .tint(phase.tint)
                Button(intent: CancelDictationIntent()) { Label("Cancel", systemImage: "xmark") }
                    .tint(.gray)
            case .ready:
                Button(intent: ToggleDictationIntent()) { Label("Dictate", systemImage: "mic.fill") }
                    .tint(phase.tint)
                Button(intent: TurnMicOffIntent()) { Label("Mic off", systemImage: "mic.slash.fill") }
                    .tint(.gray)
            case .transcribing:
                EmptyView()
            }
        }
        .buttonStyle(.borderedProminent)
        .font(.subheadline.weight(.semibold))
    }
}
