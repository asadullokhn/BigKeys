# BigKeys

A TouchChat-style iPadOS keyboard extension for people with limited fine motor control. Built by Ali, Artem, and Keiko for Apple Developer Academy Challenge 5, inspired by our community: The Inclusive Pair (Muhammad Sayfullah and Siti Fadillah, Singapore-based AAC advocates).

## The problem

Sayfullah communicates through TouchChat, an AAC (Augmentative and Alternative Communication) app with a large symbol grid. His symbol-grid speech is fluent — 30-45 seconds per sentence. But the moment he needs a word that isn't in his grid, he falls back to the standard on-screen keyboard, where a single mid-word tap can take up to 30 seconds. We watched this happen live during our interview. The bottleneck is spatial precision, not vocabulary or thinking speed: small keys demand an accuracy his hands don't have. That locks him out of most of the digital world — messaging, commenting, posting — because everything there assumes fast, precise typing.

## The idea

A system-wide keyboard (works in any app: Messages, Instagram, Notes) that brings the interface he already trusts — the TouchChat word grid — to every text field on the device. One tap inserts one whole word.

Our competitive research found nobody has built this: TouchChat, Proloquo2Go, Tobii Dynavox, CoughDrop, and Avaz all only compose-and-share from inside their own app. The closest precedent is AssistiveWare's Keeble (an accessible letter keyboard), which proves the architecture is shippable and App-Review-approvable.

## Design decisions, and where each one comes from

Every interaction decision traces to a specific research finding:

| Decision | Source |
|---|---|
| Word grid with category pages, letter keyboard only as fallback | TouchChat's own structure — the interface Sayfullah already has muscle memory for |
| Fitzgerald color key (pronouns yellow, verbs green, nouns orange, social pink) | Standard AAC color convention, used by TouchChat |
| Explore-then-commit: touching down costs nothing, sliding highlights, only lifting the finger commits | VoiceOver keyboard's two-stage typing pattern (accessible-keyboards research) |
| 0.5s double-tap guard: repeat commits of the same key are ignored | Game Accessibility Guidelines debounce recommendation (game-controllers research) |
| No dead zones: every point on the surface maps to the nearest key | The core insight that his problem is precision — there is no "between keys" to miss into |
| Prediction lives in the suggestion bar; grid cells never reorder | Motor planning depends on stable target positions — moving targets destroy AAC fluency |
| No Full Access permission | App Store Guideline 4.4.1 requires keyboards to work without it; prediction runs fully on-device so we never need to ask |
| Design for one person, let it generalize | "We're not trying to design for all of us, we're trying to design for each of us" — Bryce Johnson, Xbox Adaptive Controller co-inventor |

## Features (current state)

- Uniform frame on every level: pinned control columns — Home, Clear all, word-delete, cursor-left on the left; char-delete, Go, cursor-right, dismiss on the right — flank a 4×10 content grid. The pinned columns render identical frames regardless of level, so muscle memory for "delete is always over there" survives every navigation
- Three levels deep: the home word board (Core + Chat vocabulary) → Categories → a category's words. Letters and numbers are a parallel typing track reached via the abc/123 cells, for words not in the grid
- Category tiles: Recents / Core / People / Actions / Feelings / Food / Places / Art / Chat
- Recents learns his 12 most-used words automatically
- Prediction bar above the grid, with the globe key fixed at its right end (same slot on every level and device) — next-word prediction is an on-device bigram model, seeded with defaults, learning his real word patterns over time
- Letter keyboard (large-key QWERTY) and numbers layer as fallback, with system spell-checker word completions
- Word-level delete (one tap removes the whole last word)
- Punctuation cells that attach to the preceding word
- Two languages: English and Malay (Bahasa Melayu), toggled by the EN/MS key. Language switching relabels cells in place — grid positions never move, so muscle memory survives the switch. Prediction seeds, category names, and spell-check completions all follow the active language. Malay translations are drafts pending verification with Fadillah
- Three height presets cycled by the size key, persisted between sessions
- Dismiss key, like Apple's iPad keyboard
- Field-type intent mapping: the keyboard opens on the level that matches the focused field (e.g. a search field opens on letters, a numeric field opens on numbers) — applied once per field, never mid-typing; manual navigation always wins afterward
- Key-commit feedback: every committed tap plays the system input click and a light haptic impulse
- Responsive layout: word boards drop to a compact 5-column content grid when the system narrows the keyboard (floating, Split View, Slide Over); the letters and numbers levels keep all 10 columns so no character goes missing. Pinned columns never change width or position, at any width
- All learning (usage counts, bigrams) stays in the keyboard's own sandbox — no network, no shared containers, no Full Access

## Project structure

```
BigKeys/
  project.yml                      xcodegen spec — the source of truth for the project
  App/BigKeysApp.swift             container app: setup instructions + practice text field
  Keyboard/KeyboardViewController.swift   the entire keyboard extension
  BigKeys.xcodeproj                generated — regenerate with `xcodegen generate`
```

## Build and run

Requirements: Xcode 26+, an iPad (or simulator), and a signing team.

1. Clone, then open `BigKeys.xcodeproj` (or run `xcodegen generate` first if you've changed `project.yml` — `brew install xcodegen` if needed).
2. **Change `DEVELOPMENT_TEAM` in `project.yml` to your own team ID** (currently Ali's), regenerate, or just set your team in Xcode's Signing & Capabilities for both targets.
3. Build and run the `BigKeys` scheme on your device.
4. On the iPad: Settings → General → Keyboard → Keyboards → Add New Keyboard → BigKeys.
5. Open any app with a text field (or the BigKeys app's practice field), hold the globe key, choose BigKeys.

First run on a new device needs Developer Mode enabled (Settings → Privacy & Security → Developer Mode) and the device registered to your team — Xcode handles that automatically on first install.

## Testing

- Manual: build to a device, enable the keyboard, and use the practice field in the app. The regression checklist that matters: open/close/reopen the keyboard several times, rotate both ways, and confirm the height never grows (this was a real bug — see the git history on `fix/rotation-height`).
- Automated: `UITests/KeyboardHeightTests.swift` contains a scripted version of that exact checklist with height assertions. It is currently prefixed `todo_` (skipped) because reliably making a third-party keyboard the *active* keyboard inside a simulator is unsolved — the file documents what was tried. Run it by renaming the method to `test...` and running the BigKeys scheme's tests against a **freshly erased** simulator.

## Known limitations / not yet decided

- Malay vocabulary was drafted by the team, not by a native-speaking AAC user — verify every word with Fadillah before testing with Sayfullah. Singaporean Malay has colloquial forms a dictionary translation misses.
- Vocabulary is hardcoded. Editable vocabulary shared from the container app requires an App Group, which for keyboard extensions requires Full Access — that's a real architecture decision to make deliberately, not stumble into.
- No speech output. Audio in keyboard extensions is gated behind Full Access (this is exactly what Keeble does: on-device prediction free, speech gated). Same deliberate decision needed.
- Apple Foundation Models sentence completion is on the roadmap, deliberately not in the MVP. Open research question: extensions may be sandboxed away from the on-device model — needs a 5-minute empirical test (`SystemLanguageModel.availability` from inside the extension) before that feature is ever promised.
- True detachable floating (drag the keyboard anywhere) is not possible for keyboard extensions — the system owns that window. Our responsive layout handles whatever size the system gives us instead.
- Keyboard extensions have a tight memory ceiling (~30-80MB per our research). Current build is nowhere near it, but a large symbol library would be — test on older hardware before adding image assets.

## The team

- Ali — code
- Artem — code / PM, AI prediction research
- Keiko — design, accessible-interface research

Challenge context, research notes, and interview findings live in the team's Obsidian vault (`Projects/ADAP/CH5/`).
