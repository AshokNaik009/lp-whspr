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
            modeBar
            Spacer(minLength: 0)
            controls
            statusStrip
            Spacer(minLength: 0)
            bottomRow
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .font(.footnote.weight(.semibold))
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
            sideSlot { cancelButton }
            Spacer()
            micOrb
            Spacer()
            sideSlot { timer }
        }
        .padding(.horizontal, 28)
    }

    private func sideSlot<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack { if isRecording { content().transition(.scale.combined(with: .opacity)) } }
            .frame(width: 56, height: 44)
    }

    private var cancelButton: some View {
        Button(action: model.cancelTapped) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
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
                .font(.system(.subheadline, design: .rounded).weight(.semibold).monospacedDigit())
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
                            .font(.system(size: isRecording ? 26 : 30, weight: .semibold))
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
            if let live = model.liveText, !live.isEmpty, model.hint == nil {
                Text(live)
                    .font(.subheadline)
                    .foregroundStyle(isTranscribing ? Color.secondary : Color.primary)
                    .lineLimit(2)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.easeOut(duration: 0.2), value: live)
            } else {
                Text(statusText)
                    .font(.footnote.weight(.medium))
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
            return model.sessionAlive ? "Tap the orb and start talking" : "Tap to start a Leap Whisper session"
        }
    }

    // MARK: Keys

    private var bottomRow: some View {
        HStack(spacing: 6) {
            if model.showsGlobeKey {
                key(systemImage: "globe", width: 46, action: model.nextKeyboard)
            }
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
            .font(.system(size: 16, weight: .medium))
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
