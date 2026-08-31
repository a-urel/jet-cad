# Task 5 report: the collector shades a dashed polyline

Branch: `plan-c/shaded-dashes`.

## What changed and why

`lib/src/gpu/geometry_collector.dart`:

- **The dash bracket state** (Step 3 of the brief, transcribed verbatim):
  `_dashActive`, `_dashPeriodLocal`, the parallel `_dashFracStart`/
  `_dashFracEnd` lists, the per-primitive pending fields
  (`_pendingSegPeriod`/`_pendingSegPhase`, `_pendingJoinPeriod`/
  `_pendingJoinPhase`), and `_suppressJoins`.
- `beginDash` sums the cycle from `pattern.dashes` (never
  `pattern.totalLength`), bails to `_dashActive = false` on a non-finite or
  non-positive cycle or a non-finite `patternToLocal` (the same decision
  `Dasher.dashPolyline` reaches), otherwise fills the two fraction lists from
  the pattern's positive (drawn) elements and sets `_dashPeriodLocal = cycle
  * patternToLocal`.
- `endDash` resets `_dashActive`, `_suppressJoins`, and all four pending
  fields.
- `_emit` (the stroke writer) now branches on `_pendingSegPeriod`: zero means
  the old one-`writeStroke` path; nonzero writes one `writeStroke` per drawn
  element (`_dashFracStart.length`, or 1 if empty — the collapse case), the
  first carrying a **negated** `dashPeriod` as the collapse representative.
- `_emitJoin` got the identical shape against `_pendingJoinPeriod`/
  `_pendingJoinPhase`, with `debugCollinearJoins` still incremented exactly
  once per corner (before the element-fan loop), not once per element.
- `_runTo`'s join guard became `if (_runHasDirection && !_suppressJoins) {
  join } else if (!_runHasDirection) { record second point }` — the
  brief's flagged trap; a plain `if (A && !B) {...} else {...}` would have
  recorded `_runSecondX/Y` on every suppressed step and corrupted the seam.
  `_endRun`'s seam-join call is now also guarded with `&& !_suppressJoins`.
- `polyline` sets `_suppressJoins = _dashActive` at entry, computes
  `_pendingSegPeriod` per segment as `_dashPeriodLocal * (collectionLen /
  localLen)` (the segment's own local-to-collection length ratio, not
  `_residual.scaleMagnitude`) with phase pinned to `0.0` (the phase restarts
  at every vertex, `dasher.dart:94-96`), and clears `_suppressJoins` and
  `_pendingSegPeriod` back to their rest values at the end — the brief's
  second flagged trap, because `polyline` can be called twice inside one
  bracket and a pending value that survived would leak into the next
  primitive.

`test/gpu/geometry_collector_test.dart`: appended the brief's ten-test block
verbatim, filling in every `/* as above, but ... */` placeholder against the
brief's own fixtures (`dashed`, `dashDot`, `allGap`, `style` — renamed
`dashStyle` here since `_style` was already taken in this file) and hand
tracing each expected value against the arithmetic above before writing it
(e.g. `dashDot`'s cycle 18.5, `12/18.5` and `15/18.5..15.5/18.5` for its two
drawn elements; `dashed`'s `D == 1`, so "endDash restores solid emission"
reads `1 + 3` from one dashed segment plus a plain two-segment/one-join run).

## The two `break` arms — finding

Checked `test/support/differential.dart:134-135` and
`test/support/vertices_differential.dart:163-165` after the change: both
still carry a no-op `break` for `BeginDashOp`/`EndDashOp`, byte-identical to
before this task (`git diff` against them is empty). Nothing in this task
touches `DraftPainter` or either oracle file, and `GeometryCollector.beginDash`/
`endDash` are reachable in this codebase only from the new tests calling them
directly — `DraftPainter` does not open a dash bracket on any sink until a
later task. So neither oracle's op stream can contain a `BeginDashOp`/
`EndDashOp` yet, and the two `break` arms remain correct and unreached. Left
both files alone, as instructed.

## Exact commands run, with output and exit codes

### 1. `flutter test test/gpu/geometry_collector_test.dart` (new tests only, before the full suite)

```
$ cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
...
00:00 +26: a dashed polyline emits one instance per segment per drawn element, and no joins at all
00:00 +27: the same polyline undashed keeps its join -- so the assertion above is about dashes, not about the fixture
00:00 +28: a two-element pattern doubles the instances and the two elements tile the cycle without overlapping
00:00 +29: the period is the cycle times the scale, in collection units
00:00 +30: a scaled residual scales the period, because the pattern is measured in the space the points are in
00:00 +31: exactly one instance per primitive is the collapse representative
00:00 +32: a pattern with no drawn element still emits one instance, so the collapse case has something to draw
00:00 +33: endDash restores solid emission
00:00 +34: a zero-cycle pattern is solid, matching dashPolyline returning false
00:00 +35: the phase of every polyline segment is zero -- the pattern restarts at each vertex, which is dasher.dart:94-96
00:00 +36: All tests passed!
```
Exit code: 0. 36 tests in this file (26 pre-existing + 10 new).

### 2. `flutter test` (full suite)

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:07 +499 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: tile boundaries carry no difference of their own
00:07 +500 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugRestBakeDisabled slices nothing and still covers
00:07 +501 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_measurement_seam_test.dart: debugFullViewportQuery grows the fallback walk to the whole viewport
00:07 +502 ~1: All tests passed!
```
Exit code: 0. 502 passed, 1 skip (the same pre-existing `rig`-tagged skip
Task 4's report recorded at 492+1; this task adds the 10 new tests, landing
at 502).

### 3. `flutter analyze`

First run, before removing the dead field noted below:

```
$ flutter analyze
...
warning • The value of the field '_dashCycle' isn't used. Try removing the field, or using it • lib/src/gpu/geometry_collector.dart:354:10 • unused_field
1 issue found. (ran in 1.3s)
```
Exit code: 1. Fixed (see "Anything the brief got wrong" below). Re-run:

```
$ flutter analyze
...
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)
```
Exit code: 0.

### 4. `dart format --output=none --set-exit-if-changed .`

First run, before formatting the hand-edited test file:

```
$ dart format --output=none --set-exit-if-changed .
Changed test/gpu/geometry_collector_test.dart
Formatted 89 files (1 changed) in 0.16 seconds.
```
Exit code: 1. Fixed:

```
$ dart format lib/src/gpu/geometry_collector.dart test/gpu/geometry_collector_test.dart
Formatted test/gpu/geometry_collector_test.dart
Formatted 2 files (1 changed) in 0.01 seconds.

$ dart format --output=none --set-exit-if-changed .
Formatted 89 files (0 changed) in 0.17 seconds.
```
Exit code: 0.

Re-ran the full suite and `flutter analyze` after both fixes to confirm
nothing regressed — both green again (502/1 and "No issues found!" as
above).

### 5. `analysis_options.yaml` trap

```
$ git status --short
 M packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart
 M packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
```
No `analysis_options.yaml` present, and no changes outside the two files this
task's brief names. `packages/jet_cad_2d` and both differential oracle files
(`test/support/differential.dart`, `test/support/vertices_differential.dart`)
are untouched, confirmed by `git status --short packages/jet_cad_2d/` (no
output) and `git diff --stat` on the two oracle files (no output).

## Anything the brief got wrong

1. **The `_dashCycle` field in Step 3's code block is dead on arrival.**
   The brief's transcribed bracket-state code declares `double _dashCycle =
   0;` and `beginDash` sets it (`_dashCycle = cycle;`), but nothing in the
   rest of the brief — `_emit`, `_emitJoin`, `polyline`, or any later step —
   ever reads it; the fraction math and `_dashPeriodLocal` all derive from
   the local `cycle` variable inside `beginDash` itself. Following the brief
   literally left `flutter analyze` non-green (`unused_field`, exit 1),
   which violates this task's own "ends green" gate. Removed the field and
   its one assignment rather than suppressing the warning — nothing else in
   the class or the new tests references it, and the brief gives no
   indication a later task (6, curves) needs a collector-held cycle rather
   than a locally-scoped one. If Task 6 does turn out to need the cycle
   value on the instance, it can be re-added then with an actual reader.
2. Everything else in the brief matched what was needed: the field values,
   the `_emit`/`_emitJoin` shapes, the two flagged traps (`_runTo`'s guard
   and `_pendingSegPeriod`'s double-clear site), and every test's expected
   arithmetic (double-checked the `dashDot` fractions and the `dashed`
   period by hand before transcribing — see "What changed and why" above).

## Commit

```
git add packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
git commit -m "feat(gpu): a dashed polyline collects as elements, not as spans"
```
SHA: `ad37551` on `plan-c/shaded-dashes`, parent `13c92ca`.

## Fix round 1: two findings, both "correct code, unkillable mutation"

**Review verdict:** task quality not approved. Two Important findings, both
the same shape — the production code was correct but no test in the new
block could kill a one-line mutation of it.

**Finding 1.** Every dash fixture (`dashed`, `dashDot`, `allGap`,
`degenerate`) has an honest `totalLength`, so `beginDash`'s
`var cycle = pattern.totalLength;` mutation (dropping the sum over
`pattern.dashes`) passed all ten new tests and the whole suite.

**Finding 2.** The only scaled-residual test used `Transform2.scale(3.0,
3.0)` — isotropic — over one segment, so `collectionLen/localLen` and
`_residual.scaleMagnitude` coincide and the mutation
`_pendingSegPeriod = _dashPeriodLocal * _residual.scaleMagnitude;` (using the
whole-transform scalar instead of the per-segment ratio) also passed
everything.

### Fixes

Added two tests to `test/gpu/geometry_collector_test.dart`, both in the dash
section, immediately before the existing "the phase of every polyline
segment is zero" test:

1. **`'the cycle comes from summing the dashes, never from a dishonest
   totalLength'`.** New fixture `dishonestTotal = DashPattern(dashes: [12.0,
   -6.0], totalLength: 99.0)` — the same dashes as `dashed`, but a
   `totalLength` that disagrees with them. Asserts the emitted period is
   `36.0` (summed dashes 18.0 × `patternToLocal` 2.0), not `198.0` (99.0 ×
   2.0).
2. **`'an anisotropic residual scales each segment by its OWN axis, not by
   scaleMagnitude'`.** `Transform2.scale(2.0, 5.0)` over a three-point
   polyline whose first segment runs along local x and second along local y.
   Asserts `yPeriod / xPeriod` is `closeTo(5.0 / 2.0, 1e-6)` — a ratio, not
   two magic numbers, so the assertion fails loudly under the
   `scaleMagnitude` mutation (which gives both segments `sqrt(2×5)` and
   collapses the ratio to `1.0`) and stays indifferent to an unrelated change
   in the pattern itself.

Ran the file after adding both (before any mutation): all 38 pass.

```
$ flutter test test/gpu/geometry_collector_test.dart
...
00:00 +35: the cycle comes from summing the dashes, never from a dishonest totalLength
00:00 +36: an anisotropic residual scales each segment by its OWN axis, not by scaleMagnitude
00:00 +37: the phase of every polyline segment is zero -- the pattern restarts at each vertex, which is dasher.dart:94-96
00:00 +38: All tests passed!
```
Exit code: 0.

### Kill demonstration 1 — the `totalLength` mutation

Backed up the production file first (`cp`, not `git checkout --` — this
project lost a round of uncommitted work to that once):

```
$ cp packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart /tmp/geometry_collector.dart.bak
```

Mutated `beginDash` in `lib/src/gpu/geometry_collector.dart` to read
`pattern.totalLength` instead of summing `pattern.dashes`:

```dart
    // before:
    var cycle = 0.0;
    for (final d in pattern.dashes) {
      cycle += d.abs();
    }
    if (!cycle.isFinite || cycle <= 0.0 || !patternToLocal.isFinite) {

    // after (MUTATION):
    var cycle = pattern.totalLength; // MUTATION: dropped the sum for kill-test
    if (!cycle.isFinite || cycle <= 0.0 || !patternToLocal.isFinite) {
```

Ran the covering test file — **it fails**, exactly on the new test, with the
mutant's period (99.0 × 2.0 = 198.0) instead of the correct one:

```
$ cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
...
00:00 +35 -1: the cycle comes from summing the dashes, never from a dishonest totalLength [E]
  Expected: a numeric value within <0.000001> of <36.0>
    Actual: <198.0>
     Which:  differs by <162.0>
  summed dashes (12 + 6) x patternToLocal 2.0 = 36.0, not 99.0 x 2.0 = 198.0 from the dishonest totalLength

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 886:5         main.<fn>

00:00 +37 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: the cycle comes from summing the dashes, never from a dishonest totalLength
```
Exit code: 1 ("Some tests failed").

Restored from the `cp` backup, confirmed byte-identical, re-ran green:

```
$ cp /tmp/geometry_collector.dart.bak packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart
$ git diff --stat packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart
(no output -- byte-identical to the committed version)

$ flutter test test/gpu/geometry_collector_test.dart
...
00:00 +38: All tests passed!
```
Exit code: 0.

### Kill demonstration 2 — the `scaleMagnitude` mutation

Re-used the same `cp` backup taken above (the file was byte-identical to the
committed version at this point, so the backup still matched).

Mutated `polyline`'s per-segment dash-period computation to use
`_residual.scaleMagnitude` (a single whole-transform scalar) instead of the
segment's own `collectionLen / localLen` ratio:

```dart
    // before:
        final llx = lx - points[i * 2 - 2], lly = ly - points[i * 2 - 1];
        final localLen = math.sqrt(llx * llx + lly * lly);
        final cdx = nx - px, cdy = ny - py;
        final collectionLen = math.sqrt(cdx * cdx + cdy * cdy);
        _pendingSegPeriod =
            localLen > 0 ? _dashPeriodLocal * (collectionLen / localLen) : 0.0;
        _pendingSegPhase = 0.0;

    // after (MUTATION):
        // MUTATION: dropped the per-segment ratio for kill-test
        _pendingSegPeriod = _dashPeriodLocal * _residual.scaleMagnitude;
        _pendingSegPhase = 0.0;
```

Ran the covering test file — **it fails**, exactly on the new test, with the
ratio collapsed to `1.0` (both segments getting the same `scaleMagnitude` of
`sqrt(2 × 5)`) instead of `2.5`:

```
$ cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
...
00:00 +36 -1: an anisotropic residual scales each segment by its OWN axis, not by scaleMagnitude [E]
  Expected: a numeric value within <0.000001> of <2.5>
    Actual: <1.0>
     Which:  differs by <1.5>
  the x-running segment scales by 2, the y-running segment by 5 -- scaleMagnitude would give both sqrt(10) and a ratio of 1.0

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 916:5         main.<fn>

00:00 +37 -1: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart: an anisotropic residual scales each segment by its OWN axis, not by scaleMagnitude
```
Exit code: 1 ("Some tests failed").

Restored from the `cp` backup, confirmed byte-identical, re-ran green:

```
$ cp /tmp/geometry_collector.dart.bak packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart
$ git diff --stat packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart
(no output -- byte-identical to the committed version)

$ flutter test test/gpu/geometry_collector_test.dart
...
00:00 +38: All tests passed!
```
Exit code: 0.

### Post-fix gates

```
$ flutter analyze
...
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.3s)
```
Exit code: 0.

```
$ dart format --output=none --set-exit-if-changed .
Changed test/gpu/geometry_collector_test.dart
Formatted 89 files (1 changed) in 0.20 seconds.
```
Exit code: 1. Fixed:

```
$ dart format test/gpu/geometry_collector_test.dart
Formatted 1 file (1 changed) in 0.01 seconds.

$ dart format --output=none --set-exit-if-changed .
Formatted 89 files (0 changed) in 0.17 seconds.
```
Exit code: 0.

Re-ran the covering test file once more after the reformat to confirm the
formatter changed nothing behaviourally:

```
$ flutter test test/gpu/geometry_collector_test.dart
...
00:00 +38: All tests passed!
```
Exit code: 0.

Full suite, run once since this round touches a file 38 tests now live in:

```
$ flutter test
...
00:07 +504 ~1: All tests passed!
```
Exit code: 0. 504 passed, 1 pre-existing skip (was 502+1 before this round's
two new tests).

```
$ git status --short
 M packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
```
Only the test file changed for this round — the production file is back to
its committed state after both restores. No `analysis_options.yaml` present.

## Commit (fix round 1)

```
git add packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
git commit -m "test(gpu): a dishonest totalLength and an anisotropic residual, killable"
```
