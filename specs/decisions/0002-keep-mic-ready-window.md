# ADR-0002: Keep the mic ready for a window after each dictation

- **Status**: Accepted
- **Date**: 2026-11-13
- **Supersedes**: the mic-off-after-every-dictation policy from commit `346d631`

## Context

With the mic switched off after every dictation, each keyboard tap opened Leap Whisper to restart it. On iOS 26.4 and later
the app also can't jump back by itself, so every dictation meant an app switch and a manual swipe back. We looked for a way to
start recording from the keyboard with no switch at all. There isn't one:

- **A keyboard extension can't record.** Apple lists "No access to microphone" among the keyboard restrictions, and open access
  doesn't lift it. Developers who try with both Full Access and microphone permission get error 561145187
  ([Apple forums 775077](https://developer.apple.com/forums/thread/775077)).
- **A backgrounded app can't start the microphone.** Since iOS 12.4, starting audio input from the background fails with
  `cannotStartRecording` (561145187). The `audio` background mode only lets an app continue input it started in the foreground
  ([Stack Overflow 58235184](https://stackoverflow.com/questions/58235184),
  [61312360](https://stackoverflow.com/questions/61312360), [Apple forums 120038](https://developer.apple.com/forums/thread/120038)).
- **Nothing public returns the user to the host app.** iOS 26.4 stopped exposing the host bundle ID to keyboards and Apple DTS
  confirmed there is no supported round trip ([Apple forums 826851](https://developer.apple.com/forums/thread/826851),
  [KeyboardKit #1014](https://github.com/KeyboardKit/KeyboardKit/issues/1014)).
- **The one sanctioned background start is `AudioRecordingIntent` with a Live Activity**, which the system invokes from the
  Action Button, Control Center, Shortcuts or Siri. We found no way for a keyboard to trigger it in place; the only route
  from a keyboard goes through the Shortcuts app, which is another app switch.

Every dictation keyboard we could check therefore keeps the app's microphone running between dictations and stops it on a
timer: Wispr Flow ("Flow Sessions": immediately, 5 minutes by default, 15 minutes, 1 hour, never), Willow, Typeless,
Superwhisper, KeyboardKit Pro, and the open-source VivaDicta, Outspoken, Yabber and Ara. The cost is the orange mic indicator
for as long as the window lasts.

## Decision

- Keep the engine running after a dictation for a user-chosen standby window: off, 5 minutes, 15 minutes (default), 1 hour or
  until turned off (`Shared/Core/MicStandby.swift`).
- Give the keyboard a mic-off button so the indicator can be cleared at any moment without opening the app.
- Record from the built-in microphone only. The Bluetooth hands-free route would hold AirPods at call quality for the whole
  window.
- If a warm `start` isn't picked up within 1.5 s, the keyboard opens the app, so a tap is never left unanswered.

## Consequences

- One app switch per window instead of one per dictation. With standby off the behaviour is the same as before.
- The orange indicator shows while the mic is ready. Buffers are discarded unless a dictation is in progress.
- A ready microphone uses some battery, and a call or an audio route change ends the window early.
- Dictating through an AirPods or car microphone is no longer possible; that needs a setting if it's wanted back.

## Not done here

- **Start without any switch from the Action Button or Control Center**: change `StartDictationIntent` to an
  `AudioRecordingIntent` with a Live Activity, falling back to opening the app when iOS refuses the background start
  ("Target is not foreground"). Wispr Flow and Superwhisper both offer this. It needs testing on a device.
- **Jump back automatically on iOS 26.4+**: possible only by swizzling a private UIKit class to read the host bundle ID
  ([KeyboardHostBundleID](https://github.com/Muskupecli/KeyboardHostBundleID)). App Review risk; not adopted.
