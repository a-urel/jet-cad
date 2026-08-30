# Task 6 report: `point()`

Commit: `c0062c3ee79cdd6e28a01ced4cd3e968ded729ec`

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart` — `point()` implemented, `skippedOps` doc trimmed.
- `packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart` — three new tests from the brief.
- `packages/jet_cad_2d_flutter/test/gpu/collector_differential_test.dart` — oracle extended with `PointOp`.

## Defect found in the brief's sample code

**Every `ResolvedStyle(...)` literal in the brief's Step 1 sample omits `linetype` and
`linetypeScale`**, but `ResolvedStyle`'s constructor (`packages/jet_cad_2d/lib/src/document/resolved_style.dart:8-13`)
requires all four named arguments (`argb`, `lineweightHundredths`, `linetype`, `linetypeScale`).
Pasted verbatim the sample does not compile. Fixed by adding `linetype: Handle.none,
linetypeScale: 1` to all three `ResolvedStyle` literals in the three new tests — matching
every other `ResolvedStyle` construction already in this file. This is the same class of
defect the task brief's own "Interfaces and decisions" section warned about ("This plan's
sample code omits them everywhere; fill them in without dwelling on it"), confirmed here
by actually running it. Step 3's implementation sample was correct as written and landed
unmodified.

## TDD evidence

### Failing run before (Step 2)

```
$ cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart; echo "exit=$?"
...
00:00 +20: a zero or negative radius draws nothing
00:00 +21: a point is one instance of its own kind, at the transformed position
00:00 +21 -1: a point is one instance of its own kind, at the transformed position [E]
  Expected: <1>
    Actual: <0>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 587:5         main.<fn>

00:00 +21 -1: a point takes the hairline fade like a stroke
00:00 +21 -2: a point takes the hairline fade like a stroke [E]
  RangeError (length): Invalid value: Valid value range is empty: 11
  dart:typed_data                               Float32List.[]
  test/gpu/geometry_collector_test.dart 616:18  main.<fn>

00:00 +21 -2: after Plan B, only fills and text are skipped
00:00 +21 -3: after Plan B, only fills and text are skipped [E]
  Expected: <0>
    Actual: <1>
  four ops Plan B draws

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 636:5         main.<fn>

00:00 +21 -3: Some tests failed.

Failing tests:
  .../test/gpu/geometry_collector_test.dart: a point is one instance of its own kind, at the transformed position
  .../test/gpu/geometry_collector_test.dart: a point takes the hairline fade like a stroke
  .../test/gpu/geometry_collector_test.dart: after Plan B, only fills and text are skipped
exit=0
```

(`exit=0` is `flutter`'s own wrapper exit code from the tool's shell capture, not the test
runner's — the "Some tests failed." line and the three `[E]` blocks are the actual signal;
the twenty-one pre-existing tests all still passed, confirming the failures are exactly the
three new ones and nothing else regressed.)

### Passing run after implementation

```
$ cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart; echo "exit=$?"
...
00:00 +20: a zero or negative radius draws nothing
00:00 +21: a point is one instance of its own kind, at the transformed position
00:00 +22: a point takes the hairline fade like a stroke
00:00 +23: after Plan B, only fills and text are skipped
00:00 +24: All tests passed!
exit=0
```

## The differential-oracle count going stale, caught live

Before touching the oracle, running the differential test with `point()` already
implemented (oracle unchanged) reproduced Ruling B5's predicted defect exactly:

```
$ flutter test test/gpu/collector_differential_test.dart; echo "exit=$?"
...
00:00 +0: emits every polyline segment the painter walks, in the same order, with the residual applied and half-width scaled by dpr
00:00 +0 -1: emits every polyline segment the painter walks, in the same order, with the residual applied and half-width scaled by dpr [E]
  Expected: <182>
    Actual: <183>
  the collector must emit exactly one instance per segment and per join the declarative rule produces -- neither dropping nor duplicating one

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/collector_differential_test.dart 143:5     main.<fn>

00:00 +0 -1: Some tests failed.
exit=0
```

## Differential-oracle changes

`test/gpu/collector_differential_test.dart`:

1. **New `_ExpectedInstance.point(style, x0, y0)` constructor** — sets `kind = kKindPoint`,
   `x1 = y1 = x2 = y2 = 0`. This mirrors `writePoint` zeroing all four slots
   (`instance_record.dart:160-163`), which is what the existing comparison loop's `x1`/`y1`/
   `x2`/`y2` assertions already check unconditionally for every instance.
2. **New `if (op is PointOp)` branch** in the main walk loop, alongside the existing
   `PolylineOp`/`CircleOp`/`ArcOp` branches. Declarative, no run state: it appends one
   `_ExpectedInstance.point` with the residual applied to the op's own (already
   screen-rebased) coordinates — `residual.a * op.x + residual.c * op.y + residual.e` /
   `residual.b * op.x + residual.d * op.y + residual.f` — exactly the formula
   `VerticesDrawSink.point` and `GeometryCollector.point` both use.
3. **Reason-string fix on the `kind` assertion** (was:
   `'instance $i must be a ${e.kind == kKindJoin ? "join" : "stroke"}'`) — extended to a
   three-way ternary that also names `"point"`.

### Per-assertion classification

- **`kind` assertion** (`expect(data[o + InstanceFieldOffset.kind], e.kind, ...)`): the
  comparison itself was **already correct** — it is generic over `e.kind` and needed no
  code change to catch a point emitted as the wrong kind. Only its `reason:` message was
  **was-vacuous-in-effect for a point**: before this change, a failing point-kind
  comparison would have printed the misleading reason `"instance N must be a stroke"`
  (the ternary's `else` branch), which doesn't invalidate the assertion but would have
  misdirected debugging. Fixed to name `"point"` correctly.
- **`x0`/`y0`/`x1`/`y1`/`x2`/`y2`/`halfWidth`/`r`/`g`/`b`/`a` assertions**: **unchanged
  code, newly exercised**. These loop bodies read generically off `_ExpectedInstance`
  (`e.x0`, `e.style`, …) and required no per-kind branching, so they were already
  "correct" in the sense of not needing to change — but before this task they had never
  been exercised against a `kKindPoint` record, since no `_ExpectedInstance.point` existed
  to feed them one. They are not newly written, but they are newly load-bearing for the
  point case; the M-B8 mutation below is the proof they actually catch a point-shaped
  defect and weren't accidentally vacuous for it.
- **`instanceCount` / `expected.length` assertion**: unchanged code, and this is the
  assertion that went red first (182 vs 183, above) purely from the new op being drawn —
  confirming it was already live and not vacuous before the oracle update.

No existing assertion was weakened, loosened, or removed.

## M-B8 mutation: point() as a zero-length capped stroke

Backed up the file before mutating:

```
$ cp lib/src/gpu/geometry_collector.dart <scratchpad>/geometry_collector.dart.bak
$ md5 lib/src/gpu/geometry_collector.dart <scratchpad>/geometry_collector.dart.bak
MD5 (lib/src/gpu/geometry_collector.dart) = 83f77567826de4359b5e016c1418c7fc
MD5 (<scratchpad>/geometry_collector.dart.bak) = 83f77567826de4359b5e016c1418c7fc
```

Mutation applied — `point()` rewritten to emit `writeStroke` from `(x - half, y)` to
`(x + half, y)` instead of `writePoint`:

```diff
   void point(double x, double y, ResolvedStyle style) {
     final t = _residual;
-    _reserve(_instances + 1);
-    writePoint(_buffer, _instances,
-        x: t.a * x + t.c * y + t.e,
-        y: t.b * x + t.d * y + t.f,
-        halfWidth: _halfWidthFor(style.lineweightHundredths),
-        argb: _coveredArgb(style.argb, style.lineweightHundredths));
+    final px = t.a * x + t.c * y + t.e;
+    final py = t.b * x + t.d * y + t.f;
+    final half = _halfWidthFor(style.lineweightHundredths);
+    _reserve(_instances + 1);
+    writeStroke(_buffer, _instances,
+        x0: px - half,
+        y0: py,
+        x1: px + half,
+        y1: py,
+        halfWidth: half,
+        argb: _coveredArgb(style.argb, style.lineweightHundredths));
     _instances++;
```

Command and verbatim failure — both the unit test and the differential oracle catch it:

```
$ flutter test test/gpu/geometry_collector_test.dart test/gpu/collector_differential_test.dart; echo "exit=$?"
...
00:00 +21 -1: .../test/gpu/geometry_collector_test.dart: a point is one instance of its own kind, at the transformed position [E]
  Expected: <2.0>
    Actual: <0.0>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/geometry_collector_test.dart 590:5         main.<fn>

00:00 +23 -2: .../test/gpu/collector_differential_test.dart: emits every polyline segment the painter walks, in the same order, with the residual applied and half-width scaled by dpr [E]
  Expected: <2.0>
    Actual: <0.0>
  instance 182 must be a point

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/gpu/collector_differential_test.dart 172:7     main.<fn>

00:00 +23 -2: Some tests failed.

Failing tests:
  .../test/gpu/collector_differential_test.dart: emits every polyline segment the painter walks, in the same order, with the residual applied and half-width scaled by dpr
  .../test/gpu/geometry_collector_test.dart: a point is one instance of its own kind, at the transformed position
exit=0
```

Both failures are `kKindPoint` (2.0) expected but `kKindStroke` (0.0) actual — exactly the
mutation, caught at the unit level (`InstanceFieldOffset.kind`) and independently at the
differential-oracle level (`instance 182 must be a point`).

Restored from the `cp` backup, never `git checkout --`:

```
$ cp <scratchpad>/geometry_collector.dart.bak lib/src/gpu/geometry_collector.dart
$ md5 lib/src/gpu/geometry_collector.dart
MD5 (lib/src/gpu/geometry_collector.dart) = 83f77567826de4359b5e016c1418c7fc
```

Matches the pre-mutation backup's hash exactly. `git diff --stat` immediately after showed
the file's diff against the pre-task `HEAD` (18 insertions / 4 deletions — this task's real
`point()` implementation, not the mutation), confirming the mutation left no trace and the
restored content is this task's intended change.

## Full gate

```
$ flutter test; echo "exit=$?"
...
00:05 +463 ~1: ... [last test line] ...
00:05 +463 ~1: All tests passed!
exit=0
```

(463 passed, 1 skipped — the skip is pre-existing and unrelated to this task.)

```
$ flutter analyze; echo "exit=$?"
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.7s)
exit=0
```

```
$ dart format --output=none --set-exit-if-changed .; echo "exit=$?"
Formatted 85 files (0 changed) in 0.13 seconds.
exit=0
```

`(0 changed)` — not a failure.

`git status` before committing showed no `analysis_options.yaml` among the changes;
nothing to revert.

## Summary

`GeometryCollector.point()` now emits one `kKindPoint` instance via `writePoint`, routed
through `_coveredArgb` for the hairline fade, exactly as the interfaces note and the
brief's Step 3 specified. `skippedOps` is now exactly `fillPolygon` + `fillCircle` + `text`.
The differential oracle (`test/gpu/collector_differential_test.dart`) was extended with a
declarative `PointOp` branch and an `_ExpectedInstance.point` constructor, kept
bookkeeping-free per Ruling B5. The M-B8 mutation (point as a zero-length capped stroke)
is caught by both the new unit tests and the differential oracle. Full gate is green.
