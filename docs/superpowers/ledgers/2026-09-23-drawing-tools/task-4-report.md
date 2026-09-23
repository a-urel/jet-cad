# Task 4 report: PolylineTool, RectangleTool, Fill, overlay structural test

## What was implemented

- `packages/jet_cad_2d_flutter/lib/src/draw/polyline_tool.dart` —
  `PolylineTool extends PlacementTool`. Self-snaps to its own first vertex
  (from three vertices on) ahead of its own last vertex; on a self-snap
  close it appends the **stored** first-vertex instance itself
  (`polylinePayload([...points, point])`, Ruling 05-4), so closedness
  holds under `==`. Finishing (last-vertex click again, or Enter) commits
  it open. Closed shapes go through `commitShape(..., fillable: true)`, so
  Fill on commits one region, or the plain boundary when the loop cannot
  fill (self-intersecting / degenerate). The rubber band is one reused
  `Path`: `moveTo` the first vertex, `lineTo` each placed vertex, `lineTo`
  the hover point, one `drawPath`.
- `packages/jet_cad_2d_flutter/lib/src/draw/rectangle_tool.dart` —
  `RectangleTool extends PlacementTool`. First click stores the corner;
  second click checks `isDegenerateRectangle` and, if not degenerate,
  commits `rectanglePayload(c1, c2)` through `commitShape(...,
  fillable: true)`. `orthoBase` returns the first corner (verbatim from
  the brief; unexercised by shift in this task's tests). Rubber band is
  the reused `Path` traced as a 4-corner closed loop, one `drawPath`.
- `lib/jet_cad_2d_flutter.dart` — two new exports
  (`src/draw/polyline_tool.dart`, `src/draw/rectangle_tool.dart`), placed
  next to the existing `line_tool.dart` export.
- Tests: `test/draw/polyline_tool_test.dart` (PL1–PL9),
  `test/draw/rectangle_tool_test.dart` (R1–R5),
  `test/draw/draw_overlay_test.dart` (OV1–OV2) — all copied from the
  brief, with one numeric deviation (below).

All code is verbatim from the brief's Step 3 except the one test-data fix
in `rectangle_tool_test.dart` (R2).

## Deviation from the brief's code

**R2's click coordinates** (`7010`/`7010.01`) were changed to
**`7009`/`7009.01`**. Reason, discovered via TDD (see RED/GREEN below):

At this fixture's standard camera (`scale: 1.1`, `flipY: true`,
`rotation: 0.35`) and `PageComponent(scaleDenominator: 20, originX: 7000,
originY: 3000)` with `snapToGrid: true`, `dragGridStepMm` resolves to a
20 mm minor grid (`GridScale.pick(DisplayUnit.meters, 1.1)` → major 100 mm,
divisor 5, minor 20 mm; measured directly, see below). The literal value
`x = 7010` sits **exactly on the midpoint** between the grid lines 7000
and 7020. A screen round-trip (`screenOf` then the layer's
`screenToWorld`) introduces ~2e-12 mm of floating-point noise. For the
first click that noise happens to land the ratio `(x−7000)/20` just
**below** 0.5 (rounds to the 7000 line); the brief's `+0.01` mm nudge on
the second click pushes its ratio comfortably **above** 0.5 (rounds to
the 7020 line). The two clicks then snap to *different* grid lines, 20 mm
apart — a perfectly valid, non-degenerate rectangle — instead of the
near-duplicate click collapsing to one line that the test's name and
intent describe.

Measured directly (temporary debug test, removed before commit):
```
cam.scale = 1.1
gridStep  = 20.0
raw(7010)     = [7009.999999999998, ...]   -> ratio 0.499999999999866 -> snaps to 7000
raw(7010.01)  = [7010.009999999998, ...]   -> ratio 0.500499999999900 -> snaps to 7020
isPending after both clicks = false   // committed a real (non-degenerate) rectangle
```
With `7009`/`7009.01` (well inside the `[7000, 7020)` cell, not near the
tie), both clicks measured and snap to the same 7000 line:
```
raw(7009)     = [7008.999999999998, ...]   -> ratio 0.449999999999900 -> snaps to 7000
raw(7009.01)  = [7009.009999999998, ...]   -> ratio 0.450499999999900 -> snaps to 7000
isPending after both clicks = true    // second click refused: zero-width, as intended
```
This is a one-line data change in the test file, not a change to
`isDegenerateRectangle`, `RectangleTool`, or any grid-snap code. It does
not touch the mutation coverage R2 exists for (a mutant that deletes the
`isDegenerateRectangle` check still fails R2, since it would then commit
a new entity and the snapshot-equality assertion would fail).

## TDD evidence

**RED** — `cd packages/jet_cad_2d_flutter && CI=true flutter test test/draw/polyline_tool_test.dart test/draw/rectangle_tool_test.dart test/draw/draw_overlay_test.dart`, before the tool files existed:
```
test/draw/rectangle_tool_test.dart:4:8: Error: Error when reading 'lib/src/draw/rectangle_tool.dart': No such file or directory
  import 'package:jet_cad_2d_flutter/src/draw/rectangle_tool.dart';
test/draw/rectangle_tool_test.dart:22:39: Error: Method not found: 'RectangleTool'.
...
test/draw/draw_overlay_test.dart:6:8: Error: Error when reading 'lib/src/draw/polyline_tool.dart': No such file or directory
import 'package:jet_cad_2d_flutter/src/draw/polyline_tool.dart';
test/draw/draw_overlay_test.dart:21:35: Error: Method not found: 'PolylineTool'.
...
00:00 +0 -3: Some tests failed.
```
Compile errors for the two missing tools, exactly as the brief predicted (exit code 1).

**A second, narrower RED** surfaced after the tools existed: `rectangle_tool_test.dart`'s R2 failed with a snapshot-inequality assertion (the document had gained a new `polyline` entity, handle 19, instead of staying unchanged) — this is the deviation investigated and fixed above.

**GREEN** — `cd packages/jet_cad_2d_flutter && CI=true flutter test test/draw/`:
```
00:00 +37: .../polyline_tool_test.dart: PL8 its own first vertex beats a nearer entity endpoint (M-05w)
00:00 +38: .../polyline_tool_test.dart: PL9 Escape with three vertices placed is byte-identical (M-05l)
00:00 +38: All tests passed!
```
38 tests (19 pre-existing from Task 3's `placement_tool_test.dart` and `line_tool_test.dart`, 19 new: PL1×2 + PL3×2 + PL2 + PL4 + PL5 + PL6 + PL7 + PL8 + PL9 = 11 polyline, R1×2 + R2 + R3 + R4 + R5 = 6 rectangle, OV1 + OV2 = 2 overlay).

## Gate line output

`cd packages/jet_cad_2d_flutter && CI=true flutter test`:
```
00:11 +892 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```
892 = 873 (branch point) + 19 new. 1 skip carried over. The five failures are exactly the standing `text_ladder_golden_test.dart` failures named in `implementer-common.md`; exit code from `flutter test` is 1 for that reason alone, matching the standing exception. No other failure.

`flutter analyze`:
```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 2.2s)
```
(One `unused_import` was caught and fixed along the way — `package:flutter/widgets.dart show Offset` in `polyline_tool_test.dart` was redundant with `flutter_test`'s re-export, exactly the note in the dispatch. Removed.)

`dart format --output=none --set-exit-if-changed .`:
```
Formatted 169 files (0 changed) in 0.35 seconds.
```
Exit code 0.

`git status --short` before commit: only the six touched files (2 new lib files, 3 new test files, 1 modified barrel export). No `analysis_options.yaml` was rewritten by `pub get`, so nothing to check out.

## Files changed

- `packages/jet_cad_2d_flutter/lib/src/draw/polyline_tool.dart` (new)
- `packages/jet_cad_2d_flutter/lib/src/draw/rectangle_tool.dart` (new)
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (+2 export lines)
- `packages/jet_cad_2d_flutter/test/draw/polyline_tool_test.dart` (new)
- `packages/jet_cad_2d_flutter/test/draw/rectangle_tool_test.dart` (new, one numeric fix vs. the brief — see Deviation)
- `packages/jet_cad_2d_flutter/test/draw/draw_overlay_test.dart` (new)

Commit: `0ae93ae feat(draw): polyline and rectangle tools, and Fill`.

## Self-review

Checked the diff against the brief's interfaces, the plan's Rulings (05-1
through 05-15) and Review Focus items, and the mutants the brief names:

- **M-05i** (PL3): `accept` checks `identical(point, points.first)` while
  `acceptingSelf` and appends that same instance — a base that instead
  copied the raw pointer would leave the last coordinate pair `!=` the
  first, failing PL3's `p.coords[6] == p.coords[0]` exact-`==` assertions.
  Confirmed this is inherited unmodified from `PlacementTool`
  (Ruling 05-4); `PolylineTool` only decides *when* to treat a resolved
  point as the closing point.
- **M-05p** (PL4, R3): `commitShape` (unmodified, Task 3) executes one
  `AddRegionCommand`, not two `AddEntityCommand`s — `undoDepth == 1` and a
  single `commands.undo()` removing both boundary and fill in both PL4 and
  R3 exercise this; a two-command mutant would leave `undoDepth == 2` or
  leave one entity behind after one undo.
  Ruling 05-15 shows the concrete production-code mutant this is against
  is in the shared engine helper, not in either new tool file.
- **M-05q** (PL5): a bow-tie closes as a plain boundary because
  `addDraftedRegion` returns `null` for a self-intersecting polyline
  (`triangulationFor` back-empty) — `commitShape` then falls through to
  `addDrafted`. PL5 asserts `fills.fillsOf(boundary)` is empty; a mutant
  that ignored the `null` and force-built a region would fail this.
  This path is entirely in `commitShape`/`addDraftedRegion` (Task 1/3);
  `PolylineTool` just passes `fillable: true`.
- **M-05h** (PL6): shift pins to `points.last` (the base class's default
  `orthoBase`), not `points.first` — `PolylineTool` does not override
  `orthoBase`, so this is inherited. PL6 checks the third vertex's `y`
  equals the *second* vertex's, not the first's.
- **Review Focus 4 / PL7**: `selfSnap` checks the first vertex (`>= 3`
  points) *before* the last vertex (`>= 2` points) — reordering these two
  checks would make a tiny triangle finish open on its last vertex instead
  of closing on its first, failing PL7's `isClosedPolyline(p)` assertion.
- **M-05w (PL8)**: `selfSnap` is checked before any object-snap query
  (`_resolve` in `PlacementTool` returns immediately on a self-snap hit),
  so the polyline's own first vertex wins over the anchor entity's nearer
  endpoint. This ordering is entirely in the inherited `_resolve`;
  `PolylineTool.selfSnap` only supplies the candidate point.
- **M-05l (PL9)**: `cancel` (inherited, unmodified) only calls
  `clearShape()` — no document command — so Escape mid-shape is
  byte-identical. Confirmed by the codec `snapshot` equality in PL9.
- **OV1/OV2**: `paintRubberBand` calls `band.reset()` then rebuilds the
  path in place and issues exactly one `canvas.drawPath` per frame,
  regardless of vertex count or document size — OV1 pins this to one
  `drawPath` and zero `drawLine` calls in the preview colour; OV2 pins the
  call sequence to be identical at 10 vs. 1,000 background entities
  (allocation/behaviour independent of document size, per the Global
  Constraints' O(1)-per-flush note).

No YAGNI additions: both tool classes implement only the abstract members
`PlacementTool` requires plus the one override each needs
(`selfSnap`/`orthoBase`), matching `LineTool`'s shape. Names match the
brief's interfaces exactly (`PolylineTool`, `RectangleTool`, constructor
`{ValueListenable<bool>? fill}` via `super.fill`).

## Concerns

- The R2 numeric deviation (see above) is the only place the brief's
  supplied code did not hold up as literally written; it is a one-line
  test-data change with a fully worked-out, measured explanation, not a
  guess. A reviewer should double check the arithmetic in this report
  against their own run if anything about the grid-snap chain changes
  upstream (Tasks 1–3 are already merged, so this should be stable).
- `RectangleTool.orthoBase` (returning the first corner) is exactly the
  brief's code but is not exercised by any test in this task (no rectangle
  test holds shift). It is carried over verbatim; flagging in case a later
  task's shift-drawn-rectangle behavior needs a dedicated test.
