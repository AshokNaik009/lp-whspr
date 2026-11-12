# 002: On-device transcription and model management

- **Status**: Implemented (not yet verified on device)
- **Goal**: G2

## Problem

Dictation should work offline and keep audio private. Whisper models range from 32 MB to almost 1 GB, so they can't ship inside the
app. They're downloaded after install.

## User stories

- As a user, I want to download a Whisper model on first launch and choose its size, trading speed for accuracy.
- As a user, I want to load a model from my own URL or from the Files app.
- As a user, I want to delete models to free space.

## Functional requirements

| ID | Requirement |
| --- | --- |
| FR-002-1 | The app shall list a catalog of ggml models from `huggingface.co/ggerganov/whisper.cpp`: tiny.en, base(.en), small(.en) in q5_1, and large-v3-turbo in q5_0 and q8_0, with their sizes. |
| FR-002-2 | Downloads shall show progress and can be cancelled. Downloads continuing after the app is suspended (background `URLSession`) is a follow-up. |
| FR-002-3 | The app shall accept a custom `https` URL to a `.bin` model and import a `.bin` from Files. |
| FR-002-4 | Models shall be stored in `Application Support/Models` and excluded from backup. |
| FR-002-5 | The user shall pick one installed model as active. The first installed model is selected automatically. |
| FR-002-6 | Inference shall use whisper.cpp with Metal in the foreground and CPU only in the background. |
| FR-002-7 | English-only models (`.en`) shall force language `en`. Other models use the language setting (default auto). |
| FR-002-8 | Each result shall include the mean token probability (confidence) and the no-speech probability. |
| FR-002-9 | Custom vocabulary shall be passed as the initial prompt. |

## Acceptance criteria

| ID | Given / When / Then |
| --- | --- |
| AC-002-1 | **Given** no models, **when** I download Small (English), **then** progress shows and the model becomes active when it finishes. |
| AC-002-2 | **Given** airplane mode and an installed model, **when** I dictate, **then** the text is transcribed on-device. |
| AC-002-3 | **Given** an imported `.bin` from Files, **then** it appears under Installed and can be selected. |
| AC-002-4 | **When** I delete the active model, **then** another installed model (or none) becomes active. |

## Design notes

**Engine choice: whisper.cpp (C/C++) called directly from Swift.** whisper.cpp ships an official iOS XCFramework (pinned to
v1.9.2 with a checksum in `Packages/WhisperFramework`). Alternatives considered:

- **Rust (`whisper-rs`)** wraps the same whisper.cpp engine, so it would give the same speed and accuracy, with an extra toolchain
  and FFI layer. Rejected unless shared logic with the laptop app justifies it. See [ADR-0001](../decisions/0001-native-swift-with-whisper-cpp.md).
- **WhisperKit (Core ML)** was viable, but whisper.cpp matches the laptop's ggml models and quantizations.
- **Apple `SFSpeechRecognizer`** has lower accuracy for dictation, no model choice, and limited offline language support.

## Implementation

| Requirement | Files |
| --- | --- |
| FR-002-1 – 5 | `App/ModelManager.swift`, `App/ModelsView.swift` |
| FR-002-6 – 9 | `App/WhisperEngine.swift`, `Packages/WhisperFramework/Package.swift` |

## Verification

Pending the first device build.
