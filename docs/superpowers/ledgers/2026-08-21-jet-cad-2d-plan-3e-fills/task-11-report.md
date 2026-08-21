# Task 11 report: `DrawSink.fillPolygon` and `fillCircle`

## What changed

- `packages/jet_cad_2d_flutter/lib/src/draw_sink.dart` — added
  `fillPolygon`/`fillCircle` to the `DrawSink` interface (doc comments per the
  brief, verbatim), `FillPolygonOp`/`FillCircleOp` (`==`/`hashCode` over
  `points`, `triangles`, `style`), and implementations on `RecordingDrawSink`
  (copies `points`/`triangles`, does not retain the caller's buffers — same
  hazard as `polyline`) and `NullDrawSink` (counts only).
- `packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart` — implemented
  both ops per the brief: `fillPolygon` builds a closed `Path` from `points`
  (ignoring `triangles`), fills, then restores `_paint.style` to `stroke`;
  `fillCircle` does the same via `drawCircle`. **Dropped the brief's
  `_popTransform()` calls** — that method does not exist anywhere in this
  file; every other primitive (`polyline`, `circle`, `arc`) pushes the
  transform once per residual and lets `endResidual` pop it, so I followed
  that existing convention instead. Noted below as a brief/tree mismatch.
- `packages/jet_cad_2d_flutter/test/draw_sink_test.dart` — added the four
  tests from the brief (adapted to the corrected `SpyCanvas` API per the
  controller ruling: `spy.named('drawPath')`, `.paintingStyle`, `.length`
  instead of `lastPaintStyle`/`drawPathCount`), plus: `fillPolygon copies the
  caller buffers`, `fillCircle records centre, radius and style`, `fill ops
  compare by value`, `fillPolygon closes the path`, `fillPolygon with fewer
  than 3 points draws nothing`, `fillCircle draws a filled circle`,
  `fillCircle leaves the paint on stroke afterwards`, and extended the
  existing `NullDrawSink counts every op` test to cover the two new ops.

### Files outside the brief's scope, touched only to keep the tree compiling

`DrawSink` is `implements`ed by three other classes/switches not listed in
the brief, and adding two abstract methods broke all of them:

- `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart` —
  `VerticesDrawSink` did not implement the new methods. Added `fillPolygon`/
  `fillCircle` that flush the pending stroke batch (same ordering hazard as
  `text`) and forward to `_fallback` (`CanvasDrawSink`), with a
  `TODO(Task 12)` comment — the brief says triangle batching for this backend
  is Task 12's job, and this task must not do it early.
- `packages/jet_cad_2d_flutter/test/rig/rig_support.dart` — `TextKeySink`
  (a no-op measurement sink) needed the two new overrides as no-ops.
- `packages/jet_cad_2d_flutter/test/support/differential.dart` and
  `packages/jet_cad_2d_flutter/test/support/vertices_differential.dart` —
  both have an exhaustive `switch (op)` over `DrawOp` that needed new cases:
  `differential.dart`'s `flatten` maps a fill to a `DrawnItem` (`'fillPolygon'`
  / `'fillCircle'`, `closed: true`); `vertices_differential.dart`'s ink
  sampler treats a fill like text — not batched, falls to the fallback sink —
  so it's a no-op `break`.

No `analysis_options.yaml` changes; `git status --porcelain` checked before
every commit-adjacent step.

## Suite output — `jet_cad_2d_flutter`

`test/draw_sink_test.dart` alone (28 tests, all new/changed ones included):

```
00:00 +0: RecordingDrawSink captures ops in order with residual-local points
00:00 +1: RecordingDrawSink polyline copies the caller buffer
00:00 +2: RecordingDrawSink polyline reads count points, not the whole buffer
00:00 +3: RecordingDrawSink ops compare by value, which is what the oracle rests on
00:00 +4: RecordingDrawSink a text op records its string, style handle and resolved style
00:00 +5: RecordingDrawSink text ops compare by value over all three fields
00:00 +6: RecordingDrawSink two recordings of the same fill compare equal
00:00 +7: RecordingDrawSink a different triangulation of the same outline is a different op
00:00 +8: RecordingDrawSink fillPolygon copies the caller buffers
00:00 +9: RecordingDrawSink fillCircle records centre, radius and style
00:00 +10: RecordingDrawSink fill ops compare by value
00:00 +11: NullDrawSink counts every op and keeps nothing
00:00 +12: flatten turns a text op into an origin and two unit images
00:00 +13: flatten flatten with a pure scale, as a sanity check on the brief
00:00 +14: CanvasDrawSink beginResidual pushes the affine as a column-major 4x4
00:00 +15: CanvasDrawSink endResidual restores the canvas
00:00 +16: CanvasDrawSink stroke width is a paper quantity, divided out of the residual
00:00 +17: CanvasDrawSink a width that scales away becomes a hairline, not a negative
00:00 +18: CanvasDrawSink a degenerate residual does not produce a NaN width
00:00 +19: CanvasDrawSink polyline draws the points it was given, and closes when asked
00:00 +20: CanvasDrawSink circle and arc reach the canvas as circles and arcs
00:00 +21: CanvasDrawSink point reaches the canvas as an axis-aligned rect in screen space, not a rotated cap
00:00 +22: CanvasDrawSink the canvas sink fills the path and does not stroke it
00:00 +23: CanvasDrawSink the canvas sink leaves its paint on stroke afterwards
00:00 +24: CanvasDrawSink fillPolygon closes the path
00:00 +25: CanvasDrawSink fillPolygon with fewer than 3 points draws nothing
00:00 +26: CanvasDrawSink fillCircle draws a filled circle
00:00 +27: CanvasDrawSink fillCircle leaves the paint on stroke afterwards
00:00 +28: All tests passed!
```

Full `flutter test` (whole package), tail:

```
00:03 +239 ~1: .../test/vertices_differential_test.dart: the sink inks every primitive the reference walk draws
00:03 +240 ~1: .../test/vertices_differential_test.dart: the same holds at 4.5e6 with the view over one nested instance
00:03 +241 ~1: .../test/vertices_differential_test.dart: the sink inks nothing the painter did not ask for
00:03 +242 ~1: .../test/lineweight_test.dart: paper-space width survives a 0.1x and a 10x instance identically
...
00:03 +253 ~1: All tests passed!
```

253 tests passed, 1 skipped (pre-existing `--tags rig` gate, unrelated to
this task — confirmed by grepping the skip reason: "run explicitly: flutter
test --tags rig --run-skipped").

`flutter analyze`: `No issues found! (ran in 1.1s)`
`dart format --output=none --set-exit-if-changed .`: `Formatted 45 files (0 changed)`

## Suite output — `jet_cad_2d` (untouched by this task, verified green)

```
00:02 +767: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +768: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +769: test/invariants/query_allocation_test.dart: snapInto does not allocate in steady state, three instances deep
00:02 +770: test/invariants/query_allocation_test.dart: pickInto stays local: an over-wide broad phase would blow the time budget
00:03 +771: test/invariants/query_allocation_test.dart: (tearDownAll)
00:03 +771: All tests passed!
```

`dart analyze`: `No issues found!`
`dart format --output=none --set-exit-if-changed .`: `Formatted 110 files (0 changed)`

## Mutation transcripts

Each mutation was applied with `python3 -c` string replacement inside one
shell call, tested, then restored from a `/tmp` copy inside the same call —
never `git checkout`.

**T11a — leave `_paint.style` on fill after `fillPolygon`** (removed the
`_paint.style = PaintingStyle.stroke;` restore line):

```
00:00 +23: CanvasDrawSink the canvas sink leaves its paint on stroke afterwards
  the canvas sink leaves its paint on stroke afterwards
00:00 +23 -1: CanvasDrawSink the canvas sink leaves its paint on stroke afterwards [E]
  The test description was: the canvas sink leaves its paint on stroke afterwards
00:00 +27 -1: Some tests failed.
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink the canvas sink leaves its paint on stroke afterwards
```
Verdict: **kill**.

**T11b — drop `triangles` from `FillPolygonOp`'s `==`**:

```
00:00 +7: RecordingDrawSink a different triangulation of the same outline is a different op
00:00 +7 -1: RecordingDrawSink a different triangulation of the same outline is a different op [E]
00:00 +27 -1: Some tests failed.
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: RecordingDrawSink a different triangulation of the same outline is a different op
```
Verdict: **kill**.

**T11c — draw the polygon unclosed** (removed `_scratch.close()`):

```
00:00 +24: CanvasDrawSink fillPolygon closes the path
00:00 +24 -1: CanvasDrawSink fillPolygon closes the path [E]
00:00 +27 -1: Some tests failed.
  /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/draw_sink_test.dart: CanvasDrawSink fillPolygon closes the path
```
Verdict: **kill** (caught by the test I added for this specifically, since
the brief's own test set does not check closure).

After each mutation, the mutated file was restored from its `/tmp` backup and
`git status --porcelain` confirmed no stray diff before moving on.

## Unsure / brief-vs-tree mismatches

1. The brief's `CanvasDrawSink.fillPolygon`/`fillCircle` snippet calls
   `_popTransform()`, which does not exist on `CanvasDrawSink` — no method by
   that name is defined anywhere in the file, and no other primitive
   (`polyline`, `circle`, `arc`) pops per-op; they push once per residual via
   `_pushTransform()` and let `endResidual()` do the single `restore()`. I
   dropped the two `_popTransform()` calls to match that convention rather
   than invent a new pop-per-op mechanism the rest of the sink doesn't use.
2. The brief's test snippets construct `CanvasDrawSink(canvas: spy,
   pixelsPerPaperMm: kLogicalPixelsPerMm)`, but the real constructor also
   requires `measurer` and `textStyleOf`. Used the existing `setUp` in
   `draw_sink_test.dart` (which already supplies both) instead of a bespoke
   construction per test.
3. `DrawSink` turned out to have three more implementers/exhaustive switches
   the brief didn't mention (`VerticesDrawSink`, `TextKeySink` in
   `rig_support.dart`, and the switch in `vertices_differential.dart`). All
   three needed minimal, uncontroversial additions to keep both `flutter
   test` and `flutter analyze` green; none of them do real fill work — they
   either no-op, forward to the fallback, or classify for the differential
   oracle the same way `text` already does. Flagging in case Task 12's brief
   assumed `VerticesDrawSink` was still non-compiling/untouched going in.
