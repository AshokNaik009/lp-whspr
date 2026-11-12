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
| FR-001-8 | The app shall end the background session after `sessionTimeoutMinutes` of inactivity (default 10). |
| FR-001-9 | The keyboard shall not load ML models or audio frameworks. |

## Acceptance criteria

| ID | Given / When / Then |
| --- | --- |
| AC-001-1 | **Given** no session, **when** I tap the mic in Notes, **then** Leap Whisper opens and starts recording, and after I swipe back the keyboard shows "Recording". |
| AC-001-2 | **Given** a live session, **when** I tap the mic twice in Messages, **then** recording starts and stops without leaving Messages, and the transcript is inserted at the cursor. |
| AC-001-3 | **Given** the text "Hello" before the cursor, **when** a transcript "world" arrives, **then** the field reads "Hello world". |
| AC-001-4 | **Given** recording, **when** I tap cancel, **then** nothing is inserted and the state returns to idle. |
| AC-001-5 | **Given** 10 idle minutes, **then** the app stops the audio session and the next keyboard tap reopens the app. |

## Design notes

See [architecture: keyboard microphone constraint](../architecture.md#keyboard-microphone-constraint). Opening a URL from an
extension uses the responder chain, because `UIApplication.shared` isn't available to extensions. The keyboard needs
**Allow Full Access** to read the App Group.

## Implementation

| Requirement | Files |
| --- | --- |
| FR-001-1, 4, 6, 7 | `Keyboard/KeyboardView.swift` |
| FR-001-2, 3, 5 | `Keyboard/KeyboardModel.swift`, `Keyboard/URLOpener.swift`, `Shared/SharedStore.swift`, `Shared/DarwinNotifier.swift` |
| FR-001-2, 8 | `App/DictationController.swift`, `App/AudioCapture.swift` |

## Verification

| Criterion | Device / OS | Result | Date |
| --- | --- | --- | --- |
| AC-001-3 | `swift test` (TranscriptCleanerTests) | Pass | 2026-11-12 |
| Device acceptance criteria | iPhone | Pending | |
