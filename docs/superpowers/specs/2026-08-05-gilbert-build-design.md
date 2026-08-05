# Typikey — Gilbert Build (capture, customization, pointer)

Date: 2026-08-05. Status: approved direction (Ali: "work on all Gilbert's notes, bring everything"). Single spec+plan; executes as three code tasks + one research dispatch.

## Goal

Implement every code-actionable idea from the 4 Aug Gilbert session:
(A) automatic keyword capture, (B) independent tremor-friendly customization v1, (C) pointer/hover access. Research homework (device sprint) runs as vault notes, not code.

## Design

### Shared data (app group `group.com.asadullokh.ch5.typikey`, fallback sandbox — same `store` plumbing as Full Access commit)

- `myWords: [String]` — the user's own words. Rendered as a new **"Mine" category** appended after Chat (10th tile — exactly fills the 5×2 tiling; remove the compact `prefix(9)` cap, ledger minor now load-bearing). Cells use `.social` color, no emoji. Append-only ordering (invariant 1).
- `captureCounts: [String: Int]` — words typed **letter-by-letter** (letters level, ≥3 letters, terminated by space/return/punct or a field switch), lowercased. Grid-cell taps do NOT count (already vocabulary). A word reaching **3 uses** and not already in vocabulary/myWords is a **capture candidate**.
- Keyboard includes myWords in `topVocabulary()` (completion prompts) and in the vocab index used for Recents rendering is NOT touched (myWords are plain text cells).

### (A) Capture — keyboard side

In the letters-level char-commit path: accumulate current typed token; on terminator, if token ≥3 letters and contains letters only, `captureCounts[token] += 1` in `store`. No UI in the keyboard beyond the existing bar (candidates surface in the app; invariant 6 untouched).

### (B) Customization v1 — container app

New "My Words" screen reachable from SetupView (NavigationLink, large row):
- **Captured section**: candidates (count ≥3, not in myWords) sorted by count desc; each row = the word + huge **Add** and **Skip** buttons (min 64pt height, full-width halves). Add → append to myWords, remove from captureCounts. Skip → remove from captureCounts.
- **My Words section**: list of myWords; each row has a huge **Remove** button with a two-tap arm ("Remove" → "Tap again"), mirroring the keyboard's clear-all pattern. Below: a large TextField + **Add word** button (52pt+) for manual entry (trim, non-empty, dedupe case-insensitively).
- All controls sized for tremor: no swipe actions, no drag, no small ✕.
- Writes go to the shared suite directly (`UserDefaults(suiteName:)` — the app always can; the keyboard picks changes up on next `viewWillAppear` reload of myWords). Keyboard re-reads myWords in `viewWillAppear`.

### (C) Pointer/hover — keyboard side

`UIHoverGestureRecognizer` on the tracking view: hover moves the same highlight `touchMoved` uses (`keyIndex(at:)` nearest-key); hover end clears it. No commit on hover — click/touch commits as today. Serves trackpad, Apple Pencil hover, and AssistiveTouch pointer devices (the joystick).

### Invariants

All nine hold. Mine appends (1); capture adds no bar UI beyond existing (6); no network (5); no new Malay strings — Mine's category name is "Mine" in both languages (8 flagged); pinned geometry untouched (9).

### Testing

- UITest: seed the standard UserDefaults (fallback store, sim runs ungranted) via the app's launch environment is NOT possible for the extension — instead test the observable path: type a word 3× via letters level in the practice field, then open the app's My Words screen and assert the candidate row exists (app reads the same fallback store? NO — app and extension sandboxes differ without the group on sim... On the simulator the app-group container DOES work (simulators don't enforce Full Access gating for suite access? — the keyboard's `store` gates on `hasFullAccess`, false on sim → extension writes to ITS sandbox; the app cannot see it). Therefore the cross-process UITest is only meaningful with full access granted — NOT automatable on sim.
- So: suite-level guarantee = existing 6 tests stay green + one new UITest for the Mine category rendering when the KEYBOARD's own store has myWords — seed by typing a manual word in the app? Same sandbox problem.
- Honest resolution: (1) unit-style verification by code review; (2) new UITest limited to the APP side: navigate to My Words, add a word manually via the editor, assert it appears in the list (app-sandbox only, deterministic); (3) keyboard Mine-category + capture verified manually on the 10th-gen iPad (grant full access there) and noted in the PR. Existing 6 tests must stay green.

## Plan

### Task G1 — Shared words + capture + Mine category (keyboard)
`Keyboard/KeyboardViewController.swift`: myWords load in viewDidLoad + reload in viewWillAppear; Mine category appended in `allCategories()`; remove compact `prefix(9)` cap (both categories branches handle 10); capture accumulator in the `.char` commit path + terminators (space/ret/punct/`textDidChange` field switch resets token); captureCounts writes to `store`; myWords included in `topVocabulary()`. Full suite green (6 tests — Mine tile also implicitly exercised by pinned-frame test's categories tap? It taps "Core" — unaffected). Commit: "Capture typed words and render a Mine category".

### Task G2 — My Words editor (app)
`App/TypikeyApp.swift`: MyWordsView per design (B); NavigationLink row in SetupView ("My Words — add your own keys"); shared-suite read/write with `UserDefaults(suiteName:)`; new UITest `MyWordsTests.testManualAddShowsInList` (launch app, navigate, add "quando", assert row). Suite green (7). Commit: "Add the tremor-friendly My Words editor".

### Task G3 — Hover highlight (keyboard)
UIHoverGestureRecognizer wired in viewDidLoad on trackingView → began/changed: `touchMoved(to:)`; ended/cancelled: `touchCancelled()`. Suite green (7). Commit: "Highlight keys under a hovering pointer".

### Task G4 — verification, docs, PR
README feature bullets (capture, My Words, pointer); suite; push branch `feat/gilbert`; PR "Keyword capture, My Words customization, and pointer hover" with the manual-verification caveats. Research dispatch runs parallel (vault, not repo).
