import SwiftUI
import UIKit

enum KeyboardStatus {
    /// iOS lists enabled keyboards (by bundle identifier) in the global `AppleKeyboards` default.
    static var isInstalled: Bool {
        guard let appID = Bundle.main.bundleIdentifier,
              let keyboards = UserDefaults.standard.array(forKey: "AppleKeyboards") as? [String] else { return false }
        return keyboards.contains { $0.hasPrefix(appID + ".") }
    }

    /// Set by the keyboard the first time it runs with Full Access (it can only write to the App Group then).
    static var hasFullAccess: Bool { SharedStore.keyboardHasConnected }

    static func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}

/// Guided first-run setup: model download, adding the keyboard, Full Access and a practice field.
struct OnboardingView: View {
    @EnvironmentObject private var models: ModelManager
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var keyboardInstalled = KeyboardStatus.isInstalled
    @State private var fullAccess = KeyboardStatus.hasFullAccess
    @State private var practiceText = ""

    private static let starterModel = WhisperModelInfo.catalog.first { $0.file == "ggml-base.en-q5_1.bin" }!

    private var hasEngine: Bool { models.selectedModelURL != nil || settings.groqAPIKey != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Four quick steps and you can dictate into any app: WhatsApp, Notes, Mail, Slack.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                    modelStep
                    keyboardStep
                    fullAccessStep
                    practiceStep
                }
                .padding(20)
            }
            .navigationTitle("Set up Leap Whisper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .task {
                while !Task.isCancelled {
                    keyboardInstalled = KeyboardStatus.isInstalled
                    fullAccess = KeyboardStatus.hasFullAccess
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }
        .tint(Theme.accent)
    }

    // MARK: Steps

    private var modelStep: some View {
        StepCard(number: 1, title: "Download a speech model", done: hasEngine) {
            Text("Runs entirely on your iPhone, works offline. You can switch models or add Groq later.")
            if let progress = models.progress[Self.starterModel.file] {
                ProgressView(value: progress) {
                    Text("Downloading \(Self.starterModel.title)… \(Int(progress * 100))%")
                        .font(.caption)
                }
            } else if !hasEngine {
                Button {
                    models.download(Self.starterModel)
                } label: {
                    Label("Download \(Self.starterModel.title) · \(ByteCountFormatter.string(fromByteCount: Self.starterModel.bytes, countStyle: .file))", systemImage: "arrow.down.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            if let error = models.lastError {
                Text(error).foregroundStyle(.red)
            }
        }
    }

    private var keyboardStep: some View {
        StepCard(number: 2, title: "Add the Leap Whisper keyboard", done: keyboardInstalled) {
            InstructionList(items: [
                "Tap Open Settings below.",
                "Tap Keyboards.",
                "Turn on Leap Whisper.",
            ])
            Text("Or: Settings › General › Keyboard › Keyboards › Add New Keyboard › Leap Whisper.")
                .foregroundStyle(.tertiary)
            if !keyboardInstalled { settingsButton }
        }
    }

    private var fullAccessStep: some View {
        StepCard(number: 3, title: "Turn on Allow Full Access", done: fullAccess) {
            Text("On the same screen, turn on Allow Full Access and tap Allow. The keyboard needs it to talk to the app that records your voice. Your other keystrokes are never stored or sent anywhere.")
            if keyboardInstalled && !fullAccess {
                Text("Ticks itself off the first time you open the keyboard in step 4.")
                    .foregroundStyle(.tertiary)
            }
            if !fullAccess { settingsButton }
        }
    }

    private var practiceStep: some View {
        StepCard(number: 4, title: "Try it here", done: !practiceText.isEmpty) {
            InstructionList(items: [
                "Tap the box below.",
                "Long-press 🌐 at the bottom left and pick Leap Whisper.",
                "Tap the mic, speak, tap again. The text appears here.",
            ])
            Text("In other apps, the first tap opens Leap Whisper to start the mic. Swipe back (◀ top left) and keep dictating; it stays ready for 10 minutes.")
                .foregroundStyle(.tertiary)
            TextField("Practice here…", text: $practiceText, axis: .vertical)
                .lineLimit(3...6)
                .padding(12)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .font(.body)
                .foregroundStyle(.primary)
        }
    }

    private var settingsButton: some View {
        Button {
            KeyboardStatus.openSettings()
        } label: {
            Label("Open Settings", systemImage: "arrow.up.forward.app")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}

private struct StepCard<Content: View>: View {
    let number: Int
    let title: String
    let done: Bool
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(done ? AnyShapeStyle(Color.green) : AnyShapeStyle(Theme.gradient))
                    .frame(width: 30, height: 30)
                if done {
                    Image(systemName: "checkmark").font(.footnote.weight(.bold))
                } else {
                    Text("\(number)").font(.footnote.weight(.bold))
                }
            }
            .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline)
                content
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .opacity(done ? 0.75 : 1)
    }
}

private struct InstructionList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(Character(UnicodeScalar(UInt8(97 + index))))."  ).fontWeight(.semibold)
                    Text(item)
                }
            }
        }
    }
}
