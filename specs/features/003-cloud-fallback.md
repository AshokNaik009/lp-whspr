# 003: Confidence-based Groq fallback and online mode

- **Status**: Implemented (Groq endpoints checked with curl; app not yet verified on device)
- **Goal**: G3

## Problem

Small on-device models sometimes mishear noisy or accented speech. Users want cloud accuracy only when it's needed, and the option
to always use the cloud.

## Functional requirements

| ID | Requirement |
| --- | --- |
| FR-003-1 | Settings shall offer the engine choice **On-device** or **Groq Cloud** (online). |
| FR-003-2 | With fallback enabled (the default) and a Groq key saved, if local confidence is below `fallbackConfidenceThreshold` (default 55%) and the no-speech probability is below 0.8, the app shall send the recording as 16 kHz WAV to Groq and use Groq's text. |
| FR-003-3 | If no local model is installed, or local inference throws, and a key is saved, the app shall use Groq. |
| FR-003-4 | If the Groq call fails during fallback, the app shall keep the local text. |
| FR-003-5 | The Groq key shall be stored in the Keychain, never in UserDefaults, source or logs. |
| FR-003-6 | The result shall record which engine produced it, for example `Groq (local confidence 41%)`. |
| FR-003-7 | The Groq transcription model (default `whisper-large-v3-turbo`) and rewrite model (default `openai/gpt-oss-20b`) shall be configurable. |

## Acceptance criteria

| ID | Given / When / Then |
| --- | --- |
| AC-003-1 | **Given** threshold 55% and a local result at 40%, **then** the inserted text comes from Groq and History shows the reason. |
| AC-003-2 | **Given** a local result at 80%, **then** no network request is made. |
| AC-003-3 | **Given** fallback on but no key, **then** the local text is used, with no error. |
| AC-003-4 | **Given** engine = Groq and no network, **then** an error is shown and nothing is inserted. |

## Design notes

Confidence is the mean token probability across all segments, from `whisper_full_get_token_p`, skipping special tokens. The
no-speech guard stops silence from being sent to the cloud. Public App Store builds must use a proxy instead of user keys, as the
[constitution](../constitution.md) requires. Calibration ([006](006-model-calibration.md)) suggests a threshold for each user.

## Implementation

| Requirement | Files |
| --- | --- |
| FR-003-1, 7 | `App/Settings.swift`, `App/SettingsView.swift` |
| FR-003-2 – 4, 6 | `App/DictationController.swift` (`transcribe(samples:)`) |
| FR-003-5 | `App/Keychain.swift` |
| Transport | `App/GroqClient.swift`, `App/WAVEncoder.swift` |

## Verification

| Criterion | Device / OS | Result | Date |
| --- | --- | --- | --- |
| Groq transcription and chat endpoints respond (curl, same request shape) | Linux VM | Pass | 2026-11-12 |
