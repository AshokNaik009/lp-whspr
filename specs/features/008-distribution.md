# 008: Device debugging, TestFlight and App Store distribution

- **Status**: In progress
- **Goal**: G8

## Functional requirements

| ID | Requirement |
| --- | --- |
| FR-008-1 | The project is generated from `project.yml` with XcodeGen. Team ID and bundle prefix come from `Config/Local.xcconfig`, which is git-ignored. |
| FR-008-2 | A developer can run the app and keyboard on a USB-connected iPhone with a free or paid Apple ID (README, "Run on your iPhone over USB"). |
| FR-008-3 | `scripts/testflight.sh` archives and uploads with an App Store Connect API key, with no Xcode UI needed. |
| FR-008-4 | The GitHub Actions workflow `iOS` builds for the Simulator on every push. When triggered manually with `testflight: true`, it uploads to TestFlight using repository secrets. |
| FR-008-5 | Before public App Store release, Groq calls go through a server-side proxy, and the privacy manifest and the keyboard open-access justification are complete. |

## Acceptance criteria

| ID | Given / When / Then |
| --- | --- |
| AC-008-1 | **Given** Xcode on the Mac and a USB iPhone, **when** I press Run, **then** the app installs and launches. |
| AC-008-2 | **Given** API key secrets, **when** I run the workflow with `testflight: true`, **then** a build appears in TestFlight. |
| AC-008-3 | **Given** a TestFlight build, **then** an internal tester can install it and record a demo. |

## Status

- [x] Code pushed to `AshokNaik009/lp-whspr`
- [ ] First Xcode build on the Mac. Blocked: Xcode isn't installed yet.
- [ ] Run on a USB iPhone
- [ ] Apple Developer team, bundle IDs and App Store Connect API key
- [ ] TestFlight upload
- [ ] Groq proxy, privacy manifest, App Store review
