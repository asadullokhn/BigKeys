# BigKeys — Uniform Grid Frame Redesign

Date: 2026-08-04
Status: approved design, pending implementation plan
Source: team mock (annotated iPad keyboard, 2026-08-03) + Ali's answers to the four structural questions

## Goal

Restructure the keyboard so every level renders inside one uniform grid frame with control keys pinned to fixed edge positions, per the team mock: word-prediction bar on top, a 4-row content grid, three navigation levels (home buttons → categories → words), letters as the typing fallback, no spacebar, and field-type-aware starting level.

## Decisions made (with Ali, 2026-08-03)

1. **One uniform frame** — all levels (home, categories, words, letters, numbers) render in the same grid; control keys occupy identical positions on every level.
2. **Home = core word board** — TouchChat's pattern: one tap = one word. Letters reached via an `abc` cell.
3. **No spacebar.** Word commits auto-space (existing behavior). One normal-sized space cell exists on the typing surface (letters and its numbers sub-level) only.
4. **Intent-awareness v1 = field-type mapping only.** Read once when the keyboard attaches to a field; never switch mid-typing.

## The frame

**12 columns total: pinned control columns at 0 and 11, content grid 4 rows × 10 columns between them.**

The mock's "4 rows 10 columns" is the content grid; its annotated controls sit on the QWERTY edge keys, outside the 10 letters. (Adjustment from the first sketch, which showed 10 total columns / 8 content: 8-wide content cannot hold a QWERTY row. 10-wide content matches both the mock's note and QWERTY exactly.)

| row | col 0 (pinned) | cols 1–10 (content) | col 11 (pinned) |
|---|---|---|---|
| 0 | Home | level content | ⌫ (character delete) |
| 1 | Clear all | level content | Go (label follows field: Send / Search / Go / return) |
| 2 | ⌫ word | level content | → (cursor right) |
| 3 | ← (cursor left) | level content | ⌄ (dismiss keyboard) |

- Pinned keys are identical in position, label style, and behavior on every level. This is a **new invariant** alongside the existing eight.
- The globe (change keyboard) appears only when `needsInputModeSwitchKey`, replacing the last content cell of row 3 on every level (stable position).
- Prediction bar stays above the grid: 3 suggestion slots, existing behavior (bigram prediction on word levels, UITextChecker completions on letters).

## Levels

### Level 1 — Home (the "buttons" level)
40 content cells: 4 navigation cells + 36 fixed word cells.
- Navigation cells (fixed positions, start of row 0): `Categories`, `abc`, `EN/MS`, `⤢` (size).
- Word cells: the current Core vocabulary (24 cells incl. `.` and `?`) + the 12 Chat-category words (hello … haha) to fill the board — 36 fixed word cells. All Fitzgerald-colored, positions fixed forever; new words append at the end (existing invariant).
- Home key from anywhere returns here in one tap.

### Level 2 — Categories
Recents + the 8 categories as large content cells (replaces today's tab row entirely). Tapping one opens Level 3.

### Level 3 — Words
The chosen category's words in the content grid, colors/emoji as today. Word commit behavior unchanged: auto-space, sentence-start capitalization, usage + bigram learning.

### Letters (via `abc`; outside the 3-level hierarchy)
Content rows: `q w e r t y u i o p` / `a s d f g h j k l ⇧` / `z x c v b n m , . ?` / bottom row: `space`, `123`, remaining cells empty (nearest-key mapping absorbs them). Constraints: full QWERTY shape (10-wide top row), one normal-sized space cell, `⇧` shift, `123` to numbers. No "back to words" cell needed — the pinned Home key covers it.

### Numbers (sub-level of letters, via `123`)
Digits 1–0 as the top content row, common symbols below, `abc` back cell, one space cell. Same pinned frame.

## Intent mapping (applied once per field attach)

| Field signal | Starting level |
|---|---|
| `returnKeyType` `.search` / `.google` / `.websearch` | Letters |
| `returnKeyType` `.send` | Words: Chat category |
| `keyboardType` `.emailAddress` / `.URL` / `.numberPad` etc. | Letters (numbers for number pads) |
| everything else | Home |

Go key label follows `returnKeyType`. Level never changes mid-typing; manual navigation always wins after attach.

## Key behaviors

- **Clear all** (destructive): two-step arm — first tap relabels the key "tap again"; second tap within 3s clears; otherwise disarms. Clearing: move cursor to end (`adjustTextPosition` past `documentContextAfterInput`), then delete backward while context remains, bounded loop. Limitation (accepted): extensions only see the field's exposed context window; in very long documents this clears the visible window. In his real use (messages, search) that is the whole text.
- **Arrows**: `adjustTextPosition(byCharacterOffset: ±1)` per tap. Exempt from the 0.5s double-tap guard (like deletes — repeats are intentional).
- **⌫ / ⌫ word**: existing behaviors, now pinned.
- **Go**: `insertText("\n")`, label per field.
- **EN/MS**: existing in-place relabel behavior, now a home-board cell.
- **⤢ size**: existing three height presets, now a home-board cell.

## Preserved invariants (unchanged)

Lift-off commit / slide-to-explore; 0.5s same-key debounce (deletes and arrows exempt); no dead zones (nearest key wins); prediction only in the bar; `RequestsOpenAccess = false`, no network, on-device learning only; language switch relabels in place; Malay strings remain unverified drafts; the height-constraint machinery (content-view constraint, self-heal, rotation handling) is not touched.

This redesign moves cell positions once, by explicit team decision (the mock). After it lands, the positions-never-move invariant applies to the new layout.

## Compact width (floating / Split View / Slide Over)

Below the existing 500pt threshold: pinned columns stay; content drops from 10 to 5 columns showing the first 20 content cells (words) or an abbreviated letters packing. Cells stay big rather than all shrinking (existing philosophy). Exact compact packing decided at implementation; pinned keys never move.

## Out of scope (backlog, not this change)

Saved-phrases page; CloudKit/language packs; joystick/pointer support; content-based intent guessing; any Full Access feature.

## Implementation approach

Evolve `KeyboardViewController.swift` in place (approach A): replace the `Layer` enum + `rows(for:)` free-form rows with a `Level` model and one frame renderer that lays out pinned columns + content grid. Keep TrackingView, styling, commit path, prediction, persistence, and all height machinery as-is. Single-file diff, PR-reviewable.

## Testing

- Build both targets; run in simulator; type through every level and field type (Safari search field, Messages-style field, plain note) including the container app's practice field.
- New UITest: pinned control keys occupy identical frames across all levels (the new invariant, asserted).
- Existing `KeyboardHeightTests` must still pass.
- Manual: clear-all two-step arm/disarm, arrows at document edges, globe presence on device vs simulator.
