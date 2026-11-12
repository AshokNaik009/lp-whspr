import SwiftUI

struct KeyboardView: View {
    @ObservedObject var model: KeyboardModel

    var body: some View {
        VStack(spacing: 10) {
            modeBar
            Spacer(minLength: 0)
            micButton
            statusLine
            Spacer(minLength: 0)
            bottomRow
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var modeBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(model.modes) { mode in
                    Button { model.select(mode) } label: {
                        Label(mode.name, systemImage: mode.symbol)
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(model.selectedModeID == mode.id ? Color.accentColor : Color(.systemGray5), in: Capsule())
                            .foregroundStyle(model.selectedModeID == mode.id ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var micButton: some View {
        HStack(spacing: 24) {
            if model.state == .recording {
                Button(action: model.cancelTapped) {
                    Image(systemName: "xmark").font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray4), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel recording")
            }
            Button(action: model.micTapped) {
                ZStack {
                    Circle()
                        .fill(model.state == .recording ? Color.red : Color.accentColor)
                        .frame(width: 84, height: 84)
                    if model.state == .transcribing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: model.state == .recording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.state == .recording ? "Stop dictation" : "Start dictation")
        }
    }

    private var statusLine: some View {
        Text(statusText)
            .font(.caption)
            .foregroundStyle(model.state == .error || model.hint != nil ? Color.orange : Color.secondary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(minHeight: 30)
    }

    private var statusText: String {
        if let hint = model.hint { return hint }
        switch model.state {
        case .recording: return "Listening… tap to finish"
        case .transcribing: return "Transcribing…"
        case .error: return model.statusMessage ?? "Something went wrong"
        case .idle:
            if let message = model.statusMessage, model.sessionAlive { return message }
            return model.sessionAlive ? "Tap to dictate" : "Tap to start a Leap Whisper session"
        }
    }

    private var bottomRow: some View {
        HStack(spacing: 6) {
            if model.showsGlobeKey {
                key(systemImage: "globe", width: 44, action: model.nextKeyboard)
            }
            key(title: "space", action: model.insertSpace)
            key(systemImage: "delete.left", width: 54, action: model.deleteBackward)
            key(systemImage: "return", width: 54, action: model.insertReturn)
        }
        .frame(height: 42)
    }

    private func key(title: String? = nil, systemImage: String? = nil, width: CGFloat? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let systemImage { Image(systemName: systemImage) } else { Text(title ?? "") }
            }
            .font(.body)
            .frame(maxWidth: width ?? .infinity, maxHeight: .infinity)
            .frame(width: width)
            .background(Color(.systemBackground).opacity(0.9), in: RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.25), radius: 0, y: 1)
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }
}
