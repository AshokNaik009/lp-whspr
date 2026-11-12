# Leap Whisper for iOS

Voice dictation for iPhone and iPad: a SwiftUI app plus a custom keyboard with a mic button that toggles
recording on and off and types the transcript into any app. Transcription runs on-device with
[whisper.cpp](https://github.com/ggml-org/whisper.cpp) (Metal-accelerated). Groq Cloud is a fallback
for low-confidence results, or it can be the main engine. Optimization modes (Clean, Message, Email,
Notes, AI Prompt, custom) rewrite the transcript with Apple Intelligence (on-device) or a Groq LLM.

## How the keyboard dictates

iOS does not let keyboard extensions use the microphone, so the app owns the mic:

1. The first mic tap in the keyboard opens Leap Whisper (`leapwhisper://session?start=1`). The app starts
   an `AVAudioEngine` session with the `audio` background mode and begins recording.
2. The user swipes back (◀ breadcrumb). The engine keeps running in the background, so the app stays alive.
3. From then on, the keyboard mic sends `start`/`stop` commands over Darwin notifications and the
   App Group. The app transcribes, applies the selected mode and publishes the text. The keyboard inserts it via
   `textDocumentProxy`.
4. The session ends after the idle timeout (Settings, default 10 min) or from the app.

The keyboard needs **Allow Full Access** to reach the shared App Group.

Other entry points: Home Screen and Lock Screen widgets, a Control Center control, and a Siri or Action Button
shortcut ("Dictate with Leap Whisper").

## Transcription pipeline

1. On-device whisper.cpp with the selected ggml model. Confidence is the mean token probability.
2. If confidence < the threshold (default 55%), no model is installed, or local inference fails, and
   a Groq key is set, the WAV is re-sent to Groq `whisper-large-v3-turbo`.
3. The selected mode rewrites the text (or it is inserted verbatim).

GPU (Metal) is used while the app is in the foreground. Background transcriptions use the CPU, because iOS blocks
GPU work from background apps.

## Models

Downloaded on demand from Hugging Face `ggerganov/whisper.cpp` into Application Support (excluded from backup):
tiny.en q5_1 (32 MB) → small q5_1 (190 MB, recommended) → large-v3-turbo q5_0/q8_0 (574/874 MB).
A custom URL or a `.bin` imported from Files also works.

## Secrets

The Groq key is entered in the app's Settings and stored in the iOS Keychain. It is never in source or the
binary. For a public App Store release, put a small proxy (e.g. a Cloudflare Worker) in front of Groq instead of
per-user keys.

## App

- **Dictate**: mic button, live level, mode picker, last transcript.
- **History**: every dictation from the app or keyboard, grouped by day, searchable. Swipe to copy or delete. Detail shows the
  original transcript, engine, local confidence and timing. Stored on-device only.
- **Stats**: words dictated, time saved versus typing at 40 WPM, speaking speed, streak, on-device versus Groq share, a 7-day chart
  and words by mode.
- **Models**: download, import or delete whisper.cpp models, and pick the active one.
- **Calibration** (Models tab or Settings): read a reference sentence once. Every installed model, plus Groq if a key is saved,
  transcribes the same recording. Results show accuracy (1 − word error rate), latency and confidence. You can apply the recommended
  engine and a suggested fallback threshold with one tap.
- **Settings**: on-device or Groq (online) engine, language, vocabulary, cloud fallback and threshold, optimizer, modes, Groq key.

## Build

Requires macOS, Xcode 16+ (Xcode 26 to enable the Apple Intelligence optimizer) and XcodeGen.

```bash
brew install xcodegen
cp Config/Local.xcconfig.example Config/Local.xcconfig   # set your Team ID and bundle prefix
xcodegen generate
open LeapWhisper.xcodeproj
```

### Run on your iPhone over USB

1. Connect the iPhone with a cable, then tap **Trust** on the phone.
2. Turn on Developer Mode on the phone (Settings > Privacy & Security > Developer Mode), then restart the phone.
3. In Xcode, under Settings > Accounts, add your Apple ID.
4. For each of the three targets, go to Signing & Capabilities and pick your team. Make the bundle prefix unique,
   e.g. `com.<yourname>.leapwhisper`, in `Config/Local.xcconfig`.
5. Select the iPhone as the run destination and press Run (⌘R). To debug the keyboard, choose the `LeapKeyboard` scheme,
   then pick any app with a text field as the host.
6. On the phone, add the keyboard: Settings > General > Keyboard > Keyboards > Add New Keyboard > Leap Whisper.
   Then turn on **Allow Full Access**, which the keyboard needs for the App Group.

Free Apple IDs work for this, but the app expires after 7 days. If Xcode refuses the App Groups capability on a personal team,
you'll need a paid Developer Program team.

Bundle IDs: `$(LEAP_BUNDLE_PREFIX).app`, `.app.keyboard` and `.app.widgets`. App Group: `group.$(LEAP_BUNDLE_PREFIX).shared`.

## TestFlight

1. Apple Developer Program membership ($99/yr).
2. In App Store Connect, create the app record with bundle ID `$(LEAP_BUNDLE_PREFIX).app`.
3. Create an App Store Connect API key (Users and Access > Integrations, App Manager role).
4. Upload:
   ```bash
   LEAP_TEAM_ID=… LEAP_BUNDLE_PREFIX=… ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_PATH=./AuthKey_….p8 ./scripts/testflight.sh
   ```
   Or run the `iOS` GitHub workflow with `testflight: true`. It needs these secrets: `ASC_KEY_P8`, `ASC_KEY_ID`, `ASC_ISSUER_ID`,
   `LEAP_TEAM_ID` and `LEAP_BUNDLE_PREFIX`.
5. Add internal testers in TestFlight. They can install right away, without review.

## Layout

```
App/        SwiftUI app: DictationController (session + pipeline), AudioCapture, WhisperEngine, GroqClient,
            TextOptimizer, ModelManager, views, App Shortcuts
Keyboard/   UIInputViewController + SwiftUI dictation keyboard
Widgets/    Home/Lock Screen widget and Control Center control
Shared/     App Group store, Darwin notifications, modes, StartDictationIntent
Packages/   whisper.cpp xcframework (SwiftPM binary target)
```
