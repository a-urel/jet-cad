# Plan 04 mutation log

Branch: `plan-04/page-grid-rulers`
HEAD: `39c88bd5a5ea34751a25fd0c5088864f977a4c4e`
Date: 2026-09-22
Count: twenty-two named mutants (M-04a…v) plus the tile-cache twin of M-04r — 23 fired, 0 survived.

Discipline: each production file was `cp`-backed up to
`.superpowers/sdd/2026-09-22-page-grid-rulers/mutation-backups/` before the
one-line edit, restored with `cp` from that backup after the run, and
confirmed with `diff -q`. No `git checkout --` was used on any `.dart` file.

---

### M-04a — drop the camera translation from ruler tick placement
file: `packages/jet_cad_2d_flutter/lib/src/ruler_painter.dart:85`, `? cam.worldToScreen(Vector2(world, 0)).x` → `? world * cam.scale`
test: `CI=true flutter test test/ruler_painter_test.dart`
result: FIRED — `major ticks sit at worldToScreen of the lattice, labelled in metres` [E]
```
Expected: a numeric value within <0.000001> of <4.0>
  Actual: <3.9270072992700733>
   Which:  differs by <0.0729927007299267>
```
`00:00 +5 -1: Some tests failed.`
restored: diff clean

### M-04b — drop the camera scale from ruler tick spacing
file: `packages/jet_cad_2d_flutter/lib/src/ruler_painter.dart:85`, `? cam.worldToScreen(Vector2(world, 0)).x` → `? world + cam.worldToScreenMatrix.e`
test: `CI=true flutter test test/ruler_painter_test.dart`
result: FIRED — `major ticks sit at worldToScreen of the lattice, labelled in metres` [E]
```
Expected: a numeric value within <0.000001> of <56.0>
  Actual: <56.10291970802919>
   Which:  differs by <0.10291970802919082>
```
`00:00 +5 -1: Some tests failed.`
restored: diff clean

### M-04c — remove the ladder: major = 64 px / pxPerMm (continuous)
file: `packages/jet_cad_2d/lib/src/geometry/grid_scale.dart:80-81`, `for (final step in ladderFor(unit, floorMm: floorMm)) {` / `if (step * pxPerWorldMm >= kMajorMinPixels) {` → `for (final step in [kMajorMinPixels / pxPerWorldMm]) {` / `if (true) {`
test: `CI=true dart test test/geometry/grid_scale_test.dart` and (per the amendment) `CI=true flutter test test/page_chrome_painter_test.dart`
result: FIRED on both.
`grid_scale_test.dart` — `pick metric: the smallest ladder step at or above 64 px` [E]
```
Expected: <500>
  Actual: <467.1532846715328>
```
seven of eight `pick`/`snapToGrid` tests failed; `00:00 +4 -8: Some tests failed.`
`page_chrome_painter_test.dart` — `major lines sit where the oracle says, anchored at the sheet corner` [E]
```
Expected: <6>
  Actual: <7>
```
and `differential: fifty seeded cameras agree with the literal-ladder oracle` [E]
```
Expected: <7>
  Actual: <8>
trial 1, scale 0.03652213221987167
```
`00:00 +7 -2: Some tests failed.`
restored: diff clean

### M-04d — call `registerComponents` after `components.loadJson` in `decode`
file: `packages/jet_cad_2d/lib/src/codec/json_codec.dart:118`, `registerComponents?.call(doc.components);` moved from before `_loadHeader` to just after `doc.components.loadJson(...)`
test: `CI=true dart test test/codec/page_component_roundtrip_test.dart`
result: FIRED — `the page round-trips typed when the load registers it, and the bytes are stable` [E]
```
Expected: PageComponent:<PageComponent(Letter portrait 1:48.0 at (7350.0, -1230.0), feetInches)>
  Actual: <null>
```
and `decode (the map form) takes the same hook` [E] with the same shape.
`00:00 +1 -2: Some tests failed.`
restored: diff clean

### M-04e — swap portrait and landscape in `effectiveWidthMm`
file: `packages/jet_cad_2d/lib/src/document/page_component.dart:132,134`, both arms of `effectiveWidthMm`/`effectiveHeightMm` swapped
test: `CI=true dart test test/document/page_component_test.dart test/document/page_geometry_test.dart`
result: FIRED — `page_component_test.dart: effective size follows orientation on a non-square sheet` [E]
```
Expected: <215.9>
  Actual: <279.4>
```
`page_geometry_test.dart: the sheet rect is origin plus effective size times D` [E]
```
Expected: <22200>
  Actual: <17850.0>
```
`00:00 +9 -2: Some tests failed.`
restored: diff clean

### M-04f — anchor the grid at world (0, 0) instead of the sheet origin
file: `packages/jet_cad_2d_flutter/lib/src/page_chrome_painter.dart:149`, `cam.worldToScreen(Vector2(p.originX + i * stepMm, minY)).x` → `cam.worldToScreen(Vector2(i * stepMm, minY)).x`
test: `CI=true flutter test test/page_chrome_painter_test.dart`
result: FIRED — `major lines sit where the oracle says, anchored at the sheet corner` [E]
```
Expected: a numeric value within <0.001> of <395.45000000000005>
  Actual: <-611.5>
   Which:  differs by <1006.95>
```
and `differential: fifty seeded cameras agree with the literal-ladder oracle` [E]
```
Expected: a numeric value within <0.001> of <620.96517293893>
  Actual: <593.0402221679688>
trial 0
```
`00:00 +7 -2: Some tests failed.`
restored: diff clean

### M-04g — draw minors regardless of spacing (Ruling 04-7)
file: `packages/jet_cad_2d/lib/src/geometry/grid_scale.dart:86`, `minorMm: minor * pxPerWorldMm >= minorMinPixels ? minor : null,` → `minorMm: minor,`
test: `CI=true dart test test/geometry/grid_scale_test.dart`
result: FIRED — `pick minor is null under the minor threshold` [E]
```
Expected: null
  Actual: <100.0>
```
`00:00 +11 -1: Some tests failed.`
restored: diff clean

### M-04h — snap with truncate instead of round
file: `packages/jet_cad_2d/lib/src/geometry/grid_scale.dart:147-148`, both `.roundToDouble()` → `.truncateToDouble()`
test: `CI=true dart test test/geometry/grid_scale_test.dart`
result: FIRED — `snapToGrid nearest, anchored at the sheet origin, negative side too` [E]
```
Expected: <7850>
  Actual: <7350.0>
```
`00:00 +11 -1: Some tests failed.`
restored: diff clean

### M-04i — formatLength ignores the unit (always mm)
file: `packages/jet_cad_2d/lib/src/geometry/grid_scale.dart:109`, `DisplayUnit.meters => '${_trim(mm / 1000, 3)} m',` → `DisplayUnit.meters => '${_trim(mm, 3)} mm',`
test: `CI=true dart test test/geometry/grid_scale_test.dart`
result: FIRED — `formatLength per unit` [E]
```
Expected: '1.5 m'
  Actual: '1500 mm'
```
`00:00 +11 -1: Some tests failed.`
restored: diff clean

### M-04j — sheet rect ignores scaleDenominator
file: `packages/jet_cad_2d/lib/src/document/page_geometry.dart:10-11`, `page.originX + page.effectiveWidthMm * page.scaleDenominator,` / the height mirror → `page.originX + page.effectiveWidthMm,` / mirror
test: `CI=true dart test test/document/page_geometry_test.dart`
result: FIRED — `the sheet rect is origin plus effective size times D` [E]
```
Expected: <22200>
  Actual: <7647.0>
```
`00:00 +2 -1: Some tests failed.`
restored: diff clean

### M-04k — fitToPage fits the extents
file: `apps/floor_planner/lib/planner_view.dart:85`, `? fitToPage(page, size)` → `? ViewportTransform.fit(widget.document.extents, size)`
test: `CI=true flutter test test/planner_shell_test.dart`
result: FIRED — `the camera is fitted to the real viewport on first layout` [E]
```
Expected: a numeric value within <1e-9> of <0.016377104377104375>
  Actual: <0.017371428571428572>
```
and `the camera is fitted to the page at the drawing area's size` [E]
```
Expected: a numeric value within <1e-9> of <0.016377104377104375>
  Actual: <0.017371428571428572>
```
`00:02 +10 -2: Some tests failed.`
restored: diff clean

### M-04l — PageNotifier ignores CommandUndone
file: `packages/jet_cad_2d_flutter/lib/src/page_notifier.dart:23`, the `CommandUndone(:final touched) ||` line deleted; `CommandUndone() => false,` added as its own arm
test: `CI=true flutter test test/page_notifier_test.dart`
result: FIRED — `follows apply, undo and redo through the stream` [E]
```
Expected: [PageComponent..., PageComponent..., PageComponent...]
  Actual: [PageComponent...]
   Which: at location [1] ... shorter than expected
```
`00:00 +3 -1: Some tests failed.`
restored: diff clean

### M-04m — breaks drawn without the 16 px guard
file: `packages/jet_cad_2d_flutter/lib/src/page_chrome_painter.dart:173-174`, `if (w * cam.scale < kBreaksMinSheetPixels || h * cam.scale < kBreaksMinSheetPixels) {` → `if (false) {`
test: `CI=true flutter test test/page_chrome_painter_test.dart`
result: FIRED — `page breaks tile outward and vanish under a 16 px sheet` [E]
```
Expected: <0>
  Actual: <111>
```
`00:00 +8 -1: Some tests failed.`
restored: diff clean

### M-04n — zoomOf omits D
file: `packages/jet_cad_2d/lib/src/document/page_geometry.dart:17`, `pxPerWorldMm * page.scaleDenominator / pixelsPerPaperMm;` → `pxPerWorldMm / pixelsPerPaperMm;`
test: `CI=true dart test test/document/page_geometry_test.dart`
result: FIRED — `100 % is pixelsPerPaperMm / D` [E]
```
Expected: a numeric value within <1e-12> of <1.0>
  Actual: <0.02>
```
`00:00 +2 -1: Some tests failed.`
restored: diff clean

### M-04o — the panel issues two commands per control
file: `apps/floor_planner/lib/page_panel.dart:52`, `_set` made a block body that executes the same `SetComponentCommand` twice
test: `CI=true flutter test test/page_panel_test.dart`
result: FIRED — `each toggle is exactly one command, and undo reverts the control` [E]
```
Expected: <1>
  Actual: <2>
```
and two more tests (`preset, orientation, unit and swatch each issue one command`, `the scale field commits on submit, refuses junk`) with the same `<1>`/`<2>` shape.
`00:01 +1 -3: Some tests failed.`
restored: diff clean

### M-04p — left ruler reads downward (no y flip)
file: `packages/jet_cad_2d_flutter/lib/src/ruler_painter.dart:97`, `for (var i = i1; i >= i0; i--) {` → `for (var i = i0; i <= i1; i++) {`
test: `CI=true flutter test test/ruler_painter_test.dart`
result: FIRED — `the left ruler reads upward` [E]
```
Expected: a value greater than <580.76>
  Actual: <512.26>
ticks ordered down the bar
```
`00:00 +5 -1: Some tests failed.`
restored: diff clean

### M-04q — floorMm ignored by pick
file: `packages/jet_cad_2d/lib/src/geometry/grid_scale.dart`, inside `ladderFor`'s `if (floorMm != null)` block, the element expression `floorMm * m * math.pow(10.0, k)` → `m * math.pow(10.0, k)` (the floor is no longer used; the branch still runs)
test: `CI=true dart test test/geometry/grid_scale_test.dart`
result: FIRED — `pick a floor is exact when it fits and the ladder climbs from it` [E]
```
Expected: <250>
  Actual: <500.0>
```
also failed `pick imperial divisor is 4 even with a floor` [E]
```
Expected: <304.8>
  Actual: <500.0>
```
`00:00 +10 -2: Some tests failed.`
restored: diff clean

First attempt failed to compile — not counted; Ruling 04-18. The original
edit at `grid_scale.dart:61`, `if (floorMm != null) {` → `if (false) {`,
does not behaviourally kill anything: it breaks null-safety flow analysis
inside `ladderFor` (the branch body still reads `floorMm` unpromoted), so
the suite fails to *load* rather than fails an assertion:
```
Failed to load "test/geometry/grid_scale_test.dart":
lib/src/geometry/grid_scale.dart:64:47: Error: Operator '*' cannot be called on 'double?' because it is potentially null.
          for (final m in _mantissas) floorMm * m * math.pow(10.0, k),
                                              ^
```
`00:00 +0 -1: Some tests failed.` A compile failure is not evidence the
test suite behaviourally distinguishes the mutant from the original, so
this attempt is not counted toward the fired tally.

### M-04r — remove the components skip in SpatialIndex._onChange
file: `packages/jet_cad_2d/lib/src/index/spatial_index.dart:2606`, `if (capability == Capability.components) return;` deleted
test: `CI=true dart test test/index/component_edit_skip_test.dart`
result: FIRED — `a components-only edit on the root reconciles nothing` [E]
```
Expected: <1>
  Actual: <5>
```
`00:00 +3 -1: Some tests failed.`
restored: diff clean

### M-04s — the dispatcher passes Capability.geometry for every change
file: `packages/jet_cad_2d/lib/src/document/undo.dart:117`, `capability: command.capability);` → `capability: Capability.geometry);`
test: `CI=true dart test test/index/component_edit_skip_test.dart`
result: FIRED — `a components-only edit on the root reconciles nothing` [E]
```
Expected: <1>
  Actual: <3>
```
and `the change carries the capability of the command that made it` [E]
```
Expected: [Capability.components, Capability.geometry, Capability.geometry, Capability.components, Capability.components]
  Actual: [Capability.geometry, Capability.geometry, Capability.geometry, Capability.components, Capability.components]
   Which: at location [0] is Capability.geometry instead of Capability.components
```
`00:00 +2 -2: Some tests failed.`
restored: diff clean

### M-04t — iterate the grid over the sheet rect instead of the intersection
file: `packages/jet_cad_2d_flutter/lib/src/page_chrome_painter.dart:96-97`, `math.max(visible.minX, sheet.minX)` / `math.min(visible.maxX, sheet.maxX)` (and the y pair) → `sheet.minX` / `sheet.maxX` / `sheet.minY` / `sheet.maxY`
test: `CI=true flutter test test/page_chrome_painter_test.dart`
result: FIRED — `bounded at kMinScale, kMaxScale, and the intersection is the range` [E]
```
Expected: a value less than or equal to <29.0>
  Actual: <25352>
```
plus `major lines sit where the oracle says, anchored at the sheet corner` and the differential check both failed.
`00:00 +6 -3: Some tests failed.`
restored: diff clean

### M-04u — PageNotifier does not seed in its constructor
file: `packages/jet_cad_2d_flutter/lib/src/page_notifier.dart:12`, `: super(document.components.get<PageComponent>(document.rootHandle)) {` → `: super(null) {`
test: `CI=true flutter test test/page_notifier_test.dart`
result: FIRED — `seeds from the document before any event` [E]
```
Expected: PageComponent:<PageComponent(A4 landscape 1:50.0 at (7350.0, -1230.0), meters)>
  Actual: <null>
```
and `an unrelated edit and an equal value do not notify` [E]
```
Expected: <0>
  Actual: <1>
```
`00:00 +2 -2: Some tests failed.`
restored: diff clean

### M-04v — the point list is the whole buffer, not a sublistView
file: `packages/jet_cad_2d_flutter/lib/src/page_chrome_painter.dart:165`, `Float32List.sublistView(_buffer, start, n)` → `_buffer`
test: `CI=true flutter test test/page_chrome_painter_test.dart`
result: FIRED — `the point list is exactly four numbers per line` [E]
```
Expected: (<15> or <58>)
  Actual: <73>
```
plus three more tests failed (`major lines sit where the oracle says`, the differential check, `minors that coincide with a major are not drawn twice`).
`00:00 +5 -4: Some tests failed.`
restored: diff clean

### Tile-cache twin of M-04r — remove the components skip in TileCache's change handler
file: `packages/jet_cad_2d_flutter/lib/src/tile_cache.dart:1876`, `if (capability == Capability.components) return;` deleted
test: `CI=true flutter test test/tile_invalidation_test.dart`
result: FIRED — `a components-only change drops no tile` [E]
```
Expected: <130>
  Actual: <10>
```
`00:00 +11 -1: Some tests failed.`
restored: diff clean

---

## Tally

23 fired (22 named mutants M-04a…v plus the tile-cache twin of M-04r). 0 survived. All anchors from `task-11-anchors.md` were found exactly as given, at the line numbers stated (re-grepped before each edit; no drift since 9f08c10).

## Extra checks

### Allocation gate 1 — `jet_cad_2d`
```
$ cd packages/jet_cad_2d && CI=true dart test test/invariants/query_allocation_test.dart
00:00 +0: forEachInRect does not allocate in steady state
00:01 +1: forEachInstanceInRect does not allocate in steady state
00:01 +2: pickInto does not allocate in steady state, three instances deep
00:02 +3: snapInto does not allocate in steady state, three instances deep
00:02 +4: pickInto stays local: an over-wide broad phase would blow the time budget
00:02 +5: All tests passed!
EXIT: 0
```

### Allocation gate 2 — `jet_cad_2d_flutter`
```
$ cd packages/jet_cad_2d_flutter && CI=true flutter test test/invariants/paint_allocation_test.dart
00:00 +0: a steady-state frame allocates O(1) per flush, not O(entities)
00:00 +1: flush hands drawVertices the same Paint object every time, not a call-site-local one
00:00 +2: load-time triangulation cost, recorded
LOAD fills=5000 elapsed=65ms
00:00 +3: All tests passed!
EXIT: 0
```

### Untouched-files diff — must be empty
```
$ git diff --stat main..HEAD -- apps/dev_harness_2d packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart packages/jet_cad_2d_flutter/lib/src/draft_painter.dart packages/jet_cad_2d_flutter/lib/src/camera_gesture_detector.dart packages/jet_cad_2d_flutter/lib/src/interaction_layer.dart packages/jet_cad_2d_flutter/lib/src/selection_overlay.dart
(no output)
EXIT: 0
```

### TileCache diff — one hunk, the D13 skip
```
$ git diff --stat main..HEAD -- packages/jet_cad_2d_flutter/lib/src/tile_cache.dart
 packages/jet_cad_2d_flutter/lib/src/tile_cache.dart | 8 +++++---
 1 file changed, 5 insertions(+), 3 deletions(-)
EXIT: 0
```

### dart:ui grep — must print nothing
```
$ grep -rn "dart:ui" packages/jet_cad_2d/lib/src/document/page_component.dart packages/jet_cad_2d/lib/src/document/page_geometry.dart packages/jet_cad_2d/lib/src/geometry/grid_scale.dart
(no output)
EXIT: 1
```
