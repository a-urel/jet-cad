# Task 2 report: the painter routes undashed geometry to a shading sink

Branch: `plan-c/shaded-dashes`, on top of `41b705d` (Task 6, the last of the
4/5/6 sequence this task deliberately follows).

## What changed and why

`lib/src/draft_painter.dart` — three branches, each between the existing
`pattern == null` early return and the call into `_dasher`, exactly as the
brief specified. No shared helper, per the brief's explicit instruction (they
differ in the scale passed and the op emitted).

1. **`_emitScreenSpace` (polyline path).** After the continuous-entity early
   return, before `_spanSink = sink;`:
   ```dart
   if (sink.shadesDashes) {
     sink.beginDash(pattern, _dashScale(style, toScreen));
     sink.polyline(_points, count, style, closed: false);
     sink.endDash();
     sink.endResidual();
     return;
   }
   ```
   Uses `_dashScale(style, toScreen)` — the existing helper, unchanged —
   because the points are already carried into screen space here, so the
   factor must include `toScreen.scaleMagnitude`.

2. **`EntityKind.circle` case in `_emit`.** After its own `pattern == null`
   early return, before `_spanSink = sink;`:
   ```dart
   if (sink.shadesDashes) {
     sink.beginDash(pattern,
         style.linetypeScale * document.header.globalLinetypeScale);
     sink.circle(coords[0] - ox, coords[1] - oy, r, style);
     sink.endDash();
     return;
   }
   ```
   No `chain.scaleMagnitude` — the coordinates stay in the leaf's own local
   space here and the residual (`chain`) carries the scale, matching the
   split `dashArc`'s `scale`/`pixelScale` arguments already make.

3. **`EntityKind.arc` case in `_emit`.** Identical shape, calling
   `sink.arc(coords[0] - ox, coords[1] - oy, r, start, sweep, style)`.

`_dashScale` itself was not touched (see the mutation demonstration below for
why it matters that it wasn't).

## Test file

`test/draft_painter_test.dart` — appended three tests, verbatim assertions
from the brief, placeholders filled from the file's own idiom (`doc.extents`
for the brief's `worldOf(doc)` — no such helper exists in this codebase or
its dependents; `doc.extents` is the `Aabb2` every other camera-construction
site in this file already fits against). Inserted after the existing
"one pixel outside the raw viewport" dash test, before the circle/arc dash
tests begin.

1. **"a shading sink is handed the undashed polyline inside a bracket, and
   the bracket carries the painter's own dash scale"** — asserts one
   `BeginDashOp`/`EndDashOp` pair (not one per span), one `PolylineOp` with 4
   points (whole geometry, not a span), and `patternToLocal` equal to
   `1.0 * globalLinetypeScale * (camera.worldToScreenMatrix.scaleMagnitude *
   2.0)` computed from the camera object itself, not a copied literal.
   **Kill mutation:** delete `* toScreen.scaleMagnitude` from `_dashScale` in
   `draft_painter.dart`. Demonstrated below.

2. **"a non-shading sink still gets spans, and no bracket"** — asserts no
   `BeginDashOp`s and more than one `PolylineOp` for a non-shading sink.
   **Kill mutation:** wrap `_emitScreenSpace`'s new `if (sink.shadesDashes)`
   branch's body around the existing span-emitting call unconditionally (i.e.
   delete the `if (sink.shadesDashes)` guard and always take the bracket
   path) — the non-shading `RecordingDrawSink()` would then throw
   `UnsupportedError` out of `beginDash`, which this test would surface as a
   test failure rather than a false green. Equivalently: flip the polyline
   branch's condition to `!sink.shadesDashes`.

3. **"a shading sink sees no dash-span counters move"** — asserts
   `dashSpanCount == 0` and `collapsedDashCount == 0` after painting a dashed
   fixture into a shading sink. **Kill mutation:** in the polyline branch,
   call `_dasher.dashPolyline(...)` (or otherwise let a span-counting path
   run) before or instead of the `sink.beginDash`/`polyline`/`endDash`
   sequence — `_dashSpans` would then be nonzero and the test would go red.

## Mutation kill, demonstrated

Backed up the file (not `git checkout --`, per the project's standing
instruction after the earlier lost-work incident):

```
$ cp lib/src/draft_painter.dart <scratchpad>/draft_painter.dart.bak
```

Mutated `_dashScale` to drop the screen-scale factor:

```diff
   double _dashScale(ResolvedStyle style, Transform2 toScreen) =>
       style.linetypeScale *
-      document.header.globalLinetypeScale *
-      toScreen.scaleMagnitude;
+      document.header.globalLinetypeScale;
```

Ran the polyline bracket test alone:

```
$ cd packages/jet_cad_2d_flutter && flutter test test/draft_painter_test.dart --plain-name "a shading sink is handed the undashed polyline inside a bracket"
...
00:00 +0: a shading sink is handed the undashed polyline inside a bracket, and the bracket carries the painter's own dash scale
00:00 +0 -1: a shading sink is handed the undashed polyline inside a bracket, and the bracket carries the painter's own dash scale [E]
  Expected: a numeric value within <1e-9> of <2.0>
    Actual: <1.0>
     Which:  differs by <1.0>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/draft_painter_test.dart 283:5                  main.<fn>

00:00 +0 -1: Some tests failed.
```
Exit code: 1 (implicit — "Some tests failed").

Restored from the backup:

```
$ cp <scratchpad>/draft_painter.dart.bak lib/src/draft_painter.dart
$ git diff lib/src/draft_painter.dart
```
Diff after restore contained exactly the three intended branches added in
this task and nothing else — confirmed by reading the full diff.

Re-ran the same test, green:

```
$ flutter test test/draft_painter_test.dart
...
00:00 +15: All tests passed!
```
Exit code: 0. (15 tests total in the file after the append — 12 pre-existing
+ 3 new.)

## Exact commands run, with output and exit codes

### `jet_cad_2d_flutter` full suite

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:07 +513 ~1: All tests passed!
```
513 passed, 1 skip. Exit code: 0.

### `jet_cad_2d_flutter` analyze

```
$ flutter analyze
...
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)
```
Exit code: 0.

### `jet_cad_2d_flutter` format check

```
$ dart format --output=none --set-exit-if-changed .
Formatted 89 files (0 changed) in 0.17 seconds.
```
Exit code: 0. (Ran `dart format lib/src/draft_painter.dart
test/draft_painter_test.dart` once, right after writing the tests, which
reformatted the long test-name string literal in the first new test onto two
lines — that is the only formatting change it made.)

### `dev_harness_2d` gate

```
$ cd apps/dev_harness_2d && flutter test --concurrency=1
...
00:17 +72: All tests passed!
```
72 tests. Exit code: 0.

```
$ flutter analyze
...
Analyzing dev_harness_2d...
No issues found! (ran in 1.2s)
```
Exit code: 0.

### `analysis_options.yaml` / scope check

```
$ git status --short
 M packages/jet_cad_2d_flutter/lib/src/draft_painter.dart
 M packages/jet_cad_2d_flutter/test/draft_painter_test.dart
```
No `analysis_options.yaml` touched. `packages/jet_cad_2d` untouched
(`git diff --stat -- packages/jet_cad_2d/` is empty).

## Note on pre-existing untracked files

`apps/dev_harness_2d/lib/widget_arm.dart` and
`apps/dev_harness_2d/lib/widget_arm_rig.dart` exist on disk but do not appear
in `git status --short` on this branch — they belong to an unrelated spike
branch's working state noted at session start, not to this task. Not
touched, staged, or committed.

## Anything the brief got wrong

1. **`worldOf(doc)`** appears in the Step 1 test code as if it were a real
   helper, but no such function exists anywhere in `jet_cad_2d` or
   `jet_cad_2d_flutter`. Read it as `doc.extents` — the `Aabb2` getter every
   other camera construction in this test file already fits against
   (`ViewportTransform.fit(doc.extents, kViewport)`, used four times
   elsewhere in the same file). The brief's own "placeholders" list
   (`/* the file's own helper */` etc.) didn't name this one explicitly, but
   it's the same shape of gap.
2. Everything else — the three call sites, the exact scale expressions, the
   "do not factor into a helper" instruction, the assertion bodies — matched
   the actual code exactly with no adjustment needed.

## Commit

```
git add packages/jet_cad_2d_flutter/lib/src/draft_painter.dart packages/jet_cad_2d_flutter/test/draft_painter_test.dart
git commit -m "feat(painter): a dash-shading sink gets the pattern, not the spans"
```
