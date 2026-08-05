# CLAUDE.md — rules for Claude Code sessions in this repo

## What this project is

BigKeys is a TouchChat-style iPadOS keyboard extension for a specific real person: an AAC user with spastic quadriplegic cerebral palsy whose bottleneck is spatial precision (up to 30 seconds per tap on a standard keyboard), not vocabulary or thinking speed. Read `README.md` before changing anything — every design decision traces to community research, and the reasoning matters more than the code.

## Git rules

- **Never push to `master`.** It is protected. Always work on a branch (`feat/...` or `fix/...`) and open a PR.
- PRs require review from @asadullokhn before merging. Do not merge your own PRs.
- **Never commit signing changes** — `DEVELOPMENT_TEAM` in `project.yml` or anything provisioning-related. Set the team locally in Xcode instead.
- Commit messages: imperative mood, concise, no emojis, **no `Co-Authored-By` lines**.
- Do not force-push. Do not amend published commits.

## Build rules

- `project.yml` is the source of truth; the `.xcodeproj` is generated. After editing `project.yml`, run `xcodegen generate` and commit both together.
- Build both targets before declaring anything done. Then actually run the keyboard on a device/simulator and type with it — including the practice field in the container app.
- The keyboard extension has a ~30-80MB memory ceiling. Keep it lightweight: no heavy dependencies, no image assets in the extension target.

## Design invariants — do not "improve" these away

The full list with reasoning lives in `CONTRIBUTING.md`. The short version:

1. Grid cell positions never move or reorder (muscle memory). New words go at the end.
2. Touch-down never types. Lift-off commits. Sliding is free exploration.
3. Same-key commits within 0.5s are ignored (delete, word-delete, clear-all, and the cursor arrows are exempt).
4. Every point on the keyboard maps to the nearest key — no dead zones.
5. `RequestsOpenAccess` stays `false`. No network calls, no shared containers, no Full Access — this is a deliberate product decision, not an oversight.
6. Prediction appears only in the suggestion bar, never by reordering the grid.
7. Language switching relabels cells in place.
8. Malay vocabulary is an unverified draft — flag any translation you add as unverified.
9. Pinned control columns render identical frames on every level — never derive their geometry from the content grid's column count.

## When unsure

If a change touches any invariant above, or adds a permission, framework, or architectural pattern — stop and say so in the PR description instead of deciding unilaterally. The team reviews design changes together; the research behind them lives in the team's shared vault, not in this repo.
