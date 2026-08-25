# Task 8a report — the machine-independent half of Task 8

Per controller amendment 2 ("this dispatch is Task 8a only"), this task did
**not** attempt or wait for any `flutter drive` device run, did **not**
create `docs/superpowers/notes/2026-08-25-plan-3h-results.md`, and did
**not** write a `STATUS.md` section claiming Plan 3h is closed. Plan 3h
remains open (M4 unfired, the results note absent, the exit-gate section
absent, the `Verified against` line unchanged) — all of that is Task 8b's.

## What was done

1. Wrote `docs/superpowers/notes/plan-3h-mutation-log.md` with sections for
   M1, M2, M3, M5 (full record) and M4 (placeholder, no result — explicitly
   states it is a device mutant, not yet fired, and that Task 8b fills it
   in). M3's section records the fuller kill (criterion 2b also reddens,
   `differing: 417` against a bound of 60). M2's section records gap H5 with
   the measured zeros and the D2/F1 provenance sentence verbatim per the
   brief. A "Deferred minors" section records the triangle gate's 4-triangle
   headroom, `checkTriangleBudget`'s unsafe default, and Task 3's
   undocumented per-offset table. A closing section lists the two figures
   that came from the ledger (`progress.md`) rather than from
   `task-4-report.md`/`task-5-report.md`, since those two files did not
   carry them.
2. Made Task 1's `STATUS.md` renumbering (controller amendment 1, item 1) —
   see the exact diff below.
3. Ran every suite in the brief's Step 2 on the current tree, fresh (not
   read off any report). All results below.

## git status --porcelain before staging

Before any edits (start of this task):

```
(clean)
```

After edits, before staging:

```
 M STATUS.md
?? docs/superpowers/notes/plan-3h-mutation-log.md
```

No `analysis_options.yaml`, no `.png`, and no
`apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj` appeared at any
point — `flutter analyze` in this session triggered a workspace `pub get`
(visible in the transcripts below) but did not dirty any of those three.

## Suite 1 — `packages/jet_cad_2d` (pure Dart engine)

### `CI=true dart test`

Tail of transcript:

```
00:02 +783: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
...
00:03 +796: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +797: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +797: All tests passed!
```

**797 tests passed, 0 failed, 0 skipped.**

### `dart analyze`

```
Analyzing jet_cad_2d...
No issues found!
```

Exit code 0.

### `dart format --output=none --set-exit-if-changed .`

```
Formatted 113 files (0 changed) in 0.20 seconds.
```

Exit code 0.

## Suite 2 — `packages/jet_cad_2d_flutter` (Flutter render layer)

### `CI=true flutter test`

Tail of transcript:

```
00:05 +371 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the comparison is not vacuous
00:06 +372 ~1: All tests passed!
```

**372 tests passed, 1 skipped** (the pre-existing `rig`-tagged skip,
`test/rig/paint_microbench_test.dart`, per `dart_test.yaml` — run explicitly
with `--tags rig --run-skipped`), **0 failed.**

### `CI=true flutter test --tags golden`

Tail of transcript:

```
00:01 +34: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.vertices)
00:01 +35: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: (tearDownAll)
00:04 +35: All tests passed!
```

**35 golden tests passed, 0 failed.** `git status --porcelain` showed no
`.png` modified before or after this run.

### `flutter analyze`

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
```

Exit code 0. (This invocation triggered a workspace `flutter pub get`,
visible as "Resolving dependencies..." / "Got dependencies..." in the raw
output — no tracked file changed as a result; `git status --porcelain`
confirmed no `analysis_options.yaml` appeared.)

### `dart format --output=none --set-exit-if-changed .`

```
Formatted 65 files (0 changed) in 0.12 seconds.
```

Exit code 0.

## Suite 3 — `apps/dev_harness_2d` (analyze and format only)

### `flutter analyze`

```
Analyzing dev_harness_2d...
No issues found! (ran in 2.1s)
```

Exit code 0.

### `dart format --output=none --set-exit-if-changed .`

```
Formatted 4 files (0 changed) in 0.06 seconds.
```

Exit code 0.

## Summary of counts

| Suite | Result |
|---|---|
| `jet_cad_2d` — `dart test` | **797 passed**, 0 failed, 0 skipped |
| `jet_cad_2d` — analyze/format | clean |
| `jet_cad_2d_flutter` — `flutter test` | **372 passed, 1 skipped**, 0 failed |
| `jet_cad_2d_flutter` — `flutter test --tags golden` | **35 passed**, 0 failed, no PNG regenerated |
| `jet_cad_2d_flutter` — analyze/format | clean |
| `dev_harness_2d` — analyze/format | clean |

No regressions and no unexpected skips relative to what the two source task
reports (and the existing `STATUS.md` table) already recorded for this tree.

## Exact `STATUS.md` edits

Two edits, both in the `## Resume here` section (this is Task 1's orphaned
renumbering, controller amendment 1 item 1 — Task 1 was blocked at its first
step by Low Power Mode and produced no commit, so this had never been made).

**Edit 1 — inserted a renumbering note immediately before "What 3h starts
from":**

```diff
+**Renumbered 2026-08-25.** This section originally read G3 and the vertex
+buffer as Plan 3h's own starting points. They are not. **Plan 3h is the
+fallback walk and its instrument, nothing else** — item 1 below. Plan 3g
+assigned G3 to 3h; **G3 now belongs to Plan 3i** (item 2), and the 192 MiB
+vertex buffer is **Plan 3j**'s question (item 3), not 3h's. The reassignment
+is licensed by item 3's own finding: the 2026-08-25 high-water measurement
+showed memory is not a consequence of the pan frame, so the pan frame could
+be finished without settling zoom first.
+
 **What 3h starts from**, in the order the results note argues it:
```

**Edit 2 — the three-item list itself, reworded to name the new owners
without rewriting the underlying measurements:**

```diff
 1. **Criterion 11's miss, cause isolated, remedy spent.** 35.67 ms against
    16.67, reproduced three times, and the bake is under a fifth of it. The
    excess is the **live fallback drawing the still-uncovered strip**. The
    budget is already floored at one tile, so lowering it leaves the strip
    uncovered for more frames, each paying the fallback again. **A pan frame
-   that exposes more than one tile has no covered path today.**
-2. **G3, the zoom, with a number on it.** 32.06 ms at 500,000 entities with
-   tiles on. **No caching scheme touches it** — the triangles are genuinely
-   being drawn — so the answer is level-of-detail geometry, and the tile cache
-   can already hold it: a generation is keyed by scale, so a coarser bake can
-   never outlive the scale it was simplified for.
+   that exposes more than one tile has no covered path today.** This, and
+   only this, is Plan 3h's scope.
+2. **G3, the zoom, with a number on it — now Plan 3i's.** 32.06 ms at
+   500,000 entities with tiles on. **No caching scheme touches it** — the
+   triangles are genuinely being drawn — so the answer is level-of-detail
+   geometry, and the tile cache can already hold it: a generation is keyed by
+   scale, so a coarser bake can never outlive the scale it was simplified for.
 3. **The memory measurement, taken 2026-08-25 — and the answer is no.**
    `debugCapacityVertices` reads **16,777,216 vertices, 192.00 MiB, in all five
    configurations measured**: 50,000 and 500,000 entities, tiles on and off.
    **Tiles change nothing, so the tile budget adds to that memory rather than
-   replacing it** — 3h budgets 192 + tiles. **And the mark is not a function of
-   entity count**, ...
+   replacing it** — the 192 MiB figure and the tile budget it must add to are
+   **Plan 3j**'s starting point. **And the mark is not a function of
+   entity count**, ...
```

Nothing else in `STATUS.md` was touched. In particular, per amendment 2's
explicit exclusions: the `Verified against` line at the top of the file
still names `1b7ea04`, and no exit-gate section quoting criteria 3/3b was
added — both are Task 8b's.

## Figures needed but not found in `task-4-report.md` / `task-5-report.md`

Two figures used in the mutation log were not present in either named
source report; both are recorded instead in this plan's own ledger
(`.superpowers/sdd/2026-08-25-jet-cad-2d-plan-3h-pan-frame/progress.md`) and
restated in `task-8-brief.md`'s controller amendment 1, which is where this
task took them from rather than inventing them:

1. **M3's criterion 2b figure**, `differing: 417` against a bound of 60.
   `task-5-report.md`'s M3 section only reports criteria 2 and 2c
   (`uncoveredPixels: 1642`); the 2b figure is in `progress.md` line 89
   ("Task 5: out of scope, carry to Task 8: under M3, criterion 2b also
   reddens (`differing: 417` against a bound of 60)...").
2. **M5's first-fired result**, `+372 ~1` all-green against the whole
   package, from before the triangle-budget gate existed. `task-5-report.md`
   documents M5 only from the point the gate already existed ("Fix round
   1"); the original discovery run is in `progress.md` line 79 ("...the
   whole package stayed green at `+372 ~1`.").

Both are flagged explicitly in the mutation log's own closing section
("Figures not independently reproduced by Task 8a") rather than presented as
if reproduced by Task 8a.

## Status

DONE, scoped exactly to Task 8a. M4 is an intentionally empty section. The
results note, the Plan 3h exit-gate section, and the `Verified against` line
are untouched and remain Task 8b's.

---

# Fix round 1

## The finding

Reviewer's Important finding on commit `b7ff8f5`: unlike M1's and M2's
sections, M3's section in the mutation log never stated whether the full
widget suite (`flutter test`, `analyze`, `format`) was run under that
mutant — only the targeted `criterion 2 and 2c` command and a re-fire note.
The brief requires every section to state which suites were actually run
under it, precisely because Plan 3g's costliest error was inferring
suite-wide behavior without running it.

## What was done, in order

1. `cp /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/lib/src/tile_cache.dart /tmp/tile_cache.m3_fixround1`
2. Applied M3 to the current tree: `kTileSlack` → `-20.0` at all four call
   sites inside `stripFor` (lines 116–119).
3. Ran `CI=true flutter test` (whole package) from
   `packages/jet_cad_2d_flutter`.
4. Ran `flutter analyze` and `dart format --output=none --set-exit-if-changed .`
   under the same mutant, before restoring.
5. Restored `lib/src/tile_cache.dart` from the `/tmp` copy (never `git
   checkout`), confirmed `diff` against the pre-mutation copy produced no
   output, confirmed `git status --porcelain` was clean, and re-ran
   `CI=true flutter test` to confirm the suite returned to green.
6. Amended the mutation log's M3 section (and its closing "Figures" section,
   for internal consistency) with everything below.

## Verbatim whole-suite output under M3

Command: `CI=true flutter test` (from `packages/jet_cad_2d_flutter`, whole
package, not one file).

Final summary line:

```
00:07 +365 ~1 -7: Some tests failed.
```

**365 passed, 1 skipped, 7 failed** — against the baseline's 372 passed / 1
skipped / 0 failed (373 total both times; exactly 7 of the 373 flip from
pass to fail under this mutant).

**All seven failures, each confirmed from its own `[E]` block in the
transcript** (the reporter's own "Failing tests:" summary truncates to
"...and 3 more"; all seven are named here from the transcript directly):

1. `test/invariants/tile_budget_test.dart`: *criterion 12: a frame at the cap
   still equals the live frame*
   ```
   Expected: <0>
     Actual: <1000>
   InkReport(live: 19860, tiled: 18860, stray: 0, uncovered: 1000, differing: 1000, liveTri: 40, tiledTri: 36)
   ```
   **New relative to every prior record of M3** — not mentioned in
   `task-5-report.md` or the ledger's M3 entries.
2. `test/tile_cache_test.dart`: *stripFor pads an interior rect on every
   side*
   ```
   Expected: Rect:<Rect.fromLTRB(68.0, 48.0, 232.0, 212.0)>
     Actual: Rect:<Rect.fromLTRB(120.0, 100.0, 180.0, 160.0)>
   ```
   This is the one `stripFor` case M1 (drop the clamp) could **not** redden;
   M3 reddens it because it replaces the pad's *value*, not just its clamp.
3. `test/tile_cache_test.dart`: *stripFor clamps to the viewport rather than
   growing past it*
   ```
   Expected: Rect:<Rect.fromLTRB(0.0, 0.0, 400.0, 300.0)>
     Actual: Rect:<Rect.fromLTRB(20.0, 20.0, 380.0, 280.0)>
   ```
4. `test/tile_cache_test.dart`: *stripFor clamps one edge at a time*
   ```
   Expected: Rect:<Rect.fromLTRB(0.0, 0.0, 72.0, 300.0)>
     Actual: Rect:<Rect.fromLTRB(20.0, 20.0, 20.0, 280.0)>
   ```
5. `test/tile_cache_test.dart`: *stripFor a strip touching the bottom-right
   clamps there and pads inward*
   ```
   Expected: Rect:<Rect.fromLTRB(328.0, 228.0, 400.0, 300.0)>
     Actual: Rect:<Rect.fromLTRB(380.0, 280.0, 380.0, 280.0)>
   ```
6. `test/tile_fallback_test.dart`: *criterion 2 and 2c: a partly baked frame
   equals the live frame*
   ```
   Expected: <0>
     Actual: <1642>
   Offset(37.0, 0.0): InkReport(live: 38886, tiled: 37244, stray: 0, uncovered: 1642, differing: 1642, liveTri: 60, tiledTri: 10)
   ```
   Digit-identical to every prior firing of M3 at this offset.
7. `test/tile_fallback_test.dart`: *criterion 2b: the near-axis arm stays
   inside the tiled path's bound*
   ```
   Expected: a value less than or equal to <60>
     Actual: <417>
   Offset(37.0, 0.0): InkReport(live: 10703, tiled: 10344, stray: 29, uncovered: 388, differing: 417, liveTri: 20, tiledTri: 0)
   ```
   **This independently reproduces, digit-identical, the `differing: 417`
   figure previously known only from the ledger and the brief.** Both
   expectations named in the coordinator's message came true: criterion 2/2c
   and criterion 2b both failed, and more besides (all four `stripFor` unit
   cases plus `tile_budget_test.dart`'s criterion 12) — a fuller kill than
   even the amended plan text claimed.

## `flutter analyze` and `dart format` under M3

Run, not assumed:

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)
```

```
Formatted 65 files (0 changed) in 0.12 seconds.
```

Both clean — M3 is a value change with no structural effect visible to
either tool, confirmed rather than reasoned.

## Restore, verified

```
$ diff /tmp/tile_cache.m3_fixround1 lib/src/tile_cache.dart
(no output)
$ git status --porcelain
(clean)
```

Re-ran `CI=true flutter test`:

```
00:06 +372 ~1: All tests passed!
```

Exactly the pre-mutation baseline: 372 passed, 1 skipped, 0 failed.

## Mutation log amendments

`docs/superpowers/notes/plan-3h-mutation-log.md`, M3 section:

- "Layer fired in" now names all three firings (targeted, targeted-again
  under the fix-round-1 triangle gate, and this whole-suite firing) and
  states the analyze/format commands explicitly, matching M1's and M2's
  style.
- Added a new subsection, "Full widget suite under M3 (Task 8a, fix round 1,
  today's tree)", carrying the command, the final summary line, all seven
  named failures with their verbatim `[E]` blocks, the analyze/format
  results, and the restore confirmation.
- Made explicit that this subsection is a property of **today's tree**,
  reproduced directly by this task — not a historical record like M5's
  first-fired green result, which cannot be reproduced now that the
  triangle-budget gate exists.
- Updated the log's closing "Figures not independently reproduced by Task
  8a" section: M3's `differing: 417` figure is now recorded as independently
  reproduced (digit-identical) by this fix round; M5's first-fired figure
  remains not reproducible today, with the reason stated (the gate now
  exists, so re-firing M5 reddens rather than reproduces the historical
  green).

Nothing else in the mutation log changed. `STATUS.md` was not touched, no
results note was created, and M4's placeholder was not filled.

## git status --porcelain before staging

```
 M docs/superpowers/notes/plan-3h-mutation-log.md
```

No `analysis_options.yaml`, no `.png`, no `.pbxproj` present. Only the
mutation log was staged and committed.

## Status

DONE. The reviewer's one Important finding is closed with a direct
reproduction, not an inferred sentence — M3's section now meets the same
suite-scope bar as M1's and M2's.
