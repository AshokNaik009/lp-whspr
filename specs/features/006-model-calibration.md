# 006: Model calibration

- **Status**: Implemented (not yet verified on device)
- **Goal**: G6

## Problem

Users can't tell which model is accurate enough and fast enough on their device for their voice, or what fallback threshold makes
sense.

## Functional requirements

| ID | Requirement |
| --- | --- |
| FR-006-1 | Calibration shows a fixed reference sentence and records the user reading it once. |
| FR-006-2 | The same audio is transcribed by every installed model, and by Groq when a key is saved and "Include Groq" is on. |
| FR-006-3 | Each result shows accuracy (1 − word error rate against the reference), wall-clock time, local confidence and the text. |
| FR-006-4 | The recommended engine has the highest accuracy, with ties within 2% broken by the faster engine. |
| FR-006-5 | The user can apply any result as the active engine or model with one tap. |
| FR-006-6 | The app suggests a fallback threshold: the lowest confidence among results with accuracy of 90% or more, minus 10 points, clamped to 30–90%. |
| FR-006-7 | Calibration recordings never reach History and can't be stopped by keyboard commands. |

## Acceptance criteria

| ID | Given / When / Then |
| --- | --- |
| AC-006-1 | **Given** Tiny and Small installed, **when** I calibrate, **then** two results are shown with accuracy and time, and one is marked Recommended. |
| AC-006-2 | **When** I tap Use on Groq, **then** Settings shows the Groq Cloud engine. |
| AC-006-3 | **When** I record under 1 s, **then** I'm asked to read the whole sentence. |

## Implementation

| Requirement | Files |
| --- | --- |
| FR-006-1 – 6 | `App/CalibrationView.swift` (`CalibrationRunner`), `Shared/Core/WordErrorRate.swift`, `Shared/Core/FallbackPolicy.swift` |
| FR-006-7 | `App/DictationController.swift` (`beginCalibrationCapture` / `endCalibrationCapture`) |

## Verification

| Criterion | Device / OS | Result | Date |
| --- | --- | --- | --- |
| FR-006-3 WER, FR-006-6 threshold | `swift test` (WordErrorRateTests, FallbackPolicyTests) | Pass | 2026-11-12 |
| Device acceptance criteria | iPhone | Pending | |
