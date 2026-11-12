# 007: Widgets, Control Center and shortcuts

- **Status**: Implemented (not yet verified on device)
- **Goal**: G7

## Functional requirements

| ID | Requirement |
| --- | --- |
| FR-007-1 | The Home Screen widget (`systemSmall`) and Lock Screen widgets (`accessoryCircular`, `accessoryRectangular`) open the app and start dictation. |
| FR-007-2 | A Control Center control (`ControlWidget`) runs `StartDictationIntent`. |
| FR-007-3 | An App Shortcut "Dictate with Leap Whisper" is available to Siri, Spotlight and the Action Button. |
| FR-007-4 | The intent sets a pending start in the App Group. The app starts recording when it becomes active. |

## Design notes

Widgets can't record audio. They only launch the app's session, which is the same handoff the keyboard uses (001).

## Implementation

| Requirement | Files |
| --- | --- |
| FR-007-1, 2 | `Widgets/LeapWidgets.swift` |
| FR-007-3, 4 | `Shared/Intents/StartDictationIntent.swift`, `App/LeapWhisperApp.swift` |
