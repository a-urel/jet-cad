# Task 5 report: The narrowing

## Final text of the fallback branch (after edit)

From `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart`, `paintFrame`'s
fallback branch, verbatim as it stands after the edit (and as committed):

```dart
    canvas.save();
    // **The clip is unchanged, and that is a decision.** `_bake` states the
    // rule for itself -- "The query is padded; the clip is not." Drop this
    // line and the pad becomes overdraw onto tiles already blitted: the pixels
    // stay correct, so the sweep still reads zero, and the cost this whole
    // change exists to remove comes back silently.
    canvas.clipRect(uncovered, doAntiAlias: false);
    // **Walk the union, not the viewport.** The clip above only discards
    // drawing; the walk below is what costs. `DraftPainter.paint` derives its
    // index query from `camera.visibleWorld(viewport)`, so handing it the full
    // viewport tessellates the whole frame and throws most of it away -- which
    // is what every fallback did before this line, and why the frame's excess
    // read as a full live walk.
    final strip = stripFor(uncovered, viewport);
    _lastStrip = strip;
    canvas.translate(strip.left, strip.top);
    final q = quantised.worldToScreenMatrix;
    _drawInto(
        canvas,
        Size(strip.width, strip.height),
        ViewportTransform(
            worldToScreenMatrix: Transform2(
                q.a, q.b, q.c, q.d, q.e - strip.left, q.f - strip.top)),
        painter,
        sink,
        vertices,
        origin,
        null);
    canvas.restore();
    _liveDraws++;
  }
```

This matches the brief's "with" block verbatim, applying the controller
amendment: the prior single line `_lastStrip = stripFor(uncovered, viewport);`
is replaced by `final strip = stripFor(uncovered, viewport);` followed by
`_lastStrip = strip;` — no duplicate `stripFor` call remains.

Also amended, `debugLastStrip`'s doc comment (rest of the doc comment
unchanged):

```dart
  /// The rectangle the fallback walked on the most recent frame, or `null` if
  /// no fallback ran. Test-only, and **read-only**.
```

## Step 2 — sweep must stay green

Command: `CI=true flutter test test/tile_fallback_test.dart`

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
00:00 +0: criterion 2 and 2c: a partly baked frame equals the live frame
00:00 +1: criterion 2b: the near-axis arm stays inside the tiled path's bound
00:00 +2: All tests passed!
```

Both tests pass. Criterion 2 (fillingGrid sweep) and criterion 2b (nearAxisDiagonals,
bounded at 60 differing pixels) both green — the narrowing did not move a pixel.
No G5-adjacent bound issue observed.

## Step 3 — mutant M3 (kTileSlack -> -20.0, all four call sites in `stripFor`)

`cp lib/src/tile_cache.dart /tmp/tile_cache.m3` was run first.

Mutated `stripFor` body:

```dart
Rect stripFor(Rect uncovered, Size viewport) => Rect.fromLTRB(
      math.max(0.0, uncovered.left - -20.0),
      math.max(0.0, uncovered.top - -20.0),
      math.min(viewport.width, uncovered.right + -20.0),
      math.min(viewport.height, uncovered.bottom + -20.0),
    );
```

Command: `CI=true flutter test test/tile_fallback_test.dart --plain-name "criterion 2 and 2c"`

RED, exact transcript:

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
00:00 +0: criterion 2 and 2c: a partly baked frame equals the live frame
00:00 +0 -1: criterion 2 and 2c: a partly baked frame equals the live frame [E]
  Expected: <0>
    Actual: <1642>
  Offset(37.0, 0.0): InkReport(live: 38886, tiled: 37244, stray: 0, uncovered: 1642, differing: 1642)
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_fallback_test.dart 52:7                   main.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart: criterion 2 and 2c: a partly baked frame equals the live frame
```

`uncoveredPixels: 1642` (non-zero), failing at the first offset `Offset(37.0, 0.0)`
before the sweep continued to the rest — RED as required. Criterion 1 (the
mutation gate) passes: a shrunk query is caught.

Restored: `cp /tmp/tile_cache.m3 lib/src/tile_cache.dart`, verified byte-identical
with `diff` (no output, `RESTORED_OK` printed).

Confirm green: `CI=true flutter test test/tile_fallback_test.dart`

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
00:00 +0: criterion 2 and 2c: a partly baked frame equals the live frame
00:00 +1: criterion 2b: the near-axis arm stays inside the tiled path's bound
00:00 +2: All tests passed!
```

## Step 4 — mutant M2 (kTileSlack -> 0.0, all four call sites in `stripFor`)

`cp lib/src/tile_cache.dart /tmp/tile_cache.m2` was run first.

Mutated `stripFor` body:

```dart
Rect stripFor(Rect uncovered, Size viewport) => Rect.fromLTRB(
      math.max(0.0, uncovered.left - 0.0),
      math.max(0.0, uncovered.top - 0.0),
      math.min(viewport.width, uncovered.right + 0.0),
      math.min(viewport.height, uncovered.bottom + 0.0),
    );
```

Command: `CI=true flutter test test/tile_fallback_test.dart --plain-name "criterion 2 and 2c"`

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
00:00 +0: criterion 2 and 2c: a partly baked frame equals the live frame
00:00 +1: All tests passed!
```

**Outcome: GREEN. M2 survives.** This is the spec's anticipated gap **H5**, not
a failure of this task, per the brief's pre-commitment. Per the brief's own
warning ("Do not invent a fixture to force a kill"), no fixture change was made.

### H5 record — measured zeros

To see the actual `InkReport` values behind the passing assertions (the test
only prints on failure), the checked-in `test/tile_fallback_test.dart` was
temporarily edited in place to add a debug `print` of each report right after
`sweepFallbackAgreement` returned, for this measurement only, and reverted
immediately afterward (confirmed byte-identical to the pre-edit copy via
`diff` against `/tmp/tile_fallback_test.dart.orig` — no output). This temporary
instrumentation is not part of the commit; `git status --porcelain` before
staging (below) shows only `tile_cache.dart` modified.

Command run with instrumentation and mutant M2 in place:
`CI=true flutter test test/tile_fallback_test.dart --plain-name "criterion 2 and 2c"`

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
00:00 +0: criterion 2 and 2c: a partly baked frame equals the live frame
TEMP-DEBUG Offset(37.0, 0.0): InkReport(live: 38886, tiled: 38886, stray: 0, uncovered: 0, differing: 0)
TEMP-DEBUG Offset(53.0, 0.0): InkReport(live: 36906, tiled: 36906, stray: 0, uncovered: 0, differing: 0)
TEMP-DEBUG Offset(71.0, 0.0): InkReport(live: 35970, tiled: 35970, stray: 0, uncovered: 0, differing: 0)
TEMP-DEBUG Offset(0.0, 37.0): InkReport(live: 38208, tiled: 38208, stray: 0, uncovered: 0, differing: 0)
TEMP-DEBUG Offset(0.0, 53.0): InkReport(live: 37056, tiled: 37056, stray: 0, uncovered: 0, differing: 0)
TEMP-DEBUG Offset(0.0, 71.0): InkReport(live: 34232, tiled: 34232, stray: 0, uncovered: 0, differing: 0)
TEMP-DEBUG Offset(-41.0, 0.0): InkReport(live: 37608, tiled: 37608, stray: 0, uncovered: 0, differing: 0)
TEMP-DEBUG Offset(0.0, -41.0): InkReport(live: 37668, tiled: 37668, stray: 0, uncovered: 0, differing: 0)
00:00 +1: All tests passed!
```

`stray`, `uncovered`, and `differing` are `0` at every one of the eight swept
offsets on the `fillingGrid` fixture, with `live` and `tiled` ink counts equal
at each offset.

At `pad = 0` on `fillingGrid`, every offset agrees exactly with the tiled path:
`strayPixels`, `uncoveredPixels`, and `differingPixels` are all `0` across all
eight swept offsets. This is consistent with the brief's characterisation of
H5: dropping the pad only loses entities whose half stroke width bleeds into
the strip from just outside it, and `fillingGrid` at these offsets does not
happen to exercise that geometry (matching the brief's note that Plan 3g's F1
appeared at only six of forty-one swept zoom factors on a differently
constructed fixture). No fixture was invented to force a kill, per instruction.

Restored: `cp /tmp/tile_cache.m2 lib/src/tile_cache.dart`, verified byte-identical
with `diff` (`TILE_CACHE_RESTORED_OK`). Test file restored from
`/tmp/tile_fallback_test.dart.orig`, verified byte-identical with `diff`
(`TEST_FILE_RESTORED_OK`).

Confirm green (test file and tile_cache.dart both restored):
`CI=true flutter test test/tile_fallback_test.dart`

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
00:00 +0: criterion 2 and 2c: a partly baked frame equals the live frame
00:00 +1: criterion 2b: the near-axis arm stays inside the tiled path's bound
00:00 +2: All tests passed!
```

Additionally verified the restored `lib/src/tile_cache.dart` is byte-identical
to the post-Step-1-edit baseline captured in `/tmp/tile_cache.m3`
(`diff /tmp/tile_cache.m3 lib/src/tile_cache.dart` — no output,
`MATCHES_M3_BASELINE_OK`), so both mutant restorations converge to the same
edited file that was ultimately committed.

## Step 5 — full suite, analyze, format

Command: `CI=true flutter test`

Tail of transcript:

```
00:06 +368 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillPolygon closes the path
00:06 +369 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillPolygon with fewer than 3 points draws nothing
00:06 +370 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillCircle draws a filled circle
00:06 +371 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillCircle leaves the paint on stroke afterwards
00:06 +372 ~1: All tests passed!
```

372 passed, 1 skipped (`~1`), "All tests passed!" — no new failures, no new
skips beyond the pre-existing one.

Command: `flutter analyze`

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.1s)
```

Command: `dart format --output=none --set-exit-if-changed .`

```
Formatted 65 files (0 changed) in 0.13 seconds.
```

## `git status --porcelain` before staging

```
 M packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
```

Only `tile_cache.dart` was modified; `test/tile_fallback_test.dart` was left
exactly as it was (the temporary debug print used for the H5 measurement was
reverted before this check), matching the amendment's instruction that Step 6
stages the test file as a no-op.

## Step 6 — commit

Staged: `lib/src/tile_cache.dart` and `test/tile_fallback_test.dart` (the
latter a no-op add, per the amendment).

Commit message used verbatim from the brief:

```
perf: the live fallback walks the uncovered strip, not the viewport

paintFrame clipped to the uncovered union and handed DraftPainter the whole
viewport, and the painter derives its index query from exactly that, so every
fallback tessellated the entire frame and the clip discarded most of it.

The clip is deliberately unchanged: _bake states the rule at its own call site,
and dropping it turns the pad into overdraw onto tiles already blitted, which
the sweep reads as zero because the pixels stay correct.

M3 -- a query shrunk 20 logical pixels -- reddens the sweep, which is what
makes every other pixel claim here mean anything.
```

Result: `[main 853c65a] perf: the live fallback walks the uncovered strip, not the viewport`
— 1 file changed, 27 insertions(+), 5 deletions(-).

## Predictions verified, not assumed

Per the task instructions' warning that two of three carried-forward
predictions in this plan turned out false: both of this task's own
predictions from the brief were checked against real output rather than
assumed —

- The brief predicted M3 would go RED with non-zero `uncoveredPixels`: verified,
  `1642`.
- The brief pre-committed to *either* outcome for M2; the actual outcome
  (GREEN / survives, H5) was determined by running the mutant, not assumed
  in advance, and the "measured zeros" were captured with real instrumented
  output rather than asserted from the brief's prose.

## Status

DONE. Step 2's sweep stayed green before any mutation. M3 (criterion 1) reddened
as required, confirming the sweep measures something real. M2 (criterion 1b)
survived — outcome GREEN, recorded as gap **H5** with measured zeros above, per
the brief's pre-committed acceptable outcome. Full suite, analyze, and format
are all green with no change in pass/skip counts. Commit `853c65a` on `main`.

---

## Fix round 1

### The finding (M5) and the ruling

The reviewer found that the sweep is one-sided: it catches a fallback query
*shrunk* (M3) but not one *grown* back to the full viewport, because
`Size(strip.width, strip.height)` and the translate/camera-offset arguments
in `_drawInto`'s call are independent, and the clip absorbs any excess drawn
by a too-large query. The coordinator's ruling: build the gate on
`VerticesDrawSink.frameTriangleCount`, captured per arm in
`measureTiledAgreement` and carried on `InkReport`, and assert the tiled
arm's triangle count is materially below the live arm's.

### What changed

`lib/src/tile_cache.dart` is **untouched** in this fix round (verified
byte-identical to the pre-fix-round file via `diff` — no output). Both
changed files are test-only:

- `packages/jet_cad_2d_flutter/test/support/tile_comparison.dart` —
  `InkReport` gained `liveTriangleCount` and `tiledTriangleCount` (its one
  construction site, inside `measureTiledAgreement`, resets
  `rig.vertices.resetCounters()` before each arm and reads
  `rig.vertices.frameTriangleCount` right after capturing that arm).
  `measureFallbackAgreement` and `sweepFallbackAgreement` gained an opt-in
  `checkTriangleBudget` parameter (default `false`) that, when `true`, asserts
  `report.tiledTriangleCount < report.liveTriangleCount * kTriangleBudgetRatio`
  with `kTriangleBudgetRatio = 0.9`.
- `packages/jet_cad_2d_flutter/test/tile_fallback_test.dart` — the
  `criterion 2 and 2c` sweep now passes `checkTriangleBudget: true`; the
  `criterion 2b` sweep does not (see the finding below on why).

### Why the check is opt-in, not blanket in `measureFallbackAgreement`

Before writing the final bound I measured both fixtures with temporary debug
`print`s of every `InkReport` (added, used, then reverted — verified restored
byte-identical to the pre-measurement copy each time). This surfaced a real
problem with an unconditional check: on `nearAxisDiagonals` (the `criterion
2b` fixture), the correct, un-mutated implementation already produces a
tiled/live triangle ratio of exactly `1.0` at three of the eight swept
offsets, and `0/20` at the other five. That fixture is a handful of long
diagonals spanning most of the viewport, so a strip-sized query and a
full-viewport query catch the *same* entities regardless of query size — the
ratio carries no signal there, and applying any `ratio < 1.0` bound to it
would fail correct code, not catch a mutant. I did not force a kill on that
fixture; the check is scoped to `fillingGrid`/`criterion 2 and 2c`, where the
per-offset per-entity contents do vary with query size, with the reasoning
recorded in `kTriangleBudgetRatio`'s doc comment and at both call sites.

### Per-offset live/tiled triangle counts — `fillingGrid` (`criterion 2 and 2c`), correct code

Captured via a temporary debug print in the test (reverted before the real
commit); command: `CI=true flutter test test/tile_fallback_test.dart --plain-name "criterion 2 and 2c"`.

| Offset | liveTri | tiledTri | ratio |
|---|---|---|---|
| (37, 0) | 60 | 40 | 0.667 |
| (53, 0) | 58 | 40 | 0.690 |
| (71, 0) | 58 | 30 | 0.517 |
| (0, 37) | 60 | 50 | 0.833 |
| (0, 53) | 60 | 50 | 0.833 |
| (0, 71) | 58 | 40 | 0.690 |
| (-41, 0) | 58 | 38 | 0.655 |
| (0, -41) | 60 | 48 | 0.800 |

Max observed ratio under correct code: **0.833**. Verbatim output line for
the first offset: `InkReport(live: 38886, tiled: 38886, stray: 0, uncovered:
0, differing: 0, liveTri: 60, tiledTri: 40)`.

### Per-offset live/tiled triangle counts — `nearAxisDiagonals` (`criterion 2b`), correct code

| Offset | liveTri | tiledTri | ratio |
|---|---|---|---|
| (37, 0) | 20 | 20 | 1.0 |
| (53, 0) | 20 | 20 | 1.0 |
| (71, 0) | 20 | 20 | 1.0 |
| (0, 37) | 20 | 0 | 0.0 |
| (0, 53) | 20 | 0 | 0.0 |
| (0, 71) | 20 | 0 | 0.0 |
| (-41, 0) | 20 | 0 | 0.0 |
| (0, -41) | 20 | 0 | 0.0 |

This is the direct evidence behind scoping `checkTriangleBudget` to
`fillingGrid` only: three of eight offsets sit at ratio `1.0` under correct
code, which any sub-1.0 bound would reject.

### Ratio chosen and why

`kTriangleBudgetRatio = 0.9`. Margin: 0.9 sits ~8% above the correct code's
observed maximum (0.833) and comfortably below every ratio the M5 mutation
produced where it moved the count at all (1.0-1.172, see below). The value
and the measured brackets it sits between are recorded in the code comment on
`kTriangleBudgetRatio` in `tile_comparison.dart`.

### M5 — the reviewer's exact mutation

`cp lib/src/tile_cache.dart /tmp/tile_cache.m5_pre` was run first.

Applied exactly as the reviewer specified — `Size(strip.width, strip.height)`
→ `viewport`, nothing else touched:

```dart
    _drawInto(
        canvas,
        viewport,
        ViewportTransform(
            worldToScreenMatrix: Transform2(
                q.a, q.b, q.c, q.d, q.e - strip.left, q.f - strip.top)),
        painter,
        sink,
        vertices,
        origin,
        null);
```

Command: `CI=true flutter test test/tile_fallback_test.dart`

Verbatim RED output:

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
00:00 +0: criterion 2 and 2c: a partly baked frame equals the live frame
00:00 +0 -1: criterion 2 and 2c: a partly baked frame equals the live frame [E]
  Expected: a value less than <54.0>
    Actual: <70>
     Which: is not a value less than <54.0>
  pan Offset(37.0, 0.0): the tiled arm emitted as much geometry as the full-frame live arm, so the fallback walked far more than the strip: InkReport(live: 38886, tiled: 38886, stray: 0, uncovered: 0, differing: 0, liveTri: 60, tiledTri: 70)
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/support/tile_comparison.dart 275:7             measureFallbackAgreement
  
00:00 +0 -1: criterion 2b: the near-axis arm stays inside the tiled path's bound
00:00 +1 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart: criterion 2 and 2c: a partly baked frame equals the live frame
```

`criterion 2 and 2c` goes RED at the first offset (60 * 0.9 = 54, actual 70).
Note `criterion 2b` (`+1 -1`, listed as passed) is unaffected, confirming the
opt-in scoping holds under the mutation too. Full per-offset M5 triangle
counts on `fillingGrid` (gathered with the same temporary debug print used
above, before the assertion halted the sweep at offset 0): (37,0) 70/60=1.167;
(53,0) 68/58=1.172; (71,0) 58/58=1.0; (0,37) 70/60=1.167; (0,53) 70/60=1.167;
(0,71) 58/58=1.0; (-41,0) 38/58=0.655 (unchanged from correct code); (0,-41)
48/60=0.8 (unchanged from correct code). Six of eight ratios moved under M5;
the sweep only needed the first to redden.

Restored: `cp /tmp/tile_cache.m5_pre lib/src/tile_cache.dart`, verified
byte-identical via `diff` (`RESTORED_OK`).

Confirm green: `CI=true flutter test test/tile_fallback_test.dart`

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
00:00 +0: criterion 2 and 2c: a partly baked frame equals the live frame
00:00 +1: criterion 2b: the near-axis arm stays inside the tiled path's bound
00:00 +2: All tests passed!
```

### M3 — re-confirmed with the new gate in place

`cp lib/src/tile_cache.dart /tmp/tile_cache.m3_v2` was run first, then
`kTileSlack` → `-20.0` at all four call sites in `stripFor`, identical to the
original task's M3.

Command: `CI=true flutter test test/tile_fallback_test.dart --plain-name "criterion 2 and 2c"`

Verbatim RED output:

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
00:00 +0: criterion 2 and 2c: a partly baked frame equals the live frame
00:00 +0 -1: criterion 2 and 2c: a partly baked frame equals the live frame [E]
  Expected: <0>
    Actual: <1642>
  Offset(37.0, 0.0): InkReport(live: 38886, tiled: 37244, stray: 0, uncovered: 1642, differing: 1642, liveTri: 60, tiledTri: 10)
  
  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/tile_fallback_test.dart 59:7                   main.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart: criterion 2 and 2c: a partly baked frame equals the live frame
```

Same `uncoveredPixels: 1642` as before this fix round (the pixel assertion,
which appears earlier in the test body, still fires first and identically —
the new triangle-budget assertion never gets a chance to run for this
mutant). M3 still kills the test.

Restored: `cp /tmp/tile_cache.m3_v2 lib/src/tile_cache.dart`, verified
byte-identical via `diff` (`RESTORED_OK`).

Confirm green: `CI=true flutter test test/tile_fallback_test.dart`

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
00:00 +0: criterion 2 and 2c: a partly baked frame equals the live frame
00:00 +1: criterion 2b: the near-axis arm stays inside the tiled path's bound
00:00 +2: All tests passed!
```

Also confirmed `lib/src/tile_cache.dart` is byte-identical to the file as it
stood before this fix round began (`diff /tmp/tile_cache.baseline lib/src/tile_cache.dart`
— no output, `IDENTICAL_TO_TASK5_BASELINE`), so this fix round changed no
production code, only test support.

### Full suite, analyze, format

Command: `CI=true flutter test`

Tail of transcript:

```
00:07 +368 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the same holds at 4.5e6 with the view over one nested instance
00:07 +369 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the same holds at 4.5e6 with the view over one nested instance
00:07 +370 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the sink inks nothing the painter did not ask for
00:07 +371 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/vertices_differential_test.dart: the comparison is not vacuous
00:07 +372 ~1: All tests passed!
```

Same 372 passed, 1 skipped as before this fix round — no change in outcome
count.

Command: `flutter analyze`

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.8s)
```

Command: `dart format --output=none --set-exit-if-changed .`

First run flagged the two edited files as needing formatting (`Formatted 65
files (2 changed)`); `dart format test/support/tile_comparison.dart
test/tile_fallback_test.dart` was run to apply it, then the check re-run
clean:

```
Formatted 65 files (0 changed) in 0.13 seconds.
```

### `git status --porcelain` before staging

```
 M packages/jet_cad_2d_flutter/test/support/tile_comparison.dart
 M packages/jet_cad_2d_flutter/test/tile_fallback_test.dart
```

No `analysis_options.yaml` present. Only these two files were staged and
committed.

### Commit

`6cca683` — "test: gate the live fallback's triangle count against the
full-frame walk" — 2 files changed, 86 insertions(+), 4 deletions(-).

### Status

DONE. M5 (the reviewer's exact mutation) now reddens `criterion 2 and 2c`
via the triangle-budget assertion; M3 still reddens it via the pre-existing
pixel assertion, confirmed re-run with the new gate present. `criterion 2b`
is unaffected by either mutant and stays green throughout, by design (the
triangle-budget check is opt-in and `nearAxisDiagonals` does not enable it,
for the fixture-dependence reason measured and recorded above). Full suite,
analyze, and format are green with the same pass/skip counts as before this
fix round.
