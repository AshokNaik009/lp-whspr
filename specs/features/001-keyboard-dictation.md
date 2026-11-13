# 001: Keyboard dictation toggle and app handoff

- **Status**: Implemented (not yet verified on device)
- **Goal**: G1

## Problem

Users want to dictate into any app (Messages, Mail, Slack, ChatGPT) without copying and pasting. iOS doesn't let custom keyboards
use the microphone, so the keyboard alone can't record.

## User stories

- As a user typing in any app, I want to tap a mic button on my keyboard to start dictation and tap it again to stop, so the text
  is inserted where my cursor is.
- As a user, I want to pick a mode on the keyboard before dictating, so the text comes out in the format I need.
- As a user, I want to cancel a dictation I started by mistake.

## Functional requirements

| ID | Requirement |
| --- | --- |
| FR-001-1 | The keyboard shall show a mic button that toggles between idle (start) and recording (stop). |
| FR-001-2 | If no live app session exists, tapping the mic shall open `leapwhisper://session?start=1&mode=<id>`. The app then starts the audio session and begins recording. |
| FR-001-3 | While a session is alive, mic taps shall send `start`/`stop` commands through the App Group and Darwin notifications, with no app switch. |
| FR-001-4 | The keyboard shall show the current state (idle, recording, transcribing, error) and status text. |
| FR-001-5 | When a transcript is published, the keyboard shall insert it through `textDocumentProxy`, adding a leading space when the preceding character isn't whitespace. |
| FR-001-6 | The keyboard shall show chips for the user's modes and send the selected mode with `start`. |
| FR-001-7 | The keyboard shall provide globe (next keyboard), space, delete and return keys, and a cancel button while recording. |
| FR-001-8 | After a dictation is published or cancelled, the app shall keep the audio session running for the user's standby setting (off, 5 minutes, 15 minutes by default, 1 hour, always) and stop it when that much idle time has passed. With standby off it shall stop the session straight away. |
| FR-001-9 | The keyboard shall not load ML models or audio frameworks. |
| FR-001-10 | While the mic is on and idle, the keyboard shall show a mic-off button that stops the audio session. |
| FR-001-11 | If a `start` command isn't picked up within 1.5 s, the keyboard shall open the app as in FR-001-2. |
| FR-001-12 | The audio session shall record from the iPhone's built-in microphone and shall not switch Bluetooth headphones to the hands-free profile. |

## Acceptance criteria

| ID | Given / When / Then |
| --- | --- |
| AC-001-1 | **Given** no session, **when** I tap the mic in Notes, **then** Leap Whisper opens and starts recording, and after I swipe back the keyboard shows "Recording". |
| AC-001-2 | **Given** a live session, **when** I tap the mic twice in Messages, **then** recording starts and stops without leaving Messages, and the transcript is inserted at the cursor. |
| AC-001-3 | **Given** the text "Hello" before the cursor, **when** a transcript "world" arrives, **then** the field reads "Hello world". |
| AC-001-4 | **Given** recording, **when** I tap cancel, **then** nothing is inserted and the state returns to idle. |
| AC-001-5 | **Given** standby is off and a dictation was just inserted, **then** the orange mic indicator is gone and the next keyboard tap reopens the app. |
| AC-001-6 | **Given** standby is 15 minutes and a dictation was inserted 14 minutes ago, **when** I tap the mic, **then** recording starts without leaving the host app. After 15 idle minutes the indicator is gone and the next tap reopens the app. |
| AC-001-7 | **Given** the mic is on and idle, **when** I tap the mic-off button on the keyboard, **then** the orange mic indicator goes away within a second. |
| AC-001-8 | **Given** AirPods are playing music, **when** the mic is on, **then** the music keeps playing in stereo. |

## Design notes

See [architecture: keyboard microphone constraint](../architecture.md#keyboard-microphone-constraint). Opening a URL from an
extension uses the responder chain, because `UIApplication.shared` isn't available to extensions. The keyboard needs
**Allow Full Access** to read the App Group.

## Implementation

| Requirement | Files |
| --- | --- |
| FR-001-1, 4, 6, 7 | `Keyboard/KeyboardView.swift` |
| FR-001-2, 3, 5 | `Keyboard/KeyboardModel.swift`, `Keyboard/URLOpener.swift`, `Shared/SharedStore.swift`, `Shared/DarwinNotifier.swift` |
| FR-001-2, 8, 12 | `App/DictationController.swift`, `App/AudioCapture.swift`, `Shared/Core/MicStandby.swift`, `App/SettingsView.swift` |
| FR-001-10, 11 | `Keyboard/KeyboardModel.swift`, `Keyboard/KeyboardView.swift` |

## Verification

| Criterion | Device / OS | Result | Date |
| --- | --- | --- | --- |
| AC-001-3 | `swift test` (TranscriptCleanerTests) | Pass | 2026-11-12 |
| AC-001-5, AC-001-6 (timing rule only) | `swift test` (MicStandbyTests) | Pass | 2026-11-13 |
| Device acceptance criteria | iPhone | Pending | |
