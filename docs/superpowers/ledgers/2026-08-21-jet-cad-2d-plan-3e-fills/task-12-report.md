# Task 12 report: `VerticesDrawSink` fills

## What changed

`packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`:

- Removed the `TODO(Task 12)` forwarding block. `fillPolygon` and
  `fillCircle` no longer call `_flushBeforeUnbatchable()` or `_fallback`.
- `fillPolygon` transforms each triangle's three referenced points straight
  into `_emitTriangle`'s buffer, using `points[triangles[i] * 2 ...]`
  (`triangles` triple-indexes into `points`' own numbering). It uses
  `style.argb` directly — explicitly **not** `_coveredArgb` — with a comment
  explaining why. A defensive `if (triangles.isEmpty) return;` guard is kept
  per the brief, even though the painter never passes an empty list.
- `fillCircle` fans triangles from the centre using `style.argb` directly and
  the same step-count expression `_flatten` uses for its own outline.
- Extracted that expression into a new private helper,
  `int _flattenSteps(double deviceRadius, double theta)`, and changed
  `_flatten` to call it instead of inlining the computation. This makes the
  two callers *provably* share one expression rather than each reproducing
  it. `_flatten`'s behaviour is unchanged: `_flattenSteps(deviceRadius,
  theta)` computes exactly `ideal.clamp(1, kMaxFlattenSegments)` from
  `ideal = (theta * math.sqrt(deviceRadius / (8 * kFlattenTolerance))).ceil()`,
  the same as before the extraction — confirmed by the full suite staying
  green (all arc/circle stroke tests, which exercise `_flatten` directly,
  still pass unchanged).

## Confirmation the fallback forwarding is gone

`grep -n "_flushBeforeUnbatchable\|_fallback" lib/src/vertices_draw_sink.dart`
now shows `_flushBeforeUnbatchable` used only by `text`, and `_fallback` used
only by `text`. Neither `fillPolygon` nor `fillCircle` reference either.

What proves it beyond the grep:

- `test('a fill batches with strokes into one flush, not one call each')`
  emits a stroke, a fill, and a stroke in one residual, flushes once, and
  asserts `sink.totalFlushCount == 1` and `sink.frameTriangleCount == 6`.
  Under the old forwarding, the fill would have forced a mid-frame flush
  (`_flushBeforeUnbatchable`), so `totalFlushCount` would read 2 (or more,
  with a `CanvasDrawSink` fallback call in between) — this test fails on the
  pre-Task-12 code and passes now.
- `test('a polygon fill emits exactly the triangles it was handed')` and
  `test('a filled circle and its own outline use the same step count')`
  assert directly on `frameTriangleCount`, which only counts triangles
  `_emitTriangle` wrote into this sink's own buffer — the fallback path
  never touched it.

## Suite output (verbatim)

### `flutter test test/vertices_draw_sink_test.dart` (post-restore, final run)

```
00:00 +0: loading .../test/vertices_draw_sink_test.dart
00:00 +0: a segment becomes two triangles a half-width either side of it
...
00:00 +26: a polygon fill emits exactly the triangles it was handed
00:00 +27: a fill on a hairline layer keeps full alpha
00:00 +28: a polygon fill is baked into the positions, not pushed on the canvas
00:00 +29: an empty triangle list draws nothing, defensively
00:00 +30: a filled circle and its own outline use the same step count
00:00 +31: a fill batches with strokes into one flush, not one call each
00:00 +32: a zero-radius fill circle emits nothing rather than a NaN fan
00:00 +33: the submitted Vertices is disposed, and the flag reads its state
00:00 +34: the disposed Vertices rasterises the same pixels a retained one would
00:00 +35: a flush with nothing batched disposes nothing
00:00 +36: a 45-degree segment gets a normal of the right length
00:00 +37: the observer sees exactly what was submitted, before the rewind
00:00 +38: a flush with nothing batched does not call the observer
00:00 +39: the observer fires once per flush, text included
00:00 +40: All tests passed!
```

### `flutter test` (whole package)

```
...
00:03 +259 ~1: .../test/lineweight_test.dart: curves cannot be bypassed the threshold is exclusive, so a circle exactly at 2.0 is not counted
00:03 +260 ~1: All tests passed!
```
(260 passed, 1 pre-existing skip unrelated to this task.)

### `flutter analyze`

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.1s)
```

### `dart format --output=none --set-exit-if-changed .`

```
Formatted 45 files (0 changed) in 0.08 seconds.
```

### `cd packages/jet_cad_2d && CI=true dart test`

```
...
00:03 +770: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +771: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +771: All tests passed!
```
(771 passed — unaffected by this task, run to confirm the other package is
still green.)

## Mutation transcripts (verbatim)

Run via the brief's `cp`/`trap`/`perl` recipe, `flutter test
test/vertices_draw_sink_test.dart` per mutant, restored from `/tmp/t12.dart`
inside the same shell call as the mutation+test. `diff` against the saved
copy after each round confirmed a clean restore; `git status --porcelain`
showed only the intended two files modified afterward.

### T12a — route the fill through `_coveredArgb`

```
perl -0pi -e 's/    final argb = style\.argb;\n    for \(var i = 0; i < triangles\.length/    final argb = _coveredArgb(style.argb, style.lineweightHundredths);\n    for (var i = 0; i < triangles.length/' "$F"
```

Result: **KILLED**

```
00:00 +26: a polygon fill emits exactly the triangles it was handed
00:00 +27: a fill on a hairline layer keeps full alpha
00:00 +27 -1: a fill on a hairline layer keeps full alpha [E]
  Expected: <4281558732>
    Actual: <3425920716>

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/vertices_draw_sink_test.dart 854:5             _fillTests.<fn>

00:00 +27 -1: a polygon fill is baked into the positions, not pushed on the canvas
...
00:00 +39 -1: Some tests failed.

Failing tests:
  .../test/vertices_draw_sink_test.dart: a fill on a hairline layer keeps full alpha
```

Exactly one test failed: `a fill on a hairline layer keeps full alpha`
(the hairline fixture, `_style(argb: 0xFF3366CC, lineweight: 5)` at
`devicePixelRatio: 2.0`). `a polygon fill emits exactly the triangles it was
handed`, which uses the default (non-hairline) lineweight, stayed green under
this mutation — confirming the brief's claim that T12a is killed only by the
hairline fixture, and that a normal-lineweight fixture set would have missed
it. Expected `4281558732` = `0xFF3366CC`; actual `3425920716` = `0xCC3366CC`
— the fade the mutation introduced.

### T12b — give the fan its own step count (`steps = 32`)

```
perl -0pi -e 's/    const theta = 2 \* math\.pi;\n    final steps = _flattenSteps\(deviceRadius, theta\);/    const theta = 2 * math.pi;\n    final steps = 32;/' "$F"
```

Result: **KILLED**

```
00:00 +30: a filled circle and its own outline use the same step count
00:00 +30 -1: a filled circle and its own outline use the same step count [E]
  Expected: <172>
    Actual: <128>
  a different step count makes the fill's silhouette and its own outline disagree, and the disagreement changes with zoom

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test/vertices_draw_sink_test.dart 899:5             _fillTests.<fn>

...
Failing tests:
  .../test/vertices_draw_sink_test.dart: a filled circle and its own outline use the same step count
```

### T12c — drop every third triangle (`i += 6`)

```
perl -0pi -e 's/    for \(var i = 0; i < triangles\.length; i \+= 3\) \{/    for (var i = 0; i < triangles.length; i += 6) {/' "$F"
```

Result: **KILLED**

```
Failing tests:
  .../test/vertices_draw_sink_test.dart: a fill batches with strokes into one flush, not one call each
  .../test/vertices_draw_sink_test.dart: a polygon fill emits exactly the triangles it was handed
```

(Two named tests failed; `a fill batches with strokes into one flush, not one
call each` expected `6`, got `5`.)

All three mutants: **KILLED**, each by a named, printed test failure.

## Anything I was unsure about

- The brief's Step 1 snippet used illustrative helpers (`harness()`, `square`,
  `opaque`, an `observer`-based hairline check) that don't match this file's
  actual conventions (`_sink()`, `_style()`, direct `debugColors()` reads
  pre-flush). I adapted the three required tests to the file's existing
  style and added a few more (residual-baking, empty-triangle-list,
  zero-radius-circle, and the batching test that directly demonstrates the
  fallback is gone) to cover the "allocates nothing per entity" / "one flush"
  claims the brief calls out as the actual point of the task. None of the
  extra tests were needed to kill T12a/b/c — they're there because leaving
  them out would have left the "one batch, not one draw call per fill" claim
  unverified by anything except a passing suite that could pass with the old
  forwarding too.
- I extracted `_flattenSteps` as the brief suggested as an option rather than
  duplicating the expression inline in `fillCircle`. I verified `_flatten`'s
  behavior is byte-for-byte unchanged by confirming every pre-existing
  arc/circle test (which pins exact coordinates and step counts) still
  passes.
