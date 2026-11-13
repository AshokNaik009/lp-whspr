# Leap Whisper for iOS

Voice dictation for iPhone and iPad: a SwiftUI app plus a custom keyboard with a mic button that toggles
recording on and off and types the transcript into any app. Transcription runs on-device with
[whisper.cpp](https://github.com/ggml-org/whisper.cpp) (Metal-accelerated). Groq Cloud is a fallback
for low-confidence results, or it can be the main engine. Optimization modes (Clean, Message, Email,
Notes, AI Prompt, To Arabic, custom) rewrite the transcript with Apple Intelligence (on-device) or a Groq LLM.

## Features

- **Dictate into any app** from the Leap Whisper keyboard: tap the mic, speak, tap again, and the text is typed
  at the cursor. Words appear live while you speak.
- **Mic stays ready** after a dictation (15 minutes by default), so the next taps record in place without opening
  the app. A mic-off button on the keyboard ends it early.
- **Action Button, Control Center and Siri**: one "Dictate" action starts and stops a dictation. It tries to start
  without opening the app and opens it when iOS refuses.
- **Dynamic Island and Lock Screen**: a Live Activity shows recording with a timer, transcribing, or mic ready, with
  Stop, Cancel, Dictate and Mic off buttons.
- **Insert chip**: a dictation that finishes while the keyboard isn't on screen is offered the next time it opens.
- **Modes**: Raw, Clean, Message, Email, Notes, AI Prompt, To Arabic and your own. To Arabic uses a separate
  translation model (Qwen 3.8 27B on Groq by default).
- **On-device first**: whisper.cpp models run on the iPhone. Groq is optional, as a fallback or as the main engine.
- **History and stats** kept on the device, with the last 50 dictations available from the keyboard.

## Architecture

```
┌─ Any app (WhatsApp, Notes, Mail…) ─┐                  ┌─ Leap Whisper app (background audio) ──┐
│                                    │  start / stop    │                                        │
│  LeapKeyboard (extension)          │ ───────────────▶ │  AudioCapture   AVAudioEngine, 16 kHz  │
│   • mode chips  • orb mic toggle   │  Darwin notify + │        │  ├─ every ~1 s: fast greedy    │
│   • live-text strip                │  App Group       │        │  │  pass → live preview ───────┼─▶ keyboard + app
│   • recent history (tap = insert)  │                  │        ▼  ▼                            │
│   • inserts text via               │                  │  WhisperEngine  whisper.cpp            │
│     textDocumentProxy              │   transcript     │   (Metal + beam search in foreground,  │
│                                    │ ◀─────────────── │    CPU + greedy in background)         │
└────────────────────────────────────┘                  │  FallbackPolicy ── low confidence ──┐  │
                                                        │        │ ok                         │  │
┌─ LeapWidgets ──────────────────────┐  open / start    │        │                            ▼  │      ┌─ Groq API ─────────────┐
│  Home & Lock Screen widgets        │ ───────────────▶ │        │                  GroqClient ──┼────▶ │ whisper-large-v3-turbo │
│  Control Center control            │                  │        ▼                     (WAV)     │      │ gpt-oss-20b / qwen3.8  │
│  Action Button, Siri, Live Activity│                  │  TextOptimizer  mode rewrite/translate │      └────────────────────────┘
└────────────────────────────────────┘                  │   Automatic: Apple Intelligence        │
                                                        │   on-device, else Groq LLM             │
┌─ On device ────────────────────────┐                  │        │                               │
│  Models/*.bin  ◀── Hugging Face    │ ◀──────────────▶ │        ▼                               │
│  history.json   (History · Stats)  │                  │  HistoryStore · Stats · Calibration    │
│  App Group: state, live text,      │                  │   (last 50 mirrored to the keyboard)   │
│   modes, recent history            │                  │                                        │
│  Keychain       (Groq API key)     │                  │                                        │
└────────────────────────────────────┘                  └────────────────────────────────────────┘
```

Flow: keyboard mic → app records (live preview while you speak) → on-device whisper.cpp → if confidence is below
the threshold (and it isn't silence), the WAV goes to Groq → selected mode rewrites or translates the text →
keyboard inserts it. Details: [specs/architecture.md](specs/architecture.md).

## Design

The default look is Liquid Glass (iOS 26): a dark purple-blue aurora background, translucent glass cards and
a glowing orb microphone that turns pink-orange and pulses while recording. Settings > Appearance also offers
flat **Light** and **Dark** themes (warm cream canvas `#fdfcfc`, near-black ink `#201d1d`, 1px hairlines, 4px
corners, no gradients) and **System**, which follows the iPhone's light/dark setting.

- **Type:** Plus Jakarta Sans everywhere (bundled in `Shared/Fonts`, SIL Open Font License).
- **Dictate:** time-saved card, orb mic with waveform and timer, a rotating "Whispermaxxing…" status while it
  transcribes, live transcript and the final transcript with Copy right under the mic (the screen scrolls back
  up when a dictation starts or finishes), then a rotary mode dial (drag to turn; it snaps with a haptic tick to Raw, Clean,
  Message, Email, Notes, AI Prompt, To Arabic or a custom mode).
- **Keyboard:** mode chips, gradient orb mic with pulse rings, cancel and timer while recording, a glass strip
  with the live words, a mic-off button while the mic is ready, an Insert chip for a dictation that finished while
  the keyboard was away, and a clock key that shows recent dictations to re-insert. Settings > Keyboard background
  sets a gradient: Default, six presets, or a custom two-colour gradient.
- **Dynamic Island:** a waveform and running timer while recording, then transcribing and mic ready. Touch and hold
  it for the buttons.
- **History, Stats, Models, Settings:** standard iOS lists (to be restyled). Models shows the recommended
  Large v3 Turbo, per-model size and a delete button.
- **Onboarding:** a guided setup for downloading a model, adding the keyboard, Full Access and a practice field.
- **App guide:** Settings > Help > App guide has step-by-step how-tos for dictation, the keyboard, the Action Button, modes, Groq, models, history, keyboard backgrounds and recording a demo.

## How the keyboard dictates

iOS does not let keyboard extensions use the microphone, so the app owns the mic:

1. The first mic tap in the keyboard opens Leap Whisper (`leapwhisper://session?start=1`). The app starts
   an `AVAudioEngine` session with the `audio` background mode and begins recording.
2. The app jumps back to the host app when it knows which one it was. Since iOS 26.4 a keyboard can no longer
   identify its host, so the user swipes right along the bottom edge instead. The engine keeps running in the
   background, so the app stays alive.
3. The keyboard's stop tap sends a `stop` command over Darwin notifications and the App Group. The app
   transcribes, applies the selected mode and publishes the text. The keyboard inserts it via `textDocumentProxy`.
4. The engine then stays on for the standby window (Settings > Keyboard dictation > Keep mic ready: Off, 5 minutes,
   15 minutes by default, 1 hour, or until turned off). During that window every keyboard tap starts and stops
   recording in place, with no app switch, and iOS shows its orange mic indicator. The small mic-off button on the
   keyboard ends the window early.
5. When the window ends the app stops the engine. iOS won't let a backgrounded app start the microphone, so the
   next keyboard tap opens the app again. With Off, that happens after every dictation.

The microphone is always the iPhone's own, so connected AirPods keep playing in stereo while the mic is ready.
Why it works this way, with sources: [ADR-0002](specs/decisions/0002-keep-mic-ready-window.md).

The keyboard needs **Allow Full Access** to reach the shared App Group.

Home Screen and Lock Screen widgets open the app and start a dictation there.

## Starting from the Action Button or Control Center

The "Dictate" action (Settings > Action Button > Shortcut > Leap Whisper > Dictate, or the Leap Whisper control in
Control Center, or "Dictate with Leap Whisper" to Siri) starts a dictation and stops the one in progress.

1. iOS only lets an app record from the background through an `AudioRecordingIntent` with a Live Activity, so the
   action shows the Live Activity first, then starts the audio session and waits for audio to arrive.
2. If iOS refuses any of that, the action undoes what it started and opens the app, which starts the dictation in
   the foreground. That is the same result as before this feature existed.
3. Stop from the keyboard, the Action Button, or the Stop button in the expanded Dynamic Island.
4. If no Leap Whisper keyboard is on screen when the text is ready, the keyboard offers it as an Insert chip for
   the next 10 minutes.

A background start is not guaranteed. On the first try on an iPhone 17 Pro with iOS 26.6 the audio session was
refused (`'!pri'`, insufficient priority) and the app opened. Settings > Help > Start log records how each press
went and why. Details and open questions: [spec 009](specs/features/009-background-start.md).

## Transcription pipeline

1. On-device whisper.cpp with the selected ggml model. Confidence is the mean token probability.
2. If confidence < the threshold (default 55%), no model is installed, or local inference fails, and
   a Groq key is set, the WAV is re-sent to Groq `whisper-large-v3-turbo`.
3. The selected mode rewrites the text (or it is inserted verbatim). Rewrites use Groq `openai/gpt-oss-20b`;
   modes that translate (To Arabic) use `qwen/qwen3.8-27b` and fall back to the rewrite model. The transcript is
   sent inside `<transcript>` tags so a dictation that sounds like a request is transformed, not answered.

GPU (Metal) and beam search are used while the app is in the foreground. Background (keyboard) transcriptions
use the CPU with greedy decoding, because iOS blocks GPU work from background apps and beam search on the CPU is
several times slower. For keyboard dictation, Small or Base models are much faster than Large v3 Turbo on the CPU.

While recording, a fast greedy pass re-transcribes the latest audio (every ~0.8 s in the foreground, ~2 s in the
background) and publishes it as a live preview to the app and keyboard. The final pass on stop replaces it.

## Models

Downloaded on demand from Hugging Face `ggerganov/whisper.cpp` into Application Support (excluded from backup):
tiny.en q5_1 (32 MB) → small q5_1 (190 MB, recommended) → large-v3-turbo q5_0/q8_0 (574/874 MB).
A custom URL or a `.bin` imported from Files also works.

## Secrets

The Groq key is entered in the app's Settings and stored in the iOS Keychain. It is never in source or the
binary. For a public App Store release, put a small proxy (e.g. a Cloudflare Worker) in front of Groq instead of
per-user keys.

## Specs

This project uses spec-driven development. Product goals, the architecture, decision records and one spec per feature, with
numbered requirements and acceptance criteria, live in [`specs/`](specs/README.md). PRs reference the requirement IDs they implement.

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
- **Settings**: on-device or Groq (online) engine, language, vocabulary, cloud fallback and threshold, optimizer, modes,
  Groq key and its transcription, rewrite and translation models, how long the mic stays ready, appearance, and the
  app guide and start log under Help.

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

Step-by-step for anyone who clones this repo and wants to ship their own beta. TestFlight needs a paid
[Apple Developer Program](https://developer.apple.com/programs/) membership ($99/yr); a free Apple ID can only
install over USB (see [Build](#build)).

### 1. Pick your identifiers

Apple IDs are global, so use your own reverse-DNS prefix:

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig   # git-ignored
# LEAP_TEAM_ID       = your 10-character Team ID (developer.apple.com > Account > Membership details)
# LEAP_BUNDLE_PREFIX = e.g. com.yourname.leapwhisper
```

This produces bundle IDs `<prefix>.app`, `<prefix>.app.keyboard`, `<prefix>.app.widgets` and the App Group
`group.<prefix>.shared`.

### 2. Register them in the Developer portal

[Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list):

1. **Identifiers > App Groups > +**: `group.<prefix>.shared`.
2. **Identifiers > App IDs > +** for each of the three bundle IDs, enabling the **App Groups** capability and
   selecting the group above.

Xcode's automatic signing (`-allowProvisioningUpdates`) can create these for you on the first archive, but
registering them up front avoids "no profiles found" errors.

### 3. Create the app in App Store Connect

[App Store Connect](https://appstoreconnect.apple.com) > **Apps > + > New App**: platform iOS, any name, bundle ID
`<prefix>.app`, any SKU. Only the main app needs a record; the keyboard and widgets ship inside it.

### 4. Create an API key for uploads

App Store Connect > **Users and Access > Integrations > App Store Connect API > +**, role **App Manager**.
Note the **Issuer ID** and **Key ID**, and download `AuthKey_<KEYID>.p8` (downloadable only once). Never commit
it; `*.p8` is git-ignored.

### 5. Upload a build

**From a Mac** (Xcode 16+, `brew install xcodegen`):

```bash
LEAP_TEAM_ID=ABCDE12345 \
LEAP_BUNDLE_PREFIX=com.yourname.leapwhisper \
ASC_KEY_ID=XXXXXXXXXX \
ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
ASC_KEY_PATH=~/keys/AuthKey_XXXXXXXXXX.p8 \
./scripts/testflight.sh
```

[`scripts/testflight.sh`](scripts/testflight.sh) generates the project, archives a Release build, exports it
for App Store Connect and uploads it. The build number defaults to a timestamp (override with `BUILD_NUMBER`);
bump `MARKETING_VERSION` in `project.yml` for a new version.

**Or from GitHub Actions** (no Mac needed): add these repository secrets under Settings > Secrets and variables >
Actions:

| Secret | Value |
| --- | --- |
| `LEAP_TEAM_ID` | Team ID |
| `LEAP_BUNDLE_PREFIX` | e.g. `com.yourname.leapwhisper` |
| `ASC_KEY_ID` | API key ID |
| `ASC_ISSUER_ID` | Issuer ID |
| `ASC_KEY_P8` | full contents of the `.p8` file, including the BEGIN/END lines |

Then **Actions > iOS > Run workflow**, tick **Upload to TestFlight**. The run number becomes the build number.

### 6. Invite testers

The build shows up under **TestFlight** after 10–30 minutes of processing. The app already declares
`ITSAppUsesNonExemptEncryption = NO`, so there's no export-compliance prompt.

- **Internal testers** (up to 100 members of your App Store Connect team): add them to an internal group and they
  can install immediately, without review.
- **External testers** (up to 10,000): create an external group, add the build, fill in the beta description and
  submit it for Beta App Review (usually about a day). You can then share a public link.

Testers install the free **TestFlight** app, open the invite, and set up the keyboard the same way as a USB build
(the in-app setup guide walks through it). TestFlight builds expire after 90 days.

### Before a public beta

Testers paste their own Groq key in Settings (it stays in their Keychain). Don't bake a shared key into the
binary; for a wide beta or the App Store, put Groq behind a small proxy (see [Secrets](#secrets)).

## Layout

```
App/        SwiftUI app: DictationController (session + pipeline), AudioCapture, WhisperEngine, GroqClient,
            TextOptimizer, DictationActivity (Live Activity), ModelManager, views, App Shortcuts
Keyboard/   UIInputViewController + SwiftUI dictation keyboard
Widgets/    Home/Lock Screen widget, Control Center control and the Live Activity views
Shared/     App Group store, Darwin notifications, intents (Shared/Intents), tested logic (Shared/Core)
Tests/      Unit tests for Shared/Core, run with `swift test`
specs/      Product spec, architecture, decision records and one spec per feature
Packages/   whisper.cpp xcframework (SwiftPM binary target)
```
