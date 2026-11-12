import SwiftUI
import UIKit

enum Theme {
    static let accent = Color(red: 0.43, green: 0.36, blue: 0.98)
    static let accentSecondary = Color(red: 0.18, green: 0.60, blue: 1.0)
    static let gradient = LinearGradient(colors: [accent, accentSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct HomeView: View {
    @EnvironmentObject private var controller: DictationController
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var models: ModelManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedModeID = SharedStore.selectedModeID
    @State private var modes = SharedStore.modes
    @State private var levels = HomeView.silentLevels
    @State private var recordingStart: Date?
    @State private var keyboardInstalled = KeyboardStatus.isInstalled
    @State private var keyboardFullAccess = KeyboardStatus.hasFullAccess
    @State private var copied = false
    @State private var showsOnboarding = false
    @AppStorage("onboarding.presented") private var onboardingPresented = false

    private static let silentLevels = [CGFloat](repeating: 0, count: 36)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    if controller.openedFromKeyboard && controller.isSessionActive {
                        returnBanner
                    }
                    recorderCard
                    modeSection
                    if !controller.lastTranscript.isEmpty { transcriptCard }
                    if !setupComplete { setupChecklist }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                modes = SharedStore.modes
                selectedModeID = SharedStore.selectedModeID
                refreshKeyboardStatus()
                if !onboardingPresented && !setupComplete {
                    onboardingPresented = true
                    showsOnboarding = true
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshKeyboardStatus() }
            }
            .sheet(isPresented: $showsOnboarding, onDismiss: refreshKeyboardStatus) {
                OnboardingView()
            }
            .onChange(of: controller.level) { _, value in
                guard controller.state == .recording else { return }
                levels.removeFirst()
                levels.append(min(1, max(0, CGFloat(value))))
            }
            .onChange(of: controller.state) { _, state in
                recordingStart = state == .recording ? Date() : nil
                if state != .recording { levels = Self.silentLevels }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Leap Whisper").font(.title2.weight(.bold))
                Text("Speak naturally. It types for you.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Label(engineTitle, systemImage: engineSymbol)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(hasEngine ? Color.primary : Color.orange)
        }
        .padding(.top, 12)
    }

    private var hasEngine: Bool { models.selectedModelURL != nil || settings.groqAPIKey != nil }

    private var engineTitle: String {
        if settings.transcriptionBackend == .groq { return "Groq Cloud" }
        guard let file = settings.selectedModelFile, models.selectedModelURL != nil else {
            return settings.groqAPIKey != nil ? "Groq Cloud" : "No model"
        }
        return WhisperModelInfo.catalog.first { $0.file == file }?.title ?? "On-device"
    }

    private var engineSymbol: String {
        if !hasEngine { return "exclamationmark.triangle.fill" }
        return engineTitle == "Groq Cloud" ? "cloud.fill" : "iphone"
    }

    private var returnBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.title2)
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text("Session is live").font(.headline)
                Text("Swipe back to your app (tap ◀ in the top-left corner). The keyboard mic now toggles recording directly.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Recorder

    private var isRecording: Bool { controller.state == .recording }

    private var recorderCard: some View {
        VStack(spacing: 18) {
            micButton
            waveform
            VStack(spacing: 4) {
                Text(statusTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                statusDetail
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            if controller.isSessionActive && !isRecording {
                Button("End session") { controller.endSession() }
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.18), in: Capsule())
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Theme.accent.opacity(0.35), radius: 18, y: 8)
    }

    private var micButton: some View {
        let level = CGFloat(controller.level)
        return Button {
            controller.toggleRecording()
        } label: {
            ZStack {
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .stroke(.white.opacity(0.22 - Double(ring) * 0.06), lineWidth: 2)
                        .frame(width: 124 + CGFloat(ring) * 30, height: 124 + CGFloat(ring) * 30)
                        .scaleEffect(isRecording ? 1 + level * 0.12 * CGFloat(ring + 1) : 1)
                }
                Circle()
                    .fill(isRecording ? Color.red : Color.white)
                    .frame(width: 108, height: 108)
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
                if controller.state == .transcribing {
                    ProgressView().tint(Theme.accent).scaleEffect(1.5)
                } else {
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(isRecording ? AnyShapeStyle(.white) : AnyShapeStyle(Theme.gradient))
                }
            }
            .frame(width: 200, height: 200)
            .animation(.easeOut(duration: 0.12), value: controller.level)
            .animation(.spring(duration: 0.3), value: isRecording)
        }
        .buttonStyle(.plain)
        .disabled(controller.state == .transcribing)
        .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
    }

    private var waveform: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(levels.indices, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(isRecording ? 0.9 : 0.35))
                    .frame(width: 4, height: max(4, levels[index] * 40))
            }
        }
        .frame(height: 40)
        .animation(.easeOut(duration: 0.1), value: levels)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var statusDetail: some View {
        if isRecording, let start = recordingStart {
            TimelineView(.periodic(from: start, by: 1)) { context in
                Text(Self.elapsed(from: start, to: context.date))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))
            }
        } else if let message = controller.statusMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(controller.state == .error ? Color(red: 1, green: 0.85, blue: 0.85) : .white.opacity(0.8))
        } else {
            Text(controller.isSessionActive ? "Tap the mic and start talking" : "Starts a session the keyboard can use")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var statusTitle: String {
        switch controller.state {
        case .idle: return controller.isSessionActive ? "Ready to listen" : "Tap to start"
        case .recording: return "Listening…"
        case .transcribing: return "Transcribing…"
        case .error: return "Something went wrong"
        }
    }

    private static func elapsed(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: Modes

    private var selectedMode: DictationMode? { modes.first { $0.id == selectedModeID } }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Mode")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(modes) { mode in
                    modeTile(mode)
                }
            }
            if let hint = modeHint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func modeTile(_ mode: DictationMode) -> some View {
        let selected = mode.id == selectedModeID
        return Button {
            selectedModeID = mode.id
            SharedStore.selectedModeID = mode.id
        } label: {
            VStack(spacing: 6) {
                Image(systemName: mode.symbol).font(.title3)
                Text(mode.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                selected ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Color(.secondarySystemBackground)),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var modeHint: String? {
        guard let mode = selectedMode else { return nil }
        if mode.isVerbatim { return "Inserts exactly what you said." }
        if settings.optimizerBackend == .off {
            return "Turn on an optimizer in Settings to apply \(mode.name) rewriting."
        }
        return nil
    }

    // MARK: Transcript

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("Last transcript")
                Spacer()
                if !controller.lastSource.isEmpty {
                    Text(controller.lastSource)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }
            Text(controller.lastTranscript)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 16) {
                Button {
                    UIPasteboard.general.string = controller.lastTranscript
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                ShareLink(item: controller.lastTranscript) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            .font(.footnote.weight(.semibold))
            .tint(Theme.accent)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Setup

    private var setupComplete: Bool { hasEngine && keyboardInstalled && keyboardFullAccess }

    private func refreshKeyboardStatus() {
        keyboardInstalled = KeyboardStatus.isInstalled
        keyboardFullAccess = KeyboardStatus.hasFullAccess
    }

    private var setupChecklist: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Get set up")
            VStack(spacing: 0) {
                checklistRow(
                    done: hasEngine,
                    title: "Add a speech engine",
                    detail: "Download a model in Models, or add a Groq key in Settings."
                )
                Divider().padding(.leading, 44)
                checklistRow(
                    done: keyboardInstalled,
                    title: "Add the Leap Whisper keyboard",
                    detail: "Settings › Leap Whisper › Keyboards."
                )
                Divider().padding(.leading, 44)
                checklistRow(
                    done: keyboardFullAccess,
                    title: "Allow Full Access",
                    detail: "Then open the keyboard once with the 🌐 key."
                )
                Button {
                    showsOnboarding = true
                } label: {
                    Label("Show me how", systemImage: "list.number")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .tint(Theme.accent)
                .padding(.leading, 44)
                .padding(.vertical, 10)
            }
            .padding(.horizontal, 14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func checklistRow(done: Bool, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(done ? Color.green : Color.secondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(done, color: .secondary)
                    .foregroundStyle(done ? .secondary : .primary)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 4)
    }
}
