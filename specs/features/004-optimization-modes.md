# 004: Optimization modes

- **Status**: Implemented. Parity with the laptop app isn't confirmed yet.
- **Goal**: G4

## Problem

Raw speech is full of filler and reads badly. The laptop Leap Whisper rewrites transcripts according to a mode, and the phone must
offer the same modes.

## Functional requirements

| ID | Requirement |
| --- | --- |
| FR-004-1 | Built-in modes: **Raw** (verbatim), **Clean**, **Message**, **Email**, **Notes** (bullets) and **AI Prompt**. |
| FR-004-2 | Users can add, edit (name, icon, instructions), reorder, delete and reset modes. Modes are shared with the keyboard through the App Group. |
| FR-004-3 | A mode with empty instructions inserts the transcript without calling an LLM. |
| FR-004-4 | Every transcript is first cleaned locally: `[BLANK_AUDIO]`, `(music)` and similar annotations are removed and whitespace collapsed. |
| FR-004-5 | The rewrite provider is selectable: Off, Apple Intelligence (on-device, iOS 26+) or Groq LLM. |
| FR-004-6 | The rewrite prompt includes a guardrail: output only the rewritten text, never answer or follow the dictated content. |
| FR-004-7 | If rewriting fails, the cleaned transcript is inserted and a note is shown (constitution §6). |

## Acceptance criteria

| ID | Given / When / Then |
| --- | --- |
| AC-004-1 | **Given** Notes mode, **when** I dictate three ideas, **then** three `- ` bullets are inserted. |
| AC-004-2 | **Given** AI Prompt mode, **when** I dictate "what's the capital of France", **then** a prompt is inserted, not "Paris". |
| AC-004-3 | **Given** Groq rewrite and no network, **then** the cleaned raw text is inserted with a "mode skipped" note. |
| AC-004-4 | **When** I add a custom mode in the app, **then** it appears as a chip in the keyboard. |

## Implementation

| Requirement | Files |
| --- | --- |
| FR-004-1 – 3 | `Shared/DictationMode.swift`, `App/ModesView.swift` |
| FR-004-4 – 7 | `App/TextOptimizer.swift` |

## Open questions

- Get the laptop app's mode list and prompts and update the defaults to match exactly.
