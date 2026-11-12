# Product spec: Leap Whisper for iOS

## Vision

Bring Leap Whisper's desktop dictation to iPhone and iPad. Tap a button on the keyboard in any app, speak, tap again, and polished
text appears where you're typing. It reaches parity with the laptop app's optimization modes and with the dictation experience
users expect from tools like Wispr Flow.

## Users

- **Primary**: people who already use Leap Whisper on a laptop and want the same modes on their phone.
- **Secondary**: anyone who writes long messages, emails or AI prompts on mobile and prefers speaking to typing.

## Goals

| ID | Goal |
| --- | --- |
| G1 | A keyboard mic button that toggles dictation on and off in any app ([001](features/001-keyboard-dictation.md)) |
| G2 | Private, offline-capable transcription with downloadable Whisper models ([002](features/002-on-device-transcription.md)) |
| G3 | Cloud accuracy when local confidence is low, or always if the user prefers ([003](features/003-cloud-fallback.md)) |
| G4 | The same optimization modes as the laptop app, plus user-defined ones ([004](features/004-optimization-modes.md)) |
| G5 | Wispr Flow-style history and stats ([005](features/005-history-and-stats.md)) |
| G6 | Help users pick the best model for their voice and device ([006](features/006-model-calibration.md)) |
| G7 | Start dictation from Control Center, the Lock Screen, Siri or the Action Button ([007](features/007-widgets-and-shortcuts.md)) |
| G8 | Install over USB for debugging, through TestFlight for demos, then on the App Store ([008](features/008-distribution.md)) |

## Non-goals (v1)

- Recording audio inside the keyboard extension. iOS doesn't allow it; see [architecture](architecture.md#keyboard-microphone-constraint).
- Accounts, sync or a server-side history.
- Live streaming transcription while speaking. v1 transcribes when recording stops.
- Android.

## Success metrics

- Keyboard tap to inserted text in 2 s or less for a 10 s dictation with the Small model on an iPhone 15-class device.
- 95% or more of dictations finish without a user-visible error.
- At least 80% of dictations run on-device when a model is installed.
- A demo recording made from a TestFlight build.

## Open questions

- What exactly are the laptop app's modes and prompts? The current set is an equivalent and still needs a parity check.
- Which Apple Developer team will publish: personal, or Leap's organization?
- Which proxy will hold the Groq key for public builds: a Cloudflare Worker, or Leap's backend?
