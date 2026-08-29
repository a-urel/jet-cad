# Batch closure — five Minor review findings (Plan 3i, second minors pass)

Repo: `/Users/ahmeturel/Projects/oss/jet-cad`, started at `ec6fe18` on `main`.

## Finding 1 — test name overclaimed

`packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart:144`

Renamed the `testWidgets` name from `'the rest bake fires, and
debugRestBakeDisabled suppresses it'` to `'the rest bake fires: the unflagged
arm slices every visible tile'`, matching the file's `sibling test`'s naming
style (`'debugRestBakeDisabled slices nothing and still covers'`). No
assertion changed.

## Finding 2 — false doc-comment count on `debugLastStrip`

`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`, `debugLastStrip`'s doc
comment.

Verified by grep (`grep -n "^  bool debug\|^  int debug\|..." tile_cache.dart`)
that `TileCache` now carries four mutable test-only fields:
`debugOnSliceForTest`, `debugRestBakeDisabled`, `debugFullViewportQuery`,
`bakeBudgetDevicePixels` — matching the count `progress.md`'s own Task
12a/13a entry gives ("This task adds two more" on top of an original two).
Rewrote the sentence to state four, and added two sentences naming Ruling 14
(`.superpowers/sdd/2026-08-26-jet-cad-2d-plan-3i-zoom-frame/progress.md`) as
the revisit that happened: Tasks 12 and 13 each pin an interleaved
measurement, and interleaving two arms inside one session requires a runtime
switch because two binaries cannot interleave. Did not restate all of Ruling
14.

## Finding 3 — the M4-vs-M5 distinction held by nothing but source proximity

`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart:1140,1147` (pre-edit line
numbers; shifted after Finding 2/4's doc edits).

Added `debugLastClip` / `_lastClip`, mirroring `debugLastStrip` / `_lastStrip`
exactly: a private field reset to `null` at the top of `paintFrame` (beside
`_lastStrip = null`), written at the one production call site
(`canvas.clipRect(...)`), and exposed as a read-only getter with a doc
comment. Chose this mechanism — reading state out via a getter, no new way to
write it — because it is the file's own established precedent
(`debugLastStrip`'s doc comment names `tilesHolding` as the precedent it
follows), not a different one.

Added to `test/tile_measurement_seam_test.dart`:
- `_FallbackArm` now carries a fourth field, `clip` (`TileCache.debugLastClip`).
- `_fallbackArm` reads it off the rig and threads it through the constructor.
- The `'debugFullViewportQuery grows the fallback walk to the whole viewport'`
  test now asserts, under the M4 arm: `m4.clip` is not null, `m4.clip` equals
  `narrow.clip` (the clip does not move when the flag is set), and `m4.clip`
  is *not* equal to `m4.strip` (the clip stays narrower than the widened
  query — the M4/M5 distinction itself).

### M16 — proving the new assertion is not vacuous

Mutation: in `paintFrame`, changed
```dart
canvas.clipRect(uncovered, doAntiAlias: false);
_lastClip = uncovered;
```
to
```dart
final clip = debugFullViewportQuery ? Offset.zero & viewport : uncovered;
canvas.clipRect(clip, doAntiAlias: false);
_lastClip = clip;
```
— widening the clip under the flag, which is exactly the "M4 that is neither
M4 nor M5" state Finding 3 exists to refuse.

Procedure: `cp` `tile_cache.dart` to
`/private/tmp/.../scratchpad/tile_cache_m16.bak`, edited the working file, ran
the test, confirmed red, restored with `cp` from the backup, confirmed `diff`
against the backup was empty, re-ran, confirmed green.

**RED transcript (real, produced by this run):**
```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
00:00 +0: the rest bake fires: the unflagged arm slices every visible tile
00:00 +1: debugRestBakeDisabled slices nothing and still covers
00:00 +2: debugFullViewportQuery grows the fallback walk to the whole viewport
00:00 +2 -1: debugFullViewportQuery grows the fallback walk to the whole viewport [E]
  Expected: Rect:<Rect.fromLTRB(0.0, -11.0, 416.0, 53.0)>
    Actual: Rect:<Rect.fromLTRB(0.0, 0.0, 400.0, 300.0)>
  the clip must not move when the flag is set -- only the query does: narrow=_FallbackArm(strip: Rect.fromLTRB(0.0, 0.0, 400.0, 85.0), clip: Rect.fromLTRB(0.0, -11.0, 416.0, 53.0), triangles: 60, liveDraws: 1) m4=_FallbackArm(strip: Rect.fromLTRB(0.0, 0.0, 400.0, 300.0), clip: Rect.fromLTRB(0.0, 0.0, 400.0, 300.0), triangles: 80, liveDraws: 1)

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_measurement_seam_test.dart 229:5          main.<fn>

00:00 +2 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
```

**Restore verified:** `cp` from the scratchpad backup, `diff` against it —
empty output — then re-ran.

**GREEN transcript (real, produced by this run):**
```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
00:00 +0: the rest bake fires: the unflagged arm slices every visible tile
00:00 +1: debugRestBakeDisabled slices nothing and still covers
00:00 +2: debugFullViewportQuery grows the fallback walk to the whole viewport
00:00 +3: All tests passed!
```

Added an `M16` section to `docs/superpowers/notes/plan-3i-mutation-log.md`,
matching the M14/M15 format (Task, Why this mutant, Mutation diff, Procedure,
Result with both arms' clip values, verbatim red transcript, verbatim restore
+ green transcript).

## Finding 4 — flag is behaviourally equivalent to 3h's M4, not byte-identical

`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`, `debugFullViewportQuery`'s
doc comment.

Added one paragraph, no code change: states that 3h's M4 kept `_lastStrip`
narrow and dropped `canvas.translate` outright, while this flag routes the
full viewport through `_lastStrip` and leaves `canvas.translate(strip.left,
strip.top)` in place as `translate(0, 0)` — numerically inert (`q.e - 0.0` is
exact) and every measured quantity is equivalent, but a `debugLastStrip`
reading from this flag's M4 arm cannot be cross-read against Plan 3h's log.

## Finding 5 — whose M4?

`docs/superpowers/notes/plan-3i-mutation-log.md`.

Added a short, clearly marked note block near the top of the file (above the
existing M2/M6/M6b canvas-size note), stating that mutant numbering is
per-plan, that this file's own `M4`/`M5` name different mutations from Plan
3h's `M4`/`M5`, and that any citation must name the plan. Did not restructure
the file otherwise.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`
- `packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart`
- `docs/superpowers/notes/plan-3i-mutation-log.md`

`analysis_options.yaml` was never staged or touched. No golden PNGs were
regenerated (none of this touches paint output comparisons).

## Gate — real transcripts

### `packages/jet_cad_2d_flutter`

```
$ CI=true flutter test
...
00:06 +405 ~1: All tests passed!
```
(matches baseline 405 with 1 skip, exactly — no test count change; Finding 3
only added assertions inside an existing test.)

```
$ CI=true flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.3s)
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 73 files (0 changed) in 0.13 seconds.
```
(exit 0)

### `apps/dev_harness_2d`

```
$ CI=true flutter test --concurrency=1
...
00:14 +23: All tests passed!
```
(matches baseline 23, exactly — this batch touched nothing under
`apps/dev_harness_2d`.)

```
$ CI=true flutter analyze
Analyzing dev_harness_2d...
No issues found! (ran in 1.5s)
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 9 files (0 changed) in 0.07 seconds.
```
(exit 0)

### `packages/jet_cad_2d`

```
$ CI=true dart test
...
00:03 +797: All tests passed!
```
(matches baseline 797, exactly — untouched, as required: this package is pure
Dart and none of the five findings live there.)

```
$ CI=true dart analyze
Analyzing jet_cad_2d...
No issues found!
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 113 files (0 changed) in 0.20 seconds.
```
(exit 0)

## Working tree at the end

```
$ git status --porcelain
 M docs/superpowers/notes/plan-3i-mutation-log.md
 M packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
 M packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart
```

Only the three intended paths changed; `analysis_options.yaml` untouched in
all three packages.

## Commit

Staged and committed the three named paths (no `git add -A`). See git log for
the commit SHA.
