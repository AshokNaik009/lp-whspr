# 009: Start from the Action Button or Control Center without opening the app

- **Status**: Implemented (not yet verified on device)
- **Goal**: G7

## Problem

The keyboard can only start the microphone by opening Leap Whisper (ADR-0002). Once the mic has gone off, the next dictation
costs an app switch, and since iOS 26.4 a manual swipe back. iOS has one sanctioned way to start a recording from the
background: an `AudioRecordingIntent` run by the system (Action Button, Control Center, Siri) together with a Live Activity.

## User stories

- As a user, I want to press the Action Button and start talking, without Leap Whisper coming to the front.
- As a user, I want to see that I'm being recorded, and for how long, from any app.
- As a user, I want to stop from wherever my thumb is: the keyboard, the Action Button or the Dynamic Island.

## Functional requirements

| ID | Requirement |
| --- | --- |
| FR-009-1 | One action, "Dictate", starts a dictation when idle and stops it when recording. While a dictation is being transcribed it does nothing. It backs the App Shortcut (Siri, Spotlight, Action Button) and the Control Center control. |
| FR-009-2 | When the mic is off, the action shall try to start where the app is, which may be the background: show the Live Activity, start the audio session, begin recording, and confirm that audio arrives within 1 s. |
| FR-009-3 | If the Live Activity or the audio session is refused, no audio arrives, or microphone permission was never granted, the action shall undo what it started and open the app, which starts the dictation in the foreground. |
| FR-009-4 | While the microphone is on, a Live Activity shows the state: recording with a running timer, transcribing, or mic ready. |
| FR-009-5 | The expanded Dynamic Island and the Lock Screen offer Stop and Cancel while recording, and Dictate and Mic off while the mic is ready. These work without opening the app. |
| FR-009-6 | If the Live Activity is dismissed or ended by the system, the app turns the microphone off. A recording in progress is stopped and transcribed first. |
| FR-009-7 | A dictation that finishes while no Leap Whisper keyboard is on screen is offered by the keyboard as an Insert chip for 10 minutes. It is never inserted on its own after the fact. |
| FR-009-8 | Every start through the action is logged on the device with the time, whether it ran in place or opened the app, and the reason. The last 20 entries are shown in Settings > Help > Start log. |

## Acceptance criteria

| ID | Given / When / Then |
| --- | --- |
| AC-009-1 | **Given** Leap Whisper was used a few minutes ago and another app is in front, **when** I press the Action Button, **then** recording starts, the Dynamic Island shows a running timer and Leap Whisper does not come to the front. |
| AC-009-2 | **Given** a recording started from the Action Button and the Leap Whisper keyboard is on screen, **when** I tap stop on the keyboard, **then** the text is inserted at the cursor. |
| AC-009-3 | **Given** iOS refuses the background start, **then** Leap Whisper opens and starts recording, and the start log says what was refused. |
| AC-009-4 | **Given** I'm recording, **when** I press the Action Button again with no keyboard on screen, **then** recording stops, and the next time the Leap Whisper keyboard opens within 10 minutes it offers to insert the text. |
| AC-009-5 | **Given** I'm recording, **when** I tap Stop or Cancel in the expanded Dynamic Island, **then** the dictation is transcribed or discarded without Leap Whisper opening. |
| AC-009-6 | **Given** the mic is ready, **when** I tap Mic off in the Dynamic Island, **then** the orange indicator and the Live Activity go away. |
| AC-009-7 | **Given** the mic is on, **when** I swipe the Live Activity off the Lock Screen, **then** the microphone turns off. |

## Design notes

- The system performs `AudioRecordingIntent` and `LiveActivityIntent` types in the app's process. The intent types are also
  compiled into the widget extension, because the control and the Live Activity refer to them, so they reach the app through
  `DictationIntentBridge`, a set of closures the app installs at launch.
- The fallback is `.result(opensIntent: StartDictationIntent())`, the intent that already opened the app. It needs iOS 18.2;
  on 18.0 and 18.1 the action reports that the app has to be opened.
- A background start is not guaranteed. Other apps that ship this report that `Activity.request` can fail with "Target is not
  foreground" and that a cold microphone start can be refused, so they try in place first and open the app on failure
  ([hex-iphone](https://github.com/Luraxx/hex-iphone/commit/ac1a72ccc448b0da8deca7946db5581474daf2b0)). FR-009-2 and FR-009-3
  follow that pattern, and FR-009-8 exists to measure how often each case happens.
- iOS stops a background recording that has no Live Activity
  ([AudioRecordingIntent](https://developer.apple.com/documentation/appintents/audiorecordingintent)). For that reason the
  Live Activity stays up for as long as the mic is on, including the standby window of ADR-0002.

## Implementation

| Requirement | Files |
| --- | --- |
| FR-009-1, 3 | `Shared/Intents/DictationIntents.swift`, `App/LeapWhisperApp.swift`, `Widgets/LeapWidgets.swift` |
| FR-009-2, 6, 8 | `App/DictationController.swift`, `App/AudioCapture.swift`, `App/DictationActivity.swift`, `Shared/SharedStore.swift`, `App/SettingsView.swift` |
| FR-009-4, 5 | `Shared/Intents/DictationActivityAttributes.swift`, `Widgets/DictationLiveActivity.swift` |
| FR-009-7 | `Shared/Core/TranscriptDelivery.swift`, `Keyboard/KeyboardModel.swift`, `Keyboard/KeyboardView.swift` |

## Verification

| Criterion | Device / OS | Result | Date |
| --- | --- | --- | --- |
| AC-009-4 (10-minute rule only) | `swift test` (TranscriptDeliveryTests) | Pass | 2026-11-13 |
| AC-009-1 | iPhone 17 Pro, iOS 26.6, free Personal Team build | Not met on the first press: the Live Activity was accepted, then the audio session was refused in the background (`'!pri'`, insufficient priority, 561017449) | 2026-11-13 |
| AC-009-3 (the log names what was refused) | iPhone 17 Pro, iOS 26.6 | Pass | 2026-11-13 |
| AC-009-2, AC-009-4 to AC-009-7, and whether the Live Activity is visible | iPhone 17 Pro, iOS 26.6 | Pending | |
| Live Activity, recording state | iPhone 18 Pro simulator, iOS 27.2 | Seen once with waveform and timer, then not again over repeated runs although iOS logged each activity as started; cause unknown | 2026-11-13 |

## Open questions

- The first press on iOS 26.6 was refused when activating the audio session from the background. Other apps report that
  starting the engine works in the background as long as the session is already active, so the next thing to try is leaving
  the session active (engine stopped, no mic indicator) after the first foreground use instead of deactivating it.
- With that change, how often does the in-place start succeed: app used minutes ago, idle for an hour, after a reboot?
- Is the Live Activity visible on the device in all three states? The simulator result above is inconclusive.
