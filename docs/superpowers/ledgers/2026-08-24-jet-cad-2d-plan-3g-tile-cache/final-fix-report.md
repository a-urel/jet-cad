# Plan 3g — final fix report (whole-plan review, single fix wave)

Applied against the reviewer's seven findings on the tree at `82976ce`. Verdict
was "fit to merge after findings 1 and 4"; the other five are one-liners. No
behaviour change anywhere except finding 4's rename — every other change is a
comment or note correction.

---

## F1 — `quantiseCamera`'s doc comment described removed behaviour

Three files touched, all doc-only:

- `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart:158-174` — rewrote
  `quantiseCamera`'s doc. It no longer says quantisation "applies to the live
  path too" / "Quantising both paths" / "identical in both paths". It now
  states: quantisation belongs to the tiled path only, points at
  `draft_canvas.dart:384-392` for why the default path does not call it, names
  the one production call site (`tile_cache.dart:672`, inside `paintFrame`),
  and names the comparison instrument's own separate quantisation of its live
  arm (`test/support/tile_comparison.dart:81`).
- `docs/superpowers/specs/2026-08-23-jet-cad-2d-plan-3g-tile-cache-design.md`:
  - Line 280 (D9 heading): `"...on **both** paths"` → `"...on the **tiled**
    path"`.
  - Line ~310 (closing line): `"identical in the tiled and live paths"` →
    `"identical to what the comparison's quantised live arm draws"` — the
    section immediately above already carried the correct account; the
    heading and closing line now agree with it instead of contradicting it.
- `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart:141-151` —
  `DraftCanvas.tiles`'s doc comment now states the half-device-pixel
  consequence: with `tiles` on, the drawing sits up to half a device pixel
  from where it sits with `tiles` off, because the tiled path quantises the
  camera and the default path does not. Phrased as a consequence to be aware
  of, not a requirement — so it does not read as an accepted imprecision that
  a future "tiles as default" change would be locked into.

## F4 — `typedef VoidCallback` collided with `dart:ui`'s

Renamed to `TableListener` in `packages/jet_cad_2d/lib/src/document/tables.dart`.
`package:jet_cad_2d` stays pure Dart — no `dart:ui` or Flutter import was
touched or added. Full call-site list (all in this one file; nothing else in
the tree referenced `VoidCallback` from this package):

| line | site |
|---|---|
| 23 | `typedef TableListener = void Function();` |
| 32 | `TableListenable.addListener(TableListener listener)` |
| 33 | `TableListenable.removeListener(TableListener listener)` |
| 42 | `_TablesNotifier._listeners` field: `List<TableListener>` |
| 45 | `_TablesNotifier.addListener(TableListener listener)` |
| 48 | `_TablesNotifier.removeListener(TableListener listener)` |

`packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart` references
`TableListenable` (the interface, unrenamed) but never wrote `VoidCallback`
unqualified, so it needed no change. Confirmed via
`grep -rln "VoidCallback" packages apps` → only `tables.dart`, before the edit.

## F2 — stale tile-count arithmetic (256 px assumptions, 512 px shipped)

`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`:
- `:775` (was `:768`): `"at 256 px a full visible set is 154 tiles, and 154
  painter invocations"` → `"at 512 px a full visible set is about 48 tiles
  (see the 48.0 MiB figure above), and 48 painter invocations"`.
- `:789` (was `:781`): `"~130 blits"` → `"~48 blits"`.

Both now agree with the file's own `:132` figure (48.0 MiB / 1 MiB-per-tile at
512 px = 48 tiles).

## F3 — `onMutated`'s doc didn't match `clear()`'s unconditional fire

`packages/jet_cad_2d/lib/src/document/tables.dart:73-78` (in `TableSection`):
rewrote the `onMutated` doc to say what the code does — fires after `add`/
`remove` only when they actually change the section, and unconditionally from
`clear()`, because `json_codec.dart`'s loader always clears all six sections
before repopulating (`DraftDocument.empty()` seeds layer 0, linetypes 1-4 and
text style 5, so the seeded state must be observably wiped even when a
section's incoming data happens to be empty). No code change — the behaviour
was already correct; only the comment was wrong.

## F5 — results note's commit/task line was stale

`docs/superpowers/notes/2026-08-24-plan-3g-results.md:3`: verified that
`37918c5` is still the plan's last **code**-changing commit (`666714d`,
`a0312cc`, `c26055e`, `3071096`, `82976ce` are all docs-only — checked with
`git show --stat` on each). Reworded the line to say the note is written
against `37918c5` — named explicitly as the last code commit — after Tasks 1
through 12, and noted that Task 12's own results were folded in three commits
after the note was first written, without moving the code tree.

## F6 — wrong citation for "every table record is `@immutable`"

`docs/superpowers/notes/2026-08-24-plan-3g-results.md:384-387`: `tables.dart:
73-95` was `TableSection`, not a record. Replaced with the actual locations,
verified by reading each: the contract at `tables.dart:16` (`TableRecord`),
and the six records — `LayerRecord` (:138), `LinetypeRecord` (:234),
`TextStyleRecord` (:278), `PatternRecord` (:405), `DimStyleRecord` (:451),
`AppIdRecord` (:511). (Two other `@immutable` classes in the file, `DashPattern`
and `PatternLine`, are value helpers, not table records, and are excluded.)

## F7 — `_probeBake`'s reimplementation framed as a strength, no gap named

`apps/dev_harness_2d/lib/measurement_rig.dart`: added one comment directly
above the `overdraw=` print statement (immediately before line ~567) naming
gap **G7**: `overdraw` cannot see a change to `TileCache._bake`'s shipped clip
because the probe reimplements that geometry instead of calling it, so the
column read bit-identical under mutant M7 (which moved real triangle counts by
61%). Placed at the print site — where the next reader of that column's output
will be — rather than only in the class doc above it.

---

## Deferred minors left untouched (per instruction)

`draft_painter.dart`'s double `handleAt` on the bake path, `quantiseCamera`'s
identity-return being tested at dpr 2 only, and `_lastUsedFrame.entries`
allocating in `_makeRoomForOneTile` — all three triaged as standing, not
touched.

---

## Verification — both packages green

All commands prefixed `CI=true`, run from the package directory.

### `packages/jet_cad_2d`

```
$ CI=true dart test
...
00:02 +796: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:02 +797: test/invariants/query_allocation_test.dart: (tearDownAll)
00:02 +797: All tests passed!

$ CI=true dart analyze
Analyzing jet_cad_2d...
No issues found!

$ CI=true dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.15 seconds.
```

### `packages/jet_cad_2d_flutter`

```
$ CI=true flutter test
...
00:04 +362 ~1: .../test/vertices_differential_test.dart: the comparison is not vacuous
00:04 +363 ~1: All tests passed!
(363 tests, 1 skipped by design — the pre-existing `rig`-tagged microbench)

$ CI=true flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.0s)

$ CI=true dart format --output=none --set-exit-if-changed .
Formatted 63 files (0 changed) in 0.09 seconds.

$ CI=true flutter test --tags golden
...
00:01 +35: .../test/golden/text_ladder_golden_test.dart: (tearDownAll)
00:02 +35: All tests passed!
```

### Golden PNG diff — required empty

```
$ git diff --stat 82976ce -- packages/jet_cad_2d_flutter/test/golden
(empty)
```

No pre-existing golden PNG was regenerated.

---

## Files changed

```
 apps/dev_harness_2d/lib/measurement_rig.dart                                  | comment only (F7)
 docs/superpowers/notes/2026-08-24-plan-3g-results.md                          | note only (F5, F6)
 docs/superpowers/specs/2026-08-23-jet-cad-2d-plan-3g-tile-cache-design.md     | spec only (F1)
 packages/jet_cad_2d/lib/src/document/tables.dart                              | rename (F4) + comment (F3)
 packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart                         | comment only (F1)
 packages/jet_cad_2d_flutter/lib/src/tile_cache.dart                           | comment only (F1, F2)
```

No `analysis_options.yaml` or `apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`
changes were staged — `git status` was checked before every `git add`, and
neither file appeared in the working tree diff.

---

## F1 follow-up — two residues, finishing F1 rather than a new round

The coordinator's re-review of the first fix wave verdicted all seven findings
ADDRESSED but flagged two residues left inside F1's own scope.

### R1 — the excised sentence survived in `tile_comparison.dart`

`packages/jet_cad_2d_flutter/test/support/tile_comparison.dart:74-79`
(`measureTiledAgreement`'s doc) still said *"`DraftCanvas` quantises the
camera it hands the live path for exactly this reason"* — the same false
claim F1 had already removed from `tile_cache.dart`, `draft_canvas.dart` and
the spec. Worse, `tile_cache.dart`'s corrected text now cited
`tile_comparison.dart:81` as proof the instrument quantises itself, while the
neighbouring doc comment asserted the opposite.

Rewritten to say what the function does: this instrument quantises its own
live arm, deliberately, at the call directly below the comment; `DraftCanvas`
is not involved on this path at all, and `DraftCanvas` itself quantises only
inside its tiled branch, leaving its default path untouched.

### R2 — F1's own new citation pointed at the wrong span

`tile_cache.dart:168` cited `draft_canvas.dart:384-392` for the "asymmetry is
deliberate" reasoning. Lines 384-392 are the tail of the `TileCache.paintFrame`
call's arguments and the closing brace of that branch — not the explanation.
The reasoning paragraph (`"**The camera is not quantised here..."` through
`"...pixel for pixel."`) runs `392-402`. Corrected the citation to
`draft_canvas.dart:392-402`.

### Verification (second pass)

Same two files changed, both comment-only, no behaviour change:

```
 packages/jet_cad_2d_flutter/lib/src/tile_cache.dart          | comment only (R2)
 packages/jet_cad_2d_flutter/test/support/tile_comparison.dart | comment only (R1)
```

`packages/jet_cad_2d`: 797 tests pass, analyze clean, format clean (113 files,
0 changed).

`packages/jet_cad_2d_flutter`: 363 tests + 1 skip pass, analyze clean, format
clean (63 files, 0 changed), 35 golden tests pass.

```
$ git diff --stat 82976ce -- packages/jet_cad_2d_flutter/test/golden
(empty)
```

No `analysis_options.yaml` or `apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj`
changes staged; `git status` showed only the two files above before `git add`.
