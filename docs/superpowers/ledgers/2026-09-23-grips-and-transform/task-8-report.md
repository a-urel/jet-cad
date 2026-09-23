# Task 8 report: the overlay (grips, rotation grip, preview, reshape path, snap markers)

Status: DONE
Commit: f6810fb feat(render): overlay grips, rotation grip, preview, snap markers (on b7de33a)

## What was implemented
- `lib/src/snap_marker.dart` (new): `drawSnapMarker(Canvas, Offset, SnapKind?, {grid, paint})`, verbatim from the brief. Each kind draws a fixed shape: endpoint square, midpoint triangle (apex up), center circle, quadrant diamond, insertion square plus cross, intersection X, grid `+`. The raw point draws nothing, and so do perpendicular, tangent and nearest.
- `lib/src/selection_overlay.dart`: replaced whole with the brief's text. I diffed it against the original: the only removed lines are the ones the brief changes (imports, `tools.active.paintOverlay`, and `_drawPointCross`'s signature and body). The new paint order is:
  1. the rebased world pass: outlines, then `tool.paintWorldOverlay`;
  2. the preview pass through `_preview = worldToScreen ∘ T ∘ translate(origin)`, composed in doubles;
  3. the screen pass: point crosses, preview crosses at `T(p)`, grips, the hot grip, the rotation grip and its stem, then `tool.paintOverlay`.
  - Grips are drawn by `drawRawPoints` from exact-size reused `Float32List`s (Ruling 03-10), and the painter reads them from `tools.context.grips` (Ruling 03-4).
- `lib/src/select_tool.dart`, edited as the brief says:
  - `import 'snap_marker.dart'`;
  - three paint fields after `_cursor`;
  - a drag branch at the head of `paintOverlay` that draws the guide and the marker;
  - `paintWorldOverlay`, `_paintGuide` and `_reshapePath` after `_drawDashedRect`.
  - Nothing from Task 7 needed adapting. The brief uses only `_drag`, `_phase` and `_dragPoint`, and `_pressRef` and the cursor notifier are untouched.
- `lib/jet_cad_2d_flutter.dart`: `export 'src/snap_marker.dart';` before `src/snap_settings.dart`.
- Tests: `test/snap_marker_test.dart` (K1) and `test/selection_overlay_grips_test.dart` (P1, P2, P4, P5, P6, P8), taken verbatim except for the deviations below.

## Deviations from the brief (test code only; the production code is verbatim apart from `dart format`)
1. **The colour comparisons in `selection_overlay_grips_test.dart`.** Every `c.color == kXColor` and `expect(x.color, kXColor)` became `c.color?.toARGB32() == kXColor.toARGB32()`, and a two-line comment on this sits above `main`.
   - Why: `Paint.color` reads back through float32, so for a channel like 0x1E/255 the read-back `Color` is not `==` the constant, even though both print the same.
   - This caused every overlay-test failure after the implementation first landed, for example `Expected: Color:<...0.1176, 0.4353, 0.9098...> Actual: Color:<...0.1176, 0.4353, 0.9098...>`, and the preview/marker/guide filters returned empty lists.
   - `toARGB32()` is the house idiom: `selection_overlay_test.dart:262`, `ruler_painter_test.dart:93-109`.
2. **The reshape stroke width in P6 (M-03aj).** `closeTo(kPreviewStrokePixels / scale, 1e-12)` became an exact comparison against `Float32List.fromList([kPreviewStrokePixels / scale])[0]`.
   - Why: `Paint.strokeWidth` is stored as float32, and 1.5 / 1.1 is not float32-exact. The observed value was `Actual: <1.3636363744735718>` against `1.3636363636363635`, a difference of 1.08e-8.
   - Narrowing the expected value the same way keeps the comparison exact, so it still catches a missing division by the scale.
   - The 02 tests only ever compare float32-exact widths (2/4, 1.5/2), which is why they never hit this.

## TDD evidence
RED: `CI=true flutter test test/snap_marker_test.dart test/selection_overlay_grips_test.dart` exited 1.
- `test/snap_marker_test.dart:5:8: Error: Error when reading 'lib/src/snap_marker.dart': No such file or directory`, and `Method not found: 'drawSnapMarker'`.
- M-03u test: `Expected: an object with length of <2>  Actual: [Instance of 'RecordedCall']`. Only the one outline transform was recorded.
- Grips test: `Expected: an object with length of <2>  Actual: []`. There was no `drawRawPoints` yet.
- M-03ad test: `Expected: an object with length of <1>  Actual: WhereIterable<RecordedCall>:[]`. There was no rotation grip yet.
- Point cross: `Expected: an object with length of <2>  Actual: []`.
- Reshape: `Expected: a value greater than <2>  Actual: <-1>`. There was no preview path.
- Stretch marker: `Expected: an object with length of <1>  Actual: []  an endpoint won: a square`.

These were the expected failures: the module was missing, and the new overlay passes did not exist yet.

GREEN, after the implementation and the two test deviations: `CI=true flutter test test/snap_marker_test.dart test/selection_overlay_grips_test.dart test/selection_overlay_test.dart test/select_tool_drag_test.dart` printed `00:00 +39: All tests passed!` and exited 0. Every 02 overlay test passes unedited.

## Named mutants fired
In each case I backed the file up with `cp`, restored it from the copy, and `diff` then exited 0.
- **M-03u (preview is `matrix ∘ T`).** The mutation was `pe = origin.x + t.e; pf = origin.y + t.f`. The M-03u test goes RED: `Expected: a numeric value within <0.000001> of <108.1085453175474>  Actual: <4394.605694677852>`.
- **M-03v (drawRect per grip).** The mutation adds a per-grip `canvas.drawRect(...)` and removes the stretch `drawRawPoints`. The grips test goes RED: `Which: at location [17] is 'drawRect' instead of 'drawRawPoints'`.

## Gate line (jet_cad_2d_flutter)
- `CI=true flutter test` exited 1 with `00:12 +846 ~1 -5: Some tests failed.` The only failures are the five standing `test/golden/text_ladder_golden_test.dart` rungs 1–5 (RenderBackend.canvas). That is 839 + 7 new tests = 846 passing, plus 1 skip.
- `flutter analyze` printed `No issues found!` and exited 0.
- `dart format --output=none --set-exit-if-changed .` printed `Formatted 159 files (0 changed)` and exited 0.

## Files changed
- packages/jet_cad_2d_flutter/lib/src/snap_marker.dart (new)
- packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart
- packages/jet_cad_2d_flutter/lib/src/select_tool.dart
- packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart
- packages/jet_cad_2d_flutter/test/snap_marker_test.dart (new)
- packages/jet_cad_2d_flutter/test/selection_overlay_grips_test.dart (new)

## Self-review
- A band drag never sets `_drag`, so the new `paintOverlay` drag branch cannot hide the band.
- A rotate's `base` is its pivot (`GripDrag.rotate` sets `base.setFrom(pivot)`), so the guide runs from the pivot to the pointer, and a rotate draws no marker.
- The frame path during a move or rotate allocates only the fixed buffers, which are reallocated at selection-change rate. A reshape frame builds one `Path`, which Ruling 03-12 allows.
- The commit trailer check (`grep -c "Co-Authored-By: Claude"`) printed 1, and `git status --short` was clean after the commit. No `analysis_options.yaml` was touched.

## Concerns
None beyond the two recorded test deviations. Both are needed because `Paint` stores its fields as float32, and neither weakens a named mutant.
