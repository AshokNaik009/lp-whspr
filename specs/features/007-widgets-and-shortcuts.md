# 007: Widgets, Control Center and shortcuts

- **Status**: Implemented (not yet verified on device)
- **Goal**: G7

## Functional requirements

| ID | Requirement |
| --- | --- |
| FR-007-1 | The Home Screen widget (`systemSmall`) and Lock Screen widgets (`accessoryCircular`, `accessoryRectangular`) open the app and start dictation. |
| FR-007-2 | A Control Center control (`ControlWidget`) runs the Dictate action of [009](009-background-start.md). |
| FR-007-3 | An App Shortcut "Dictate with Leap Whisper" runs the same action from Siri, Spotlight and the Action Button. |
| FR-007-4 | When the action has to open the app, `StartDictationIntent` sets a pending start in the App Group and the app starts recording when it becomes active. |

## Design notes

Widgets can't record audio. The Home Screen and Lock Screen widgets launch the app's session, which is the same handoff the
keyboard uses (001). The control and the shortcut first try to start without opening the app (009).

## Implementation

| Requirement | Files |
| --- | --- |
| FR-007-1, 2 | `Widgets/LeapWidgets.swift` |
| FR-007-3, 4 | `Shared/Intents/DictationIntents.swift`, `App/LeapWhisperApp.swift` |
