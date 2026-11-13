# Working on Leap Whisper iOS

Specs are the source of truth (`specs/`). A behaviour change edits the spec and the code together.

## Commands

Set these first; plain `swift test` picks the Command Line Tools, which have no XCTest.

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/opt/homebrew/bin:$PATH
```

| Task | Command |
| --- | --- |
| Unit tests (`Shared/Core`) | `swift test` |
| Regenerate the Xcode project | `xcodegen generate -q` |
| Build for a device | `xcodebuild -project LeapWhisper.xcodeproj -scheme LeapWhisper -configuration Debug -destination 'id=<UDID>' -derivedDataPath build/dd -allowProvisioningUpdates build` |
| Install | `xcrun devicectl device install app --device <UDID> build/dd/Build/Products/Debug-iphoneos/LeapWhisper.app` |
| Launch | `xcrun devicectl device process launch --device <UDID> --terminate-existing <bundle id>` |
| Find the device | `xcrun devicectl list devices` |

The team ID and bundle prefix live in the git-ignored `Config/Local.xcconfig`.

## Checking real results

History and settings can be read off the phone, which is the quickest way to see what a mode actually produced:

```bash
xcrun devicectl device copy from --device <UDID> --domain-type appDataContainer --domain-identifier <bundle id> \
  --source "Library/Application Support/history.json" --destination /tmp/history.json
```

The Groq key lives in the phone's Keychain, so rewrite and translation models can't be called from the Mac unless
`GROQ_API_KEY` is exported in the shell.

## Things that can't be tested from the Mac

Keyboard dictation, the microphone and the orange indicator need a person holding the phone. Say which acceptance criteria
were only compiled, and record device results in the spec's Verification table.

## iOS limits that shape the design

Read [ADR-0002](specs/decisions/0002-keep-mic-ready-window.md) before changing how the keyboard starts the microphone: a
keyboard can't record, a backgrounded app can't start the mic, and nothing public returns the user to the host app.
