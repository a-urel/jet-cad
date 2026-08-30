# Task 3 report: the collector, and the mutation that proves it applies the residual

## Fix report (post-review)

Review came back Approved with two Important findings, both test-coverage
gaps in `geometry_collector_test.dart` — eight surviving mutations across
them — not defects in `geometry_collector.dart`. The production file is
unchanged by this fix; only the test file was edited.

### Finding 1 — half-width formula had no assertion on slot 5

`_halfWidthFor` (`geometry_collector.dart:51-57`) computes
`logical = lineweightHundredths/100 * pixelsPerPaperMm * lineweightScale`,
clamps it to a floor of `kMinStrokeDevicePixels / devicePixelRatio`, then
halves it. Nothing read the resulting `halfWidth` (slot 5) anywhere, so four
mutations survived: returning `w` instead of `w / 2`; dropping
`* lineweightScale`; dropping the floor clamp; and computing the floor as
`kMinStrokeDevicePixels * devicePixelRatio` instead of dividing.

Fixed by:
- Adding `expect(r[5], 1.0)` to the residual test (nominal fixture:
  `lineweightHundredths: 50, pixelsPerPaperMm: 4, devicePixelRatio: 2,
  lineweightScale: 1` → `logical = 0.5*4*1 = 2.0`, floor `= 1.0/2 = 0.5`,
  `2.0 > 0.5` so `w = 2.0`, `halfWidth = 2.0/2 = 1.0`). This alone kills
  "return `w`" and, combined with the new floor test below, also kills the
  "floor computed as `kMin * devicePixelRatio`" mutation (with that mutated
  floor of `2.0`, the nominal case coincidentally still passes since
  `2.0 > 2.0` is false and `w` clamps to the same `2.0` — so I verified the
  floor mutation separately by hand: it is caught by the new hairline test,
  not the nominal one — see below).
- New test `clamps to the device-pixel floor at a hairline lineweight`:
  `lineweightHundredths: 0` gives `logical = 0.0`, below the floor of `0.5`,
  so the clamp takes over: `halfWidth = 0.5/2 = 0.25`. This kills "drop the
  floor clamp entirely" (would give `0.0`) and the floor-formula mutation
  (mutated floor `= 1.0*2 = 2.0`, `w` clamps to `2.0`, `halfWidth = 1.0`,
  not `0.25`).
- New test `lineweightScale multiplies the logical width before the clamp`:
  `lineweightScale: 2` (not the invisible default of `1.0`) gives
  `logical = 0.5*4*2 = 4.0`, above the floor, `halfWidth = 4.0/2 = 2.0`.
  Kills "drop `* lineweightScale`" (would give `1.0`, same as the nominal
  case, which is exactly why the default scale can't pin this).

All three expected values were computed by hand from the formula in
`geometry_collector.dart:51-57`, not by running the test and recording the
output.

### Finding 2 — residual fixture was diagonal, so a transposed residual was invisible

The old fixture, `Transform2(2, 0, 0, 3, 10, 10)`, has `b == c == 0`; the two
segment points `(1,1)` and `(2,2)` both sit on `x == y`. Swapping `t.c` for
`t.b` in the residual application (`geometry_collector.dart:102,103,106,107`)
therefore left every computed value unchanged — a rotated or sheared DXF
`INSERT` produces exactly the residual shape (`b != c`, both nonzero) this
fixture could never distinguish.

Replaced it with `Transform2(2, 0.5, -1, 3, 10, 10)` (`b = 0.5`, `c = -1`,
`b != c` and neither is `0`) and points `(1, 2)` and `(4, 3)`, neither on
`x == y`. Expected values computed by hand from `Transform2`'s own
convention (`px = a*x + c*y + e`, `py = b*x + d*y + f`):

```
(1, 2) -> (2*1 + -1*2 + 10, 0.5*1 + 3*2 + 10) = (10, 16.5)
(4, 3) -> (2*4 + -1*3 + 10, 0.5*4 + 3*3 + 10) = (15, 21)
```

Independently verified with a throwaway Python snippet before writing the
test (not by running the Dart test and copying its output):

```
$ python3 -c "
a,b,c,d,e,f = 2, 0.5, -1, 3, 10, 10
def tx(x,y): return a*x+c*y+e, b*x+d*y+f
print(tx(1,2)); print(tx(4,3))"
(10, 16.5)
(15, 21.0)
```

### `expect(r[0], kKindStroke)` (the one optional item)

Left as-is. `kKindStroke == 0` and every `Float32List` Dart allocates is
zero-initialized — there is no way to observe uninitialized memory in Dart,
so there is no way to "pre-dirty" a slot from test code without reaching into
the collector's private buffer. And since `kKindStroke` is currently the
*only* kind value this task ever writes, no real write can produce a
different value there either — the assertion is genuinely vacuous in this
task's scope, not just hard to strengthen cheaply. It becomes meaningful the
moment a second kind constant exists (Plan B+), which is out of scope here.
Flagging this rather than manufacturing a fake fix.

### Covering tests, commands, and actual output

**Full coverage suite, after both fixes (no production code changed at this
point — implementation was already correct, so these are new assertions on
existing correct behaviour):**

```
$ cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
00:00 +0: loading .../geometry_collector_test.dart
00:00 +0: applies the residual, and a transposed one is not the same residual
00:00 +1: emits one instance per segment, in walk order
00:00 +2: drops a zero-length segment rather than handing the shader a NaN
00:00 +3: counts the ops Plan A does not draw instead of dropping them silently
00:00 +4: clamps to the device-pixel floor at a hairline lineweight
00:00 +5: lineweightScale multiplies the logical width before the clamp
00:00 +6: All tests passed!
```

**Mutation A — swap `t.b` for `t.c` in the residual application**
(`geometry_collector.dart:102-107`, edited in place, then reverted):

```dart
    // MUTATION: swap t.b for t.c (transposes the residual's linear part).
    var px = t.a * points[0] + t.b * points[1] + t.e;
    var py = t.c * points[0] + t.d * points[1] + t.f;
    final firstX = px, firstY = py;
    for (var i = 1; i < count; i++) {
      final qx = t.a * points[i * 2] + t.b * points[i * 2 + 1] + t.e;
      final qy = t.c * points[i * 2] + t.d * points[i * 2 + 1] + t.f;
```

Command: `flutter test test/gpu/geometry_collector_test.dart`. Actual output:

```
00:00 +0: applies the residual, and a transposed one is not the same residual
00:00 +0 -1: applies the residual, and a transposed one is not the same residual [E]
  Expected: [10.0, 16.5, 15.0, 21.0]
    Actual: [13.0, 15.0, 19.5, 15.0]
     Which: at location [0] is <13.0> instead of <10.0>
  test/gpu/geometry_collector_test.dart 46:5          main.<fn>

00:00 +0 -1: emits one instance per segment, in walk order
00:00 +1 -1: drops a zero-length segment rather than handing the shader a NaN
00:00 +2 -1: counts the ops Plan A does not draw instead of dropping them silently
00:00 +3 -1: clamps to the device-pixel floor at a hairline lineweight
00:00 +4 -1: lineweightScale multiplies the logical width before the clamp
00:00 +5 -1: Some tests failed.

Failing tests:
  .../geometry_collector_test.dart: applies the residual, and a transposed one is not the same residual
```

Went red on exactly the residual test, nothing else. Reverted; `git diff
packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart` showed no
diff afterward, confirming a clean revert.

**Mutation B — drop the `/ 2` from the half-width**
(`geometry_collector.dart:56`, edited in place, then reverted):

```dart
    final w = logical.isFinite && logical > floor ? logical : floor;
    // MUTATION: drop the / 2.
    return w;
  }
```

Command: `flutter test test/gpu/geometry_collector_test.dart`. Actual output:

```
00:00 +0 -1: applies the residual, and a transposed one is not the same residual [E]
  Expected: <1.0>
    Actual: <2.0>
  test/gpu/geometry_collector_test.dart 52:5          main.<fn>

00:00 +1 -1: emits one instance per segment, in walk order
00:00 +2 -1: drops a zero-length segment rather than handing the shader a NaN
00:00 +3 -1: counts the ops Plan A does not draw instead of dropping them silently
00:00 +3 -2: clamps to the device-pixel floor at a hairline lineweight [E]
  Expected: <0.25>
    Actual: <0.5>
  test/gpu/geometry_collector_test.dart 101:5         main.<fn>

00:00 +3 -3: lineweightScale multiplies the logical width before the clamp [E]
  Expected: <2.0>
    Actual: <4.0>
  test/gpu/geometry_collector_test.dart 116:5         main.<fn>

00:00 +3 -3: Some tests failed.

Failing tests:
  .../geometry_collector_test.dart: applies the residual, and a transposed one is not the same residual
  .../geometry_collector_test.dart: clamps to the device-pixel floor at a hairline lineweight
  .../geometry_collector_test.dart: lineweightScale multiplies the logical width before the clamp
```

Went red on all three assertions that read slot 5, as expected. Reverted;
`git diff` on the production file again showed nothing, confirming clean.

**Green again after both reverts:**

```
$ flutter test test/gpu/geometry_collector_test.dart
00:00 +0: applies the residual, and a transposed one is not the same residual
00:00 +1: emits one instance per segment, in walk order
00:00 +2: drops a zero-length segment rather than handing the shader a NaN
00:00 +3: counts the ops Plan A does not draw instead of dropping them silently
00:00 +4: clamps to the device-pixel floor at a hairline lineweight
00:00 +5: lineweightScale multiplies the logical width before the clamp
00:00 +6: All tests passed!
```

**Full gate:**

```
$ flutter test
00:06 +423 ~1: All tests passed!
```
(`~1` is the same pre-existing skip marker from before this task; no
failures, and the count rose from 421 to 423 with the two new tests.)

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.7s)
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 79 files (0 changed) in 0.10 seconds.
```
(One intermediate run of this command reported "Changed
test/gpu/geometry_collector_test.dart" — a line-wrap on the hairline test's
`polyline` call. Ran `dart format test/gpu/geometry_collector_test.dart` to
apply it, then re-ran the check clean, then re-ran the focused test to
confirm the reformat didn't change behaviour.)

`git status` before staging showed only
`packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart` modified
— no `analysis_options.yaml` regeneration to discard.

### Files changed (this fix)

- `packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart` (test-only; production `geometry_collector.dart` unchanged)

Commit: `897dde5` — `fix(gpu): close two mutation-coverage gaps in the collector's tests`

### Deferred, per the coordinator's instruction

Not changed, logged as deferred minors per explicit instruction: `endResidual`
not resetting `_residual`, the double-vs-float32 zero-length guard parity
with `VerticesDrawSink._emitSegment`, and `data` allocating a copy per
access.

## What I implemented

`packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart`:
`GeometryCollector implements DrawSink`, walking the document once per rebuild
and writing one `writeStroke` record per non-degenerate polyline segment into
a `Float32List`, in walk order. `beginResidual`/`endResidual` track the current
residual `Transform2` and every polyline point is transformed through it before
being written — nothing is emitted raw. Every op Plan A does not draw yet
(`point`, `circle`, `arc`, `fillPolygon`, `fillCircle`, `text`) increments
`skippedOps` instead of being silently dropped.

`packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart`: the four
tests from the brief, transcribed verbatim.

### One deviation from the brief's sample code, and why

The brief's `_emit` grows a `List<double> _out` via `_out.length = at +
kFloatsPerInstance`, then writes into it through a throwaway
`Float32List(kFloatsPerInstance)` view copied element-by-element. That does
not work: growing a `List<double>` (non-nullable element type) past its
current length via the `length` setter null-fills the new slots internally
and throws `type 'Null' is not a subtype of type 'double' in type cast`. I
reproduced this directly, outside the collector, before touching the
implementation (see RED section below) — it is not particular to this test
fixture; it reproduces from a minimal two-line script.

I replaced the `List<double>` with a `Float32List` grown by capacity-doubling
and copy — the exact pattern already in this file's neighbour,
`VerticesDrawSink._reserve` (`vertices_draw_sink.dart:511-521`) — and have
`writeStroke` write straight into the live buffer at index `_instances`,
removing both the crash and the per-segment temporary view/copy loop the
brief's version had. `data` returns `_buffer.sublist(0, _instances *
kFloatsPerInstance)`. Everything else — the public API, the residual
application, the zero-length-segment guard, the `skippedOps` accounting — is
exactly what the brief specifies.

## TDD Evidence

**RED** — `cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart`,
run before `geometry_collector.dart` existed:

```
test/gpu/geometry_collector_test.dart:5:8: Error: Error when reading 'lib/src/gpu/geometry_collector.dart': No such file or directory
import 'package:jet_cad_2d_flutter/src/gpu/geometry_collector.dart';
       ^
test/gpu/geometry_collector_test.dart:16:15: Error: Method not found: 'GeometryCollector'.
...
00:00 +0 -1: Some tests failed.
```

Expected failure per the brief (`Method not found: 'GeometryCollector'`) — matched.

**Intermediate RED, found during implementation, not part of the brief's plan** —
reproduced the `List<double>` growth bug directly:

```dart
// /tmp/t.dart
void main() {
  final List<double> l = <double>[];
  l.length = 5;
  print(l);
}
```
```
$ dart run /tmp/t.dart
Unhandled exception:
type 'Null' is not a subtype of type 'double' in type cast
#0      List.length= (dart:core-patch/growable_array.dart:236:12)
```

And the same failure surfaced through the actual test suite with the brief's
literal `_out.length = ...` code in place:

```
00:00 +0 -1: applies the residual, and a non-uniform one [E]
  type 'Null' is not a subtype of type 'double' in type cast
  dart:core                                                         List.length=
  package:jet_cad_2d_flutter/src/gpu/geometry_collector.dart 66:10  GeometryCollector._emit
  package:jet_cad_2d_flutter/src/gpu/geometry_collector.dart 96:7   GeometryCollector.polyline
```

This is what led to the `Float32List`-with-doubling fix described above.

**GREEN** — `cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart`, after the fix:

```
00:00 +0: loading /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
00:00 +0: applies the residual, and a non-uniform one
00:00 +1: emits one instance per segment, in walk order
00:00 +2: drops a zero-length segment rather than handing the shader a NaN
00:00 +3: counts the ops Plan A does not draw instead of dropping them silently
00:00 +4: All tests passed!
```

## Mutation Evidence

**Named mutation:** drop the residual transform and emit the raw points.

**Exact edit fired**, in `polyline` (`geometry_collector.dart`), inside the
per-segment loop:

```dart
      final qx = t.a * points[i * 2] + t.c * points[i * 2 + 1] + t.e;
      final qy = t.b * points[i * 2] + t.d * points[i * 2 + 1] + t.f;
      // MUTATION: drop the residual transform and emit raw points.
      _emit(points[0], points[1], points[2], points[3], half, style.argb);
      px = qx;
```

**Command:** `cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart`

**Actual failing output:**

```
00:00 +0: applies the residual, and a non-uniform one
00:00 +0 -1: applies the residual, and a non-uniform one [E]
  Expected: [12.0, 13.0, 14.0, 16.0]
    Actual: [1.0, 1.0, 2.0, 2.0]
     Which: at location [0] is <1.0> instead of <12.0>
  test/gpu/geometry_collector_test.dart 30:5          main.<fn>

00:00 +0: emits one instance per segment, in walk order
00:00 +0 -2: emits one instance per segment, in walk order [E]
  Expected: [1.0, 0.0, 1.0, 1.0]
    Actual: [0.0, 0.0, 1.0, 0.0]
     Which: at location [0] is <0.0> instead of <1.0>
  test/gpu/geometry_collector_test.dart 42:5          main.<fn>

00:00 +2: drops a zero-length segment rather than handing the shader a NaN
00:00 +3: counts the ops Plan A does not draw instead of dropping them silently
00:00 +2 -2: Some tests failed.
```

The mutation went red — both the residual test (its designed target) and the
walk-order test (collaterally, since the mutation also collapses every
segment onto the polyline's raw first two points) failed. The other two tests
were unaffected, as expected.

**Reverted** the edit back to the transformed `qx`/`qy` call, then re-ran:

```
00:00 +0: applies the residual, and a non-uniform one
00:00 +1: emits one instance per segment, in walk order
00:00 +2: drops a zero-length segment rather than handing the shader a NaN
00:00 +3: counts the ops Plan A does not draw instead of dropping them silently
00:00 +4: All tests passed!
```

Green confirmed after revert.

## Full gate

```
$ cd packages/jet_cad_2d_flutter && flutter test
...
00:07 +421 ~1: All tests passed!
```
(`~1` is a pre-existing skip marker from before this task, not a new one; no
failures.)

```
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.0s)
```

```
$ dart format --output=none --set-exit-if-changed .
Formatted 79 files (0 changed) in 0.12 seconds.
```
(exit 0)

`git status` before staging showed only the two new files — no
`analysis_options.yaml` regeneration to discard.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart` (new)
- `packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart` (new)

Commit: `ef53ba9` — `feat(gpu): the collector, and a fixture a dropped residual cannot pass`

## Self-review findings

- All four brief-specified tests present verbatim; `DrawSink` fully
  implemented, all non-stroke ops counted via `skippedOps`, none silently
  dropped.
- Walk order preserved: `_instances` only ever increases, records are written
  at the current write cursor, never sorted or reordered.
- No per-segment allocation once the buffer has capacity: `_reserve` only
  allocates on growth (doubling), and `writeStroke` writes directly into the
  live `Float32List` — no temporary view, no copy loop, unlike the brief's
  literal sample.
- `data` getter allocates one `sublist` copy — this runs once per rebuild
  (per Tasks 5/8/9's stated usage), not once per entity or per frame, so it
  does not touch the frame-path or per-entity allocation constraints.
- Doc comments follow house style: cite `file:line` for the pattern this
  mirrors (`vertices_draw_sink.dart:511-521` for `_reserve`,
  `vertices_draw_sink.dart:503-507` for the zero-length guard,
  `vertices_draw_sink.dart:41-57` for the walk-order defect this design
  avoids), and explain *why*, not just *what*.
- No stray output, no skipped test in the new file, `flutter analyze` clean,
  `dart format` clean.
- Nothing over-built: no extra public API beyond the four names the brief
  specifies, no premature generalization for kinds beyond stroke.

## Issues or concerns

None outstanding. One thing worth flagging for the reviewer: the brief's
Step 3 code sample (`_out.length = ...` on a `List<double>`) does not compile
correctly at runtime — it throws on the very first segment emitted, which is
also the first assertion the residual test makes. I did not silently patch
past this; I reproduced it in isolation first, then replaced the storage with
a `Float32List` grown by doubling (the pattern the file's own doc comment on
`_reserve` cites as its model). The public interface, semantics, and every
test outcome are unchanged from what the brief specifies.
