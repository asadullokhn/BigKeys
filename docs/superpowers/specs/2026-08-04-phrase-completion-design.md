# Typikey — On-Device Phrase Completion (Cotypist-style)

Date: 2026-08-04
Status: approved design (approach A), pending implementation plan
Source: Cotypist feature analysis (cotypist.app) + Ali's scope rulings + FM-in-extension feasibility spike

## Goal

Bring Cotypist's core experience to the Typikey keyboard within extension constraints: as the user composes, the suggestion bar offers a short multi-word continuation of the sentence in his own voice; one tap takes the whole phrase, or a next-word chip takes it one word at a time. All inference on-device via Apple's FoundationModels; when the model is unavailable or failing, the bar silently degrades to today's bigram prediction.

## Decisions made (with Ali, 2026-08-04)

1. **Scope v1:** phrase continuation + word-by-word acceptance + voice-learning. Typo autocorrect: OUT. Emoji triggers: OUT.
2. **Fallback:** graceful degrade to the existing learned-bigram engine — no new fallback machinery. If FM proves unusable anywhere, current shipping behavior IS the product there.
3. **Approach A** approved: FM-first with degrade, no parallel n-gram phrase engine.

## Spike findings (empirical, 2026-08-04, throwaway worktree)

- FoundationModels **imports, links, and reports `availability == .available` inside the keyboard extension** on the iPad simulator — no extension-sandbox barrier.
- Actual generation (`LanguageModelSession.respond`) fails on the **simulator** with `ModelManagerServices.ModelManagerError` code 1026, identically in the extension and the host app → simulator inference limitation, not an extension one.
- Consequence embraced by this design: **the simulator always exercises the degraded path**, which keeps the whole existing UITest suite meaningful in CI. Real generation quality/latency is a physical-device concern.
- Open: cold/warm latency on hardware. See Open items.

## Architecture

### New unit: `Keyboard/CompletionEngine.swift` (extension target)

A deliberate, sanctioned exception to the single-file pattern — one clean boundary, ~150 lines:

- `final class CompletionEngine` with:
  - `func requestCompletion(context: String, vocabulary: [String], onResult: @escaping (Completion?) -> Void)` — debounced entry point; at most one in-flight generation; new calls cancel stale ones via a monotonically increasing generation token; results delivered on the main queue with the token checked (stale results dropped).
  - `struct Completion { let words: [String] }` — 1–5 words, sanitized (trimmed, no newlines, split on whitespace, empty → nil).
  - `private(set) var isDegraded: Bool` — starts false; set true permanently for the session after 2 consecutive hard failures (thrown errors or timeouts) or when `SystemLanguageModel.default.availability != .available` at first use. Once degraded, `requestCompletion` returns nil immediately and never touches FM again.
  - Debounce 300ms; per-request timeout 2s (Task cancellation).
  - Session reuse: one `LanguageModelSession` created lazily, recreated after a failure.
  - Everything `#if canImport(FoundationModels)` + `if #available(iOS 26.0, *)` guarded; on older OS the engine constructs pre-degraded.

### Prompt (voice-learning)

Built per request, entirely from on-device data:

- Instructions (fixed): continue the user's sentence naturally; at most 5 words; plain text only; no punctuation unless ending the sentence; match the user's simple, direct style.
- Voice sample: the user's top ~40 words by `usageCounts` (the existing persisted learning — names and personal vocabulary included), passed as "words this user often uses".
- Context: the last ≤200 characters of `textDocumentProxy.documentContextBeforeInput`.
- Nothing else. No network, no shared containers — invariant 5 holds; the privacy story mirrors Cotypist's "your words never leave your device".

### Controller integration (`KeyboardViewController`)

- Trigger points: end of `commit(_:)` (word-level commits) and `textDidChange` — both already call `updateSuggestions()`; the completion request rides the same call sites.
- `updateSuggestions()` bar states (invariant 6 — prediction only in the bar; grid never changes):
  - **Continuation present** (word levels only): slot 1 = `▸ <first word>` (accept one word), slot 2 = full phrase chip (accepts all words), slot 3 = best bigram word (today's top prediction). Letters level keeps today's UITextChecker behavior; completions are a word-level feature in v1.
  - **No continuation / degraded / letters level:** exactly today's three slots. No layout shift beyond chip titles.
- Phrase acceptance inserts **word-by-word through the existing `insertWord` path** (spacing, sentence-start capitalization, usage counts, and bigram learning all come free); `▸` inserts only `words[0]` and lets the next request recompute.
- The globe slot in the bar is untouched.

## Preserved invariants

Lift-off commit; debounce and its exemptions; no dead zones; pinned columns (#9); prediction only in the suggestion bar; `RequestsOpenAccess = false`, no network, on-device only; language relabel in place; no new Malay strings (chip content is user-language text generated on device; UI adds no new labels beyond the `▸` prefix); height machinery untouched.

## Testing

- The existing 5-test suite must pass unchanged — on the simulator the engine is always degraded (spike-proven), so the suite exercises the fallback path by construction.
- New UITest: with FM failing (simulator reality), the bar renders today's slots and typing works — asserting the degrade is invisible.
- CompletionEngine's sanitization and token/stale-result logic verified by code review (no unit-test target in this repo); keep the logic pure enough to read.
- Real generation quality and latency: physical-device verification, manual, against his real vocabulary.

## Out of scope (backlog)

Typo autocorrect on commit; emoji suggestions; a stronger n-gram fallback; keyword capture → per-context vocabulary (Gilbert's idea — natural v2 on top of this engine); letters-level completions; latency-adaptive debounce.

## Open items

1. **On-device latency probe** — requires installing a probe build on the Academy iPad mid-development, which the standing simulator-only rule forbids; awaiting Ali's explicit go. Until then the debounce (300ms) and timeout (2s) are conservative guesses, tuned after the feature lands on hardware.
2. FM availability on **Sayfullah's own iPad Pro 12.9" 5th gen (M1)**: M1 supports Apple Intelligence, so the model should be available there once iPadOS 26 + Apple Intelligence are enabled — verify during the next family visit before promising the feature.
