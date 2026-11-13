import SwiftUI

private enum KeyboardTheme {
    static let accent = Color(red: 0.56, green: 0.47, blue: 1.0)
    static let accentSecondary = Color(red: 0.27, green: 0.66, blue: 1.0)
    static let recording = Color(red: 1.0, green: 0.36, blue: 0.52)
    static let recordingSecondary = Color(red: 1.0, green: 0.55, blue: 0.35)
    static let idleGradient = LinearGradient(colors: [accent, accentSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let recordingGradient = LinearGradient(colors: [recording, recordingSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct KeyboardView: View {
    @ObservedObject var model: KeyboardModel

    private var isRecording: Bool { model.state == .recording }
    private var isTranscribing: Bool { model.state == .transcribing }

    var body: some View {
        VStack(spacing: 8) {
            if model.showingHistory {
                historyPanel
            } else {
                modeBar
                Spacer(minLength: 0)
                controls
                statusStrip
                Spacer(minLength: 0)
            }
            bottomRow
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if let gradient = model.background.gradient { gradient.ignoresSafeArea() }
        }
        .modifier(DarkOnGradient(active: model.background.gradient != nil))
        .environment(\.font, .jakarta(.body))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.state)
    }

    // MARK: Modes

    private var modeBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(model.modes) { mode in
                        modeChip(mode).id(mode.id)
                    }
                }
                .padding(.horizontal, 2)
            }
            .onAppear { proxy.scrollTo(model.selectedModeID, anchor: .center) }
        }
        .disabled(isRecording || isTranscribing)
        .opacity(isRecording || isTranscribing ? 0.55 : 1)
    }

    private func modeChip(_ mode: DictationMode) -> some View {
        let selected = model.selectedModeID == mode.id
        return Button { model.select(mode) } label: {
            Label(mode.name, systemImage: mode.symbol)
                .font(.jakarta(.footnote, .semibold))
                .padding(.horizontal, 11).padding(.vertical, 7)
                .background {
                    if selected {
                        Capsule().fill(KeyboardTheme.idleGradient)
                    } else {
                        Capsule().fill(.ultraThinMaterial)
                            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
                    }
                }
                .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.8))
        }
        .buttonStyle(.plain)
    }

    // MARK: Mic

    private var controls: some View {
        HStack {
            sideSlot(visible: isRecording) { cancelButton }
            Spacer()
            micOrb
            Spacer()
            sideSlot(visible: isRecording || model.micIsReady) {
                if isRecording { timer } else { micOffButton }
            }
        }
        .padding(.horizontal, 28)
    }

    private func sideSlot<Content: View>(visible: Bool, @ViewBuilder _ content: () -> Content) -> some View {
        ZStack { if visible { content().transition(.scale.combined(with: .opacity)) } }
            .frame(width: 56, height: 44)
    }

    private var micOffButton: some View {
        Button(action: model.micOffTapped) {
            Image(systemName: "mic.slash.fill")
                .font(.jakarta(size: 14, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.7))
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Turn the microphone off")
    }

    private var cancelButton: some View {
        Button(action: model.cancelTapped) {
            Image(systemName: "xmark")
                .font(.jakarta(size: 15, weight: .bold))
                .foregroundStyle(.primary.opacity(0.8))
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cancel recording")
    }

    private var timer: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(Self.elapsed(from: model.recordingStartedAt ?? context.date, to: context.date))
                .font(.jakarta(.subheadline, .semibold).monospacedDigit())
                .foregroundStyle(KeyboardTheme.recording)
        }
    }

    private var micOrb: some View {
        Button(action: model.micTapped) {
            ZStack {
                if isRecording { PulseRings(color: KeyboardTheme.recording) }
                Circle()
                    .fill(isRecording ? KeyboardTheme.recordingGradient : KeyboardTheme.idleGradient)
                    .overlay(
                        Circle().fill(
                            RadialGradient(colors: [.white.opacity(0.45), .clear], center: .init(x: 0.3, y: 0.25), startRadius: 2, endRadius: 40)
                        )
                    )
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                    .frame(width: 76, height: 76)
                    .shadow(color: (isRecording ? KeyboardTheme.recording : KeyboardTheme.accent).opacity(0.55), radius: 16)
                Group {
                    if isTranscribing {
                        ProgressView().tint(.white).controlSize(.large)
                    } else {
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.jakarta(size: isRecording ? 26 : 30, weight: .semibold))
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .foregroundStyle(.white)
            }
            .frame(width: 96, height: 96)
            .contentShape(Circle())
        }
        .buttonStyle(OrbPressStyle())
        .accessibilityLabel(isRecording ? "Stop dictation" : "Start dictation")
    }

    // MARK: Status / live text

    private var statusStrip: some View {
        HStack(spacing: 10) {
            if isRecording {
                WaveBars(color: KeyboardTheme.recording).frame(width: 28, height: 18)
            } else if isTranscribing {
                Image(systemName: "sparkles").foregroundStyle(KeyboardTheme.accent)
            }
            if let live = model.liveText, !live.isEmpty, model.hint == nil, !isTranscribing {
                Text(live)
                    .font(.jakarta(.subheadline))
                    .foregroundStyle(isTranscribing ? Color.secondary : Color.primary)
                    .lineLimit(2)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.easeOut(duration: 0.2), value: live)
            } else if isTranscribing && model.hint == nil {
                TimelineView(.periodic(from: .now, by: 1.5)) { context in
                    Text(BusyPhrases.phrase(at: context.date))
                        .font(.jakarta(.footnote, .semibold))
                        .foregroundStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.easeInOut(duration: 0.3), value: context.date)
                }
            } else {
                Text(statusText)
                    .font(.jakarta(.footnote, .medium))
                    .foregroundStyle(model.state == .error || model.hint != nil ? Color.orange : Color.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(isRecording || isTranscribing ? .leading : .center)
                    .frame(maxWidth: .infinity, alignment: isRecording || isTranscribing ? .leading : .center)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background {
            if isRecording || isTranscribing || model.hint != nil {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
                    .transition(.opacity)
            }
        }
    }

    private var statusText: String {
        if let hint = model.hint { return hint }
        switch model.state {
        case .recording: return "Listening…"
        case .transcribing: return "Polishing your words…"
        case .error: return model.statusMessage ?? "Something went wrong"
        case .idle:
            if let message = model.statusMessage, model.sessionAlive { return message }
            if model.sessionAlive { return "Mic is ready. Tap the orb and start talking" }
            return model.micStandby.keepsMicAfterDictation
                ? "Tap to start. Leap Whisper opens once, then the mic stays ready"
                : "Tap to dictate (Leap Whisper opens briefly)"
        }
    }

    // MARK: History

    private var historyPanel: some View {
        VStack(spacing: 6) {
            HStack {
                Label("Recent dictations", systemImage: "clock.arrow.circlepath")
                    .font(.jakarta(.footnote, .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button { model.toggleHistory() } label: {
                    Image(systemName: "xmark")
                        .font(.jakarta(size: 12, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close history")
            }
            .padding(.horizontal, 4)

            if model.history.isEmpty {
                Text("Nothing yet. Your dictations will show up here.")
                    .font(.jakarta(.footnote))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(model.history) { item in
                            historyRow(item)
                        }
                    }
                }
            }
        }
        .transition(.opacity)
    }

    private func historyRow(_ item: RecentDictation) -> some View {
        Button { model.insertFromHistory(item) } label: {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.text)
                        .font(.jakarta(.subheadline))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text("\(item.date.formatted(.relative(presentation: .named))) · \(item.modeName)")
                        .font(.jakarta(.caption2))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.left")
                    .font(.jakarta(.caption, .semibold))
                    .foregroundStyle(KeyboardTheme.accent)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityHint("Inserts this text")
    }

    // MARK: Keys

    private var bottomRow: some View {
        HStack(spacing: 6) {
            if model.showsGlobeKey {
                key(systemImage: "globe", width: 46, action: model.nextKeyboard)
            }
            key(systemImage: model.showingHistory ? "mic" : "clock.arrow.circlepath", width: 46, action: model.toggleHistory)
                .disabled(isRecording || isTranscribing)
                .accessibilityLabel(model.showingHistory ? "Back to dictation" : "Recent dictations")
            key(title: "space", action: model.insertSpace)
            key(systemImage: "delete.left", width: 56, action: model.deleteBackward)
            key(systemImage: "return", width: 56, action: model.insertReturn)
        }
        .frame(height: 42)
    }

    private func key(title: String? = nil, systemImage: String? = nil, width: CGFloat? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let systemImage { Image(systemName: systemImage) } else { Text(title ?? "") }
            }
            .font(.jakarta(size: 16, weight: .medium))
            .frame(maxWidth: width ?? .infinity, maxHeight: .infinity)
            .frame(width: width)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
            .foregroundStyle(.primary)
        }
        .buttonStyle(KeyPressStyle())
    }

    private static func elapsed(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct PulseRings: View {
    let color: Color

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<2) { i in
                    let phase = (t / 1.6 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .stroke(color.opacity(0.5 * (1 - phase)), lineWidth: 2)
                        .frame(width: 76 + 26 * phase, height: 76 + 26 * phase)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Decorative "listening" bars; the keyboard has no access to the live mic level.
private struct WaveBars: View {
    let color: Color

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<5) { i in
                    let h = 0.35 + 0.65 * abs(sin(t * 5 + Double(i) * 0.9))
                    Capsule().fill(color).frame(width: 3, height: 18 * h)
                }
            }
        }
    }
}

private struct OrbPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

private struct KeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

/// Gradient backgrounds are dark enough that the keyboard reads best in dark appearance.
private struct DarkOnGradient: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active { content.environment(\.colorScheme, .dark) } else { content }
    }
}
