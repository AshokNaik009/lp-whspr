# 010: Fix mistakes without leaving the keyboard

- **Status**: Approved
- **Goal**: G1, G4

## Problem

The keyboard can insert a dictation and nothing else. A wrong take, the wrong mode or one wrong word means selecting and
deleting by hand, or switching keyboards.

## User stories

- As a user, I want to take back a dictation with one tap.
- As a user, I want to clear everything I dictated into this field and start over.
- As a user, I want the same words in another mode without saying them again.
- As a user, I want to change what I just dictated by saying how.

## Functional requirements

| ID | Requirement |
| --- | --- |
| FR-010-1 | **Undo** removes the last dictation the keyboard inserted into the current text field. |
| FR-010-2 | Holding Undo offers **Remove all**, which removes every dictation inserted into the current text field, newest first, after a confirmation. |
| FR-010-3 | The keyboard shall delete only text it inserted, and only while that text still sits unchanged directly before the cursor. Otherwise it deletes nothing and says why. Remove all stops at the first dictation that fails this check. |
| FR-010-4 | **Redo as…** offers the other modes after a dictation. The app re-runs the stored raw transcript in the chosen mode, and the keyboard replaces the inserted text under FR-010-3. If the text can't be replaced, the new version is offered as an Insert chip. |
| FR-010-5 | **Edit by voice** records a spoken instruction ("make that shorter", "change Tuesday to Wednesday") and applies it to the last dictation, replacing it under FR-010-3. |
| FR-010-6 | Redo as… and Edit by voice need the app running. With the mic ready they work in place; otherwise they open the app the way the mic button does. |
| FR-010-7 | The record of inserted dictations is kept per text field and dropped when the field changes. |

## Out of scope

- Editing text selected in the host app. A keyboard gets only a truncated view of a long selection, and inserting replaces the
  whole selection, so the unread part would be lost
  ([Stack Overflow 79903594](https://stackoverflow.com/questions/79903594)). To be revisited after a test on a device shows
  when a selection is readable in full.

## Acceptance criteria

| ID | Given / When / Then |
| --- | --- |
| AC-010-1 | **Given** I just dictated "see you at five", **when** I tap Undo, **then** exactly that text, including the space the keyboard added before it, is gone. |
| AC-010-2 | **Given** I dictated, then typed a word after it, **when** I tap Undo, **then** nothing is deleted and the keyboard says the text has changed. |
| AC-010-3 | **Given** three dictations in a row in one field, **when** I hold Undo and confirm Remove all, **then** all three are gone and text I typed before them is untouched. |
| AC-010-4 | **Given** a dictation inserted in Raw, **when** I choose Redo as Email, **then** the raw text is replaced by the email version without recording again, and History shows one entry. |
| AC-010-5 | **Given** a dictation "let's meet Tuesday at five", **when** I tap Edit by voice and say "change Tuesday to Wednesday", **then** the field reads "let's meet Wednesday at five". |
| AC-010-6 | **Given** I move to another text field, **then** Undo no longer offers the dictations made in the previous one. |

## Design notes

`UITextDocumentProxy` gives the keyboard `insertText`, `deleteBackward` and a window of text before the cursor that is usually
cut at the last sentence end and capped at a few hundred characters. FR-010-3 is therefore checked against the tail of the
inserted text that fits in that window, not the whole of it. The bookkeeping lives in `Shared/Core` so it can be tested
against a simulated proxy.

## Implementation

| Requirement | Files |
| --- | --- |

## Verification

| Criterion | Device / OS | Result | Date |
| --- | --- | --- | --- |
