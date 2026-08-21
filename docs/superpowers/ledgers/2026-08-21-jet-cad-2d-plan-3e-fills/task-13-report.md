# Task 13 report: the painter draws fills, and counts the ones it skips

## What changed

- `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`
  - Added `int get fillCount` / `int get skippedFillCount`, both backed by
    fields reset per frame in `paint()` alongside `_screenSpaceLeaves` and
    `_anisotropicCurves`. `fillCount` is produced in addition to the brief's
    `skippedFillCount` because Task 16's measurement rig reads
    `painter.fillCount`.
  - Added `_drawFill`, wired from `_drawLeafComposed`'s `EntityKind.fill`
    case. Circle boundaries keep the residual path (`fillCircle`, fanned by
    the sink); polyline boundaries go through the screen-space route
    (points carried into screen space, `fillPolygon` under a bare
    translation residual), matching how each boundary kind draws its own
    outline.
  - Guarded `boundaryPayload.scalars.isEmpty` on the circle branch (Ruling
    3): a malformed circle-boundary fill with no radius is now counted as a
    skip instead of throwing `RangeError` on the frame path.
  - The pre-existing `EntityKind.fill` cases in `_emit` are now documented
    as unreachable, in the same style as the point/line/polyline and
    text/attrib cases already there.

- `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart`
  - `_leaf`'s fill switch case now draws `fillCircle`/`fillPolygon`, reusing
    the boundary resolution already present for `entityBounds` (not a
    painter/reference-walk shared helper — that resolution predates this
    task and is local to `_ReferenceWalk`, per Task 1-12).
  - Written independently of `DraftPainter._drawFill`, per Ruling 2 and
    Plan 3c's Ruling 28: a comment at the case marks this so a later reader
    does not "fix" the duplication.

- `packages/jet_cad_2d_flutter/test/fill_render_test.dart` (new): the five
  tests from the brief, verbatim, plus local `squareLoop`/`region`/
  `paintOnce`/`paintAgain` helpers (none of these existed in the flutter
  package; `region` mirrors `jet_cad_2d/test/document/region_command_test.dart`'s
  helper, which lives in the other package and cannot be imported across
  packages).

## Suite output

`packages/jet_cad_2d_flutter`:
```
$ flutter test
...
00:03 +265 ~1: All tests passed!

$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.2s)

$ dart format --output=none --set-exit-if-changed .
Formatted 46 files (0 changed) in 0.09s
$ echo $?
0
```
(`~1` above is a pre-existing skip in the suite, unrelated to this task.)

`packages/jet_cad_2d`:
```
$ CI=true dart test
...
00:03 +771: All tests passed!

$ dart analyze
Analyzing jet_cad_2d...
No issues found!

$ dart format --output=none --set-exit-if-changed .
Formatted 110 files (0 changed) in 0.19s
$ echo $?
0
```

## Allocation gate

```
$ flutter test test/invariants/paint_allocation_test.dart
00:00 +0: a steady-state frame allocates O(1) per flush, not O(entities)
00:00 +1: flush hands drawVertices the same Paint object every time, not a call-site-local one
00:00 +2: All tests passed!
```

## Mutation transcripts

All five mutations were applied to `lib/src/draft_painter.dart` via a
`cp` backup + Python patch + `flutter test test/fill_render_test.dart` +
`cp`-restore, each inside one shell call; every restore was verified with
`diff` against the backup before moving on. `git status --porcelain` was
clean of `analysis_options.yaml` throughout.

**T13a — defer every fill to the end of `paint()` (draws it after its
boundary):**
```
00:00 +0 -1: a region draws the fill before its boundary [E]
  Expected: a value less than <1>
    Actual: <4>
  draw order is ascending handle value and the fill holds the lower one; if
  this inverts, the fill paints over its own outline
...
00:00 +3 -1: the painter walks fills and the reference walk agrees [E]
  Expected: <2>
    Actual: <1>
  the painter missed 1 of 2 reference ops, first unmatched:
  polyline(115.00,585.00)...
```
Named kill: **a region draws the fill before its boundary** (plus a second,
unlisted casualty: the differential test — expected, since deferring fills
also breaks the oracle comparison).

**T13b — hand `trianglesFor(boundary) ?? Int32List(0)` to the sink instead
of skipping:**
```
00:00 +1 -1: an unfillable boundary is skipped and counted, not handed to a sink [E]
  Expected: empty
    Actual: WhereTypeIterable<FillPolygonOp>:[
              FillPolygonOp:FillPolygonOp([0.0, 0.0, 570.0, -570.0, 570.0, 0.0, 0.0, -570.0, 0.0, 0.0], [])
            ]
...
00:00 +2 -2: skippedFillCount is per frame, not a running total [E]
  Expected: <1>
    Actual: <0>
```
Named kill: **an unfillable boundary is skipped and counted, not handed to a
sink**.

**T13c — replace every `_skippedFills++;` with a no-op comment:**
```
00:00 +1 -1: an unfillable boundary is skipped and counted, not handed to a sink [E]
  Expected: <1>
    Actual: <0>
```
Named kill: **an unfillable boundary is skipped and counted, not handed to a
sink**.

**T13d — drop the `_skippedFills = 0;` reset from `paint()`:**
```
00:00 +3 -1: skippedFillCount is per frame, not a running total [E]
  Expected: <1>
    Actual: <2>
```
Named kill: **skippedFillCount is per frame, not a running total** (the
running-total signature Ruling 44 warns about: two frames, one skip each,
read as 2).

**T13e — triangulate the circle boundary instead of fanning it (fake
3-point `fillPolygon` in place of `fillCircle`):**
```
00:00 +2 -1: a circle boundary draws a fillCircle, never a triangulated polygon [E]
  Expected: an object with length of <1>
    Actual: WhereTypeIterable<FillCircleOp>:[]
```
Named kill: **a circle boundary draws a fillCircle, never a triangulated
polygon**.

**T13f** (shared helper between painter and reference walk): not applied —
recorded as a review item per the brief, not a mutation. Both
implementations were written independently from the start; the comments at
each fill case say so.

After every mutation the file was restored and diffed byte-for-byte against
the pre-mutation backup before the next mutation ran; the final `flutter
test` / `flutter analyze` / `dart format` run above was taken against that
fully restored state.

## Concerns / things I was unsure about

- The brief's test snippet calls `expectPainterSupersetOfReference(doc)`
  with one argument, but the real helper in `test/support/differential.dart`
  takes `(painter ops, reference ops, viewport, {edgeBandPx})`. I used the
  existing call shape from `differential_test.dart`:
  `expectPainterSupersetOfReference(paintToRecording(doc),
  referenceToRecording(doc), kViewport)`. This is the same oracle the brief
  names, just spelled the way every other test in the package spells it.
- `paintOnce`/`paintAgain`/`region`/`squareLoop` do not exist anywhere
  importable from `jet_cad_2d_flutter`'s test tree (the closest, `region` in
  `jet_cad_2d/test/document/region_command_test.dart`, lives in the other
  package). I defined local equivalents in `fill_render_test.dart` rather
  than adding them to `test/support/fixtures.dart`, since the brief's Files
  list names only the test file as new and fixtures.dart is shared by many
  other tests I did not want to touch.
- T13a's mutation (deferring fills to end-of-frame) is a bigger patch than
  the other four one-line mutations, since draw order for a single fill vs.
  its boundary is otherwise already guaranteed by ascending-handle traversal
  established in earlier tasks — there is no single-line change inside
  `_drawFill` alone that inverts it. I judged this the most faithful way to
  reproduce "draw the fill after the boundary" as a real bug shape (a
  batching mistake) rather than a synthetic one.
