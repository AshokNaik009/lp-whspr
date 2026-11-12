import SwiftUI

/// In-app tutorial: short how-tos for every feature, opened from Settings > Help.
struct GuideView: View {
    @State private var showsSetup = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Short how-tos for everything Leap Whisper does. Tap a topic to see the steps.")
                    .font(.jakarta(.subheadline))
                    .foregroundStyle(.secondary)

                Button {
                    showsSetup = true
                } label: {
                    row(icon: "sparkles", tint: .purple, title: "Run the setup walkthrough",
                        subtitle: "Download a model, add the keyboard, practice")
                }
                .buttonStyle(.plain)

                ForEach(GuideTopic.all) { topic in
                    NavigationLink {
                        GuideTopicView(topic: topic)
                    } label: {
                        row(icon: topic.icon, tint: topic.tint, title: topic.title, subtitle: topic.summary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(AuroraBackground().ignoresSafeArea())
        .navigationTitle("Guide")
        .sheet(isPresented: $showsSetup) { OnboardingView() }
    }

    private func row(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.jakarta(.title3, .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.jakarta(.headline))
                Text(subtitle).font(.jakarta(.footnote)).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.jakarta(.footnote, .semibold)).foregroundStyle(.tertiary)
        }
        .padding(14)
        .glassCard(cornerRadius: 20)
        .contentShape(Rectangle())
    }
}

struct GuideTopicView: View {
    let topic: GuideTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Image(systemName: topic.icon)
                        .font(.jakarta(.title, .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(topic.tint.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text(topic.summary).font(.jakarta(.subheadline)).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(topic.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.jakarta(.footnote, .bold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(topic.tint.gradient, in: Circle())
                            Text(step).font(.jakarta(.body)).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()

                if let tip = topic.tip {
                    Label {
                        Text(tip).font(.jakarta(.subheadline)).fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(tint: .yellow.opacity(0.15))
                }
            }
            .padding()
        }
        .background(AuroraBackground().ignoresSafeArea())
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct GuideTopic: Identifiable {
    let id: String
    let icon: String
    let tint: Color
    let title: String
    let summary: String
    let steps: [String]
    var tip: String? = nil

    static let all: [GuideTopic] = [
        GuideTopic(
            id: "dictate", icon: "mic.fill", tint: .purple, title: "Dictate in the app",
            summary: "Speak, and get clean text you can copy anywhere.",
            steps: [
                "Open the Dictate tab and turn the mode dial to the style you want.",
                "Tap the glowing orb and start talking. Your words appear live as you speak.",
                "Tap the orb again to stop. The final, more accurate text replaces the preview.",
                "Tap Copy on the transcript card, or find it later in History.",
            ],
            tip: "The Time saved card on the Dictate tab shows how much faster you are than typing at 40 words per minute."
        ),
        GuideTopic(
            id: "keyboard", icon: "keyboard.fill", tint: .blue, title: "Dictate from the keyboard",
            summary: "Use your voice in WhatsApp, Notes, Mail, Slack, anywhere.",
            steps: [
                "Settings > General > Keyboard > Keyboards > Add New Keyboard > Leap Whisper.",
                "Tap Leap Whisper in that list and turn on Allow Full Access.",
                "In any app, long-press the globe key and choose Leap Whisper.",
                "Tap the mic. The first time, Leap Whisper opens to start the microphone and jumps back by itself. If it doesn't, tap ◀ in the top-left corner.",
                "Speak, then tap ■. The text is typed straight into the app.",
            ],
            tip: "After the first tap the mic session stays on (30 minutes by default), so later taps record right inside the app. Change it in Settings > Session."
        ),
        GuideTopic(
            id: "modes", icon: "dial.medium.fill", tint: .pink, title: "Modes and the dial",
            summary: "Choose how your words get rewritten.",
            steps: [
                "Raw: exactly what you said.",
                "Clean: removes filler words and fixes punctuation.",
                "Message, Email, Notes and AI Prompt: rewrite your words in that style.",
                "To Arabic: speak in any language and get Arabic text.",
                "Turn the dial on the Dictate tab, or tap a chip on the keyboard, to switch modes.",
            ],
            tip: "Every mode except Raw needs a rewrite engine. Add a Groq key in Settings so Email and To Arabic always work."
        ),
        GuideTopic(
            id: "groq", icon: "bolt.fill", tint: .orange, title: "Add your Groq key",
            summary: "Cloud rewriting, translation and a backup for transcription.",
            steps: [
                "Create a free key at console.groq.com > API Keys.",
                "In Leap Whisper, go to Settings > Groq, paste the key and tap Save key.",
                "\"API key saved in Keychain\" means it's stored. The key is only sent to api.groq.com.",
                "Try Email or To Arabic. If the key is wrong, the app tells you instead of inserting unchanged text.",
            ]
        ),
        GuideTopic(
            id: "models", icon: "cpu.fill", tint: .teal, title: "Choose a speech model",
            summary: "On-device models keep your voice on your phone.",
            steps: [
                "Open the Models tab and download a model.",
                "large-v3-turbo is the most accurate and works best inside the app.",
                "Small (multilingual) is much faster for keyboard dictation, which runs without the GPU.",
                "Tap a model to use it. Tap the red trash button to delete one and free up space.",
                "Calibration in the Models tab compares models on your own voice.",
            ]
        ),
        GuideTopic(
            id: "history", icon: "clock.arrow.circlepath", tint: .indigo, title: "History",
            summary: "Every dictation is saved on your phone.",
            steps: [
                "The History tab lists everything you've dictated. Search, copy or delete entries.",
                "On the keyboard, tap the clock key to see your last 50 dictations.",
                "Tap one to insert it again without leaving the app you're in.",
            ]
        ),
        GuideTopic(
            id: "look", icon: "paintpalette.fill", tint: .mint, title: "Customise the look",
            summary: "Light or dark app theme, and a gradient keyboard.",
            steps: [
                "Go to Settings > Appearance: Glass is the aurora look, Light and Dark are flat ink-on-cream themes, System follows your iPhone.",
                "Go to Settings > Keyboard background.",
                "Pick Default, or one of the gradients: Aurora, Sunset, Ocean, Forest, Rose or Midnight.",
                "Pick Custom to choose your own start and end colours.",
                "Switch apps once if the keyboard doesn't update straight away.",
            ]
        ),
        GuideTopic(
            id: "demo", icon: "record.circle", tint: .red, title: "Record a demo",
            summary: "Show Leap Whisper to someone with a screen recording.",
            steps: [
                "Add Screen Recording in Settings > Control Center.",
                "Open WhatsApp or Notes and switch to the Leap Whisper keyboard.",
                "Swipe down from the top-right corner and tap the record button.",
                "Dictate a sentence in Clean mode, then the same sentence in To Arabic.",
                "Stop the recording. It's saved to Photos, ready to share.",
            ],
            tip: "Long-press the record button and turn on the Microphone so the video includes your voice."
        ),
    ]
}
