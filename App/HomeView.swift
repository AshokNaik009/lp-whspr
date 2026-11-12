import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var controller: DictationController
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var models: ModelManager
    @State private var selectedModeID = SharedStore.selectedModeID
    @State private var modes = SharedStore.modes

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if controller.openedFromKeyboard && controller.isSessionActive {
                        returnBanner
                    }
                    micButton
                    statusText
                    modePicker
                    if !controller.lastTranscript.isEmpty { transcriptCard }
                    if controller.isSessionActive {
                        Button("End session", role: .destructive) { controller.endSession() }
                            .buttonStyle(.bordered)
                    }
                    setupChecklist
                }
                .padding()
            }
            .navigationTitle("Leap Whisper")
            .onAppear {
                modes = SharedStore.modes
                selectedModeID = SharedStore.selectedModeID
            }
        }
    }

    private var returnBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.uturn.backward.circle.fill").font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text("Session is live").font(.headline)
                Text("Swipe back to your app (tap ◀ in the top-left corner). The keyboard mic now toggles recording directly.")
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    private var micButton: some View {
        Button {
            controller.toggleRecording()
        } label: {
            ZStack {
                Circle()
                    .fill(controller.state == .recording ? Color.red : Color.accentColor)
                    .frame(width: 140, height: 140)
                    .scaleEffect(1 + CGFloat(controller.level) * 0.25)
                    .animation(.easeOut(duration: 0.1), value: controller.level)
                if controller.state == .transcribing {
                    ProgressView().tint(.white).scaleEffect(1.6)
                } else {
                    Image(systemName: controller.state == .recording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(controller.state == .transcribing)
        .accessibilityLabel(controller.state == .recording ? "Stop recording" : "Start recording")
        .padding(.top, 8)
    }

    private var statusText: some View {
        VStack(spacing: 4) {
            Text(statusTitle).font(.headline)
            if let message = controller.statusMessage {
                Text(message).font(.footnote).foregroundStyle(controller.state == .error ? .red : .secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var statusTitle: String {
        switch controller.state {
        case .idle: return controller.isSessionActive ? "Ready — tap to talk" : "Tap to start a session"
        case .recording: return "Listening…"
        case .transcribing: return "Transcribing…"
        case .error: return "Something went wrong"
        }
    }

    private var modePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(modes) { mode in
                    Button {
                        selectedModeID = mode.id
                        SharedStore.selectedModeID = mode.id
                    } label: {
                        Label(mode.name, systemImage: mode.symbol)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(selectedModeID == mode.id ? Color.accentColor : Color(.secondarySystemBackground), in: Capsule())
                            .foregroundStyle(selectedModeID == mode.id ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Last transcript").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(controller.lastSource).font(.caption2).foregroundStyle(.secondary)
            }
            Text(controller.lastTranscript).textSelection(.enabled)
            Button {
                UIPasteboard.general.string = controller.lastTranscript
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .font(.footnote)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var setupChecklist: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Setup").font(.headline)
            checklistRow(
                done: models.selectedModelURL != nil || settings.groqAPIKey != nil,
                title: "Download a model or add a Groq key",
                detail: "Models tab for on-device, Settings for Groq."
            )
            checklistRow(
                done: false,
                title: "Add the Leap Whisper keyboard",
                detail: "Settings > General > Keyboard > Keyboards > Add New Keyboard > Leap Whisper, then turn on Allow Full Access."
            )
            Button("Open iOS Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .font(.footnote)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func checklistRow(done: Bool, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
