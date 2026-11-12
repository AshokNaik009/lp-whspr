# Leap Whisper specs

Leap Whisper for iOS is built spec-first. Every feature starts here as a written spec. The spec is reviewed and agreed on, then
implemented, and the implementation PR links back to it. A spec is the source of truth for what a feature must do. The code
is the source of truth for how it does it.

## Workflow

1. **Specify**: copy [`templates/feature-spec.md`](templates/feature-spec.md) to `features/NNN-short-name.md`. Write the problem,
   user stories, functional requirements (`FR-NNN-x`) and acceptance criteria (`AC-NNN-x`). Set the status to `Draft`.
2. **Design**: add design notes or update [`architecture.md`](architecture.md) when the change crosses components. Check the spec
   against the [constitution](constitution.md). Set the status to `Approved`.
3. **Implement**: open a PR that names the spec and the requirement IDs it covers (see the PR template). Fill in the spec's
   *Implementation* table with file links. Set the status to `Implemented`.
4. **Verify**: run the acceptance criteria on a simulator or device and record the results in *Verification*. Set the status to
   `Verified`.

A spec may only change behaviour through a PR that edits the spec itself. Code that disagrees with an approved spec is a bug in
one of the two, and the PR must say which.

## Documents

| Doc | Purpose |
| --- | --- |
| [constitution.md](constitution.md) | Non-negotiable principles every spec must satisfy |
| [product.md](product.md) | Vision, users, goals, non-goals, success metrics |
| [architecture.md](architecture.md) | Targets, processes, IPC, data flow, storage |
| [decisions/](decisions/) | Architecture decision records (ADRs) |

## Feature specs

| ID | Feature | Status |
| --- | --- | --- |
| [001](features/001-keyboard-dictation.md) | Keyboard dictation toggle and app handoff | Implemented |
| [002](features/002-on-device-transcription.md) | On-device transcription (whisper.cpp) and model management | Implemented |
| [003](features/003-cloud-fallback.md) | Confidence-based Groq fallback and online mode | Implemented |
| [004](features/004-optimization-modes.md) | Optimization modes (Raw, Clean, Message, Email, Notes, AI Prompt, custom) | Implemented |
| [005](features/005-history-and-stats.md) | History and stats | Implemented |
| [006](features/006-model-calibration.md) | Model calibration | Implemented |
| [007](features/007-widgets-and-shortcuts.md) | Widgets, Control Center and shortcuts | Implemented |
| [008](features/008-distribution.md) | Device debugging, TestFlight and App Store distribution | In progress |

Status values: `Draft` → `Approved` → `Implemented` → `Verified`, or `In progress` while partly done. No spec is `Verified` yet
because the first Xcode build and on-device run haven't happened.
