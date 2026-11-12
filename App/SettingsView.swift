import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var groqKey = ""
    @State private var hasGroqKey = AppSettings.shared.groqAPIKey != nil

    private let languages = [
        ("auto", "Auto-detect"), ("en", "English"), ("ar", "Arabic"), ("hi", "Hindi"), ("es", "Spanish"),
        ("fr", "French"), ("de", "German"), ("pt", "Portuguese"), ("ru", "Russian"), ("zh", "Chinese"),
        ("ja", "Japanese"), ("ur", "Urdu"), ("ta", "Tamil"), ("ml", "Malayalam"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Transcription") {
                    Picker("Engine", selection: $settings.transcriptionBackend) {
                        ForEach(TranscriptionBackend.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Language", selection: $settings.language) {
                        ForEach(languages, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    TextField("Custom vocabulary (names, jargon)", text: $settings.vocabulary, axis: .vertical)
                    NavigationLink { CalibrationView() } label: { Label("Calibrate models", systemImage: "slider.horizontal.3") }
                }

                Section {
                    Toggle("Fall back to Groq", isOn: $settings.cloudFallbackEnabled)
                    if settings.cloudFallbackEnabled {
                        VStack(alignment: .leading) {
                            Text("Confidence threshold: \(Int(settings.fallbackConfidenceThreshold * 100))%")
                            Slider(value: $settings.fallbackConfidenceThreshold, in: 0.2...0.95, step: 0.05)
                        }
                    }
                } header: {
                    Text("Cloud fallback")
                } footer: {
                    Text("When the on-device result is below this confidence, or no model is installed, the recording is re-transcribed with Groq.")
                }

                Section("Optimization modes") {
                    NavigationLink { ModesView() } label: { Label("Edit modes", systemImage: "sparkles") }
                    Picker("Rewrite with", selection: $settings.optimizerBackend) {
                        ForEach(OptimizerBackend.allCases) { Text($0.title).tag($0) }
                    }
                    if settings.optimizerBackend == .apple && !TextOptimizer.isAppleModelAvailable {
                        Text("Apple Intelligence isn't available on this device.").font(.footnote).foregroundStyle(.orange)
                    }
                }

                Section {
                    if hasGroqKey {
                        HStack {
                            Label("API key saved in Keychain", systemImage: "key.fill")
                            Spacer()
                            Button("Remove", role: .destructive) {
                                settings.groqAPIKey = nil
                                hasGroqKey = false
                            }
                        }
                    } else {
                        SecureField("gsk_…", text: $groqKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Save key") {
                            settings.groqAPIKey = groqKey.trimmingCharacters(in: .whitespacesAndNewlines)
                            groqKey = ""
                            hasGroqKey = settings.groqAPIKey != nil
                        }
                        .disabled(groqKey.isEmpty)
                    }
                    TextField("Transcription model", text: $settings.groqTranscriptionModel)
                        .textInputAutocapitalization(.never)
                    TextField("Rewrite model", text: $settings.groqChatModel)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Groq")
                } footer: {
                    Text("The key is stored in this device's Keychain and only sent to api.groq.com.")
                }

                Section("Session") {
                    Stepper("Keep mic session alive: \(settings.sessionTimeoutMinutes) min", value: $settings.sessionTimeoutMinutes, in: 1...60)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
