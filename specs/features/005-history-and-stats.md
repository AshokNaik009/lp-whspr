# 005: History and stats

- **Status**: Implemented (not yet verified on device)
- **Goal**: G5

## Problem

Users lose dictated text when an insert fails or they switch apps. They also want to see the value of dictation, as Wispr Flow
shows it.

## Functional requirements

| ID | Requirement |
| --- | --- |
| FR-005-1 | Every successful dictation (app or keyboard) is saved with: date, raw text, final text, mode, engine, cloud yes/no, local confidence, audio seconds and processing seconds. |
| FR-005-2 | History is grouped by day, newest first, and searchable across raw and final text. |
| FR-005-3 | Entries can be copied (swipe), shared, deleted (swipe) or cleared all at once (with confirmation). |
| FR-005-4 | The detail view shows the original transcript next to the result, plus all metadata. |
| FR-005-5 | History is stored only on the device, in `Application Support/history.json` with file protection, capped at 2,000 entries. |
| FR-005-6 | Stats show: total words, dictations, audio time, speaking WPM, time saved vs typing at 40 WPM, on-device share, Groq count, average processing time, current daily streak, a 7-day words chart and words by mode. |

## Acceptance criteria

| ID | Given / When / Then |
| --- | --- |
| AC-005-1 | **When** I dictate from the keyboard in Messages, **then** the entry appears in History with engine and mode. |
| AC-005-2 | **When** I search a word from an old dictation, **then** only matching entries are listed. |
| AC-005-3 | **Given** 120 words over 60 s of audio, **then** Stats shows 120 WPM and 2 min saved (120/40 − 1). |
| AC-005-4 | **Given** dictations today and yesterday, but none the day before, **then** the streak is 2 days. |

## Implementation

| Requirement | Files |
| --- | --- |
| FR-005-1, 5 | `App/HistoryStore.swift`, `App/DictationController.swift` (`process`) |
| FR-005-2 – 4 | `App/HistoryView.swift` |
| FR-005-6 | `App/HistoryStore.swift` (`stats`), `App/StatsView.swift` |
