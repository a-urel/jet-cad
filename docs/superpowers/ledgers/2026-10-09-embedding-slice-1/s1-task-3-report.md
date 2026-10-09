# Slice 1, Task 3 — the overlay layer, non-interactive (G-5, G-6, G-7, H-8): report

**Commit:** `b420493` on `claude/exciting-pasteur-9m22jv` (parent `6c742b4`), not pushed.

## Files

| File | What |
|---|---|
| `packages/jet_cad_floor_plan/lib/src/host/table_overlay.dart` (new) | Public: `final class FloorPlanTableOverlay` (`detail`, `selected`, `focused`, `status`, `detailLevel`; public `const` constructor, `==`, `hashCode`, `toString`), `typedef FloorPlanTableOverlayBuilder`, `enum FloorPlanOverlaySize { natural, box }`, `final class FloorPlanOverlayLayout` (`anchor`, `size`, `maxNaturalSize` 200×120, `hideBelowScale` 0, `detailBreakpoints` `[]`, `interactive` false; `const`, `==`, `hashCode`, `toString`). Internal: `validateOverlayLayout`, `overlayDetailLevel`, the widget `TableOverlayLayer`, its `_OverlayStack` / `_OverlaySlot` / `_OverlayChild`, `FloorPlanOverlayParentData` and `RenderFloorPlanOverlays`. |
| `lib/src/host/floor_plan_controller.dart` | `@internal List<Handle> tableDetailInstances`: the instance of each `tableDetails` entry, index for index, built in the same pass and cached with it (`_detailsOf` now fills both). Nothing public changed. |
| `lib/src/planner_view.dart` | `Widget? tableOverlays` slot: the last child of the canvas `Stack` (after the selection overlay), inside `InteractionLayer` / `CameraGestureDetector`, wrapped in `Positioned.fill(ClipRect(...))`. |
| `lib/src/host/service_view.dart` | `Widget? tableOverlays`, forwarded to its `PlannerView`. |
| `lib/src/planner_shell.dart` | `Widget? tableOverlays`, forwarded to its `PlannerView`. |
| `lib/src/host/floor_plan_view.dart` | `tableOverlayBuilder`, `tableOverlayLayout = const FloorPlanOverlayLayout()`, `tableOverlayModes = const {FloorPlanMode.selection}`, documented; builds a `TableOverlayLayer` for the selection mode's `ServiceView` and for the design mode's `PlannerShell` when the builder is given and the mode is in the set; validates the layout at each build when a builder is given. |
| `lib/jet_cad_floor_plan.dart` | `export 'src/host/table_overlay.dart' show FloorPlanOverlayLayout, FloorPlanOverlaySize, FloorPlanTableOverlay, FloorPlanTableOverlayBuilder;` |
| `test/host/barrel_test.dart` | B1's pinned set gains the four names; **B5** appended (the four names through the barrel alone). No other line changed. |
| `test/host/table_overlay_test.dart` (new) | TO1–TO18, over `embedding_fixture.dart`. |

No existing test was edited apart from `barrel_test`'s pinned set and the appended B5. `jet_cad_2d` and `jet_cad_2d_flutter` are untouched.

## The render object's design (`RenderFloorPlanOverlays`)

**Children and keys.** `TableOverlayLayer` builds one child per numbered table with geometry (`detail.center != null`), in `tableDetails` order (ascending handle = draw order): `_OverlaySlot(key: ValueKey(instance), slot: i, child: RepaintBoundary(child: <cached _OverlayChild>))`. The slot is a `ParentDataWidget` that writes the child's index into the box cache. Keyed by instance, so the two `7`s keep two elements. The whole stack is `IgnorePointer(RepaintBoundary(_OverlayStack))`, so a camera frame repaints only the layer's own layer.

**The box cache.** The state turns each overlay's `detail.corners` (world, already computed by Task 1's cached `tableDetails`) into one `Float64List` of 8 doubles per slot, at the rate of the values (plan, selection, focus, statuses, groups, detail level), never per frame. The render object gets it as `corners`; a new list marks layout.

**The per-frame pass (camera listener).** The render object listens to the `CameraController` (attach/detach). `_measure` maps each slot's four corners through the camera's six coefficients (read once) into `_boxes` (`minX, minY, maxX, maxY` per slot), a `Float64List` reused and grown only when the slot count grows (`debugAllocations++`). `_place` writes each child's offset into **mutable `dx`/`dy` doubles in its `FloorPlanOverlayParentData`** and a `shown` flag: natural — `boxMin + a·boxSize − a·childSize` with `a = (anchor + 1) / 2` (`Align`'s rule); box — the box's top left. No `Vector2`, no `Offset`, nothing per table.

- `natural`: children are laid out with `BoxConstraints.loose(maxNaturalSize)`, `parentUsesSize: true`, in `performLayout`, which a camera change does not trigger; the listener calls `markNeedsPaint` + `markNeedsSemanticsUpdate` (or `markNeedsLayout` once, when the scale rises above `hideBelowScale` and the children were never laid out).
- `box`: the listener calls `markNeedsLayout` (+ semantics); `performLayout` lays out only the shown children, tight to their screen box. It skips recomputing when the camera value and size are the ones the listener already placed (`_placedAt`, `_placedIn`, `_stale`), so the pass runs once per frame.

**Culling.** `shown` is false below `hideBelowScale` (then nothing is laid out or painted), for a slot out of range, for a natural child not yet laid out, and when the child's rectangle misses `Offset.zero & size`. Box children that are not shown are not laid out (they keep their last size).

**Paint, hit test, transform.** All three read `dx`/`dy`. `paint` paints shown children only; the framework's `paintChild` needs an `Offset`, so `paint` keeps the last one in the standard `BoxParentData.offset` and makes a new one only when the place moved (`debugPaintOffsets`): one per painted overlay per camera frame, none for the culled — P-4's "O(overlays on screen) of paint". `hitTestChildren` walks shown, laid-out children in reverse paint order with `addWithPaintOffset(Offset(dx, dy))` (call rate). `applyPaintTransform` is `translateByDouble(dx, dy, 0, 1)`, so `localToGlobal` (and `tester.getRect` in the tests) is right as soon as the listener has run. `visitChildrenForSemantics` visits shown children only.

**The builder-diff.** The state recomputes every `FloorPlanTableOverlay` on `revision`, `selectedTables`, `tableFocus`, `tableStatuses`, `tableGroups`, `groupStatuses`, and on the camera **only when the detail level changes** (`overlayDetailLevel`, an indexed loop, no iterator). If the value list and instance list are equal to the last ones, nothing happens; otherwise `setState`. `build` keeps a `Map<Handle, _Built(value, widget)>`: a table whose value is `==` to the cached one gets the **identical** `_OverlayChild` widget, so Flutter does not rebuild it and the builder is not called; a changed table gets a new `_OverlayChild`, which calls the builder in its own `BuildContext` (so a host's `Theme.of` dependency rebuilds just that overlay). `didUpdateWidget` clears the cache when `builder != oldWidget.builder`, so another function builds every table; a host rebuild with the same function builds none. A detail crossing changes every value, so every overlay is built once. A source that notifies while the tree is being built or laid out is deferred to the end of the frame.

**Effective status:** `groupStatuses[groupIdsByNumber(tableGroups)[number]] ?? tableStatuses[number]`, the status painter's rule.

## Decisions the spec left open

1. **`selected` is by number** (`selectedTables.value.contains(number)`), not by instance: it is the host's notion, and `selectedTables` notifies only on a change (the `SelectionController` also notifies on hover). With a shared number both `7`s read selected when one is.
2. **`status` is computed the same way in both modes.** In the design mode nothing is drawn, but a host that asks for design-mode overlays still sees its statuses.
3. **Natural children are laid out regardless of their position** (G-6 says "neither laid out (`box`) nor painted"); only below `hideBelowScale` are they not laid out. Natural culling tests the widget's own rectangle, not the table's box, so a badge larger than a far-zoomed table does not pop while it still overlaps the canvas.
4. **Validation** cannot run in a `const` constructor, so `FloorPlanView.build` throws the `ArgumentError` (only when a builder is given). Besides the breakpoints (finite, positive, strictly ascending) it also rejects a negative or non-finite `hideBelowScale` and a negative or non-finite `maxNaturalSize`.
5. **A builder returning null** gets a `SizedBox.shrink` child (zero size, never shown).
6. **`interactive`** exists and is documented, but the layer ignores pointers whatever it says until Task 4.
7. **`FloorPlanTableOverlay` has a public `const` constructor** (like `FloorPlanTableDetail`'s), so a host can build one in its own tests.
8. **The paint `Offset`** is excluded from `debugAllocations` and counted separately as `debugPaintOffsets` (see above); the reviewer may prefer to fold it in.
9. **Handles stay internal:** `tableDetailInstances` is `@internal` on the controller; no handle crosses the barrel.

## Mutants (applied, seen red, restored)

A script copied the file aside to the scratchpad, replaced exactly one occurrence, ran `flutter test test/host/table_overlay_test.dart`, restored the file from the copy and compared it byte for byte (`restored: True` every time; `git status` clean of them afterwards). No `git checkout`. Red lines copied from the run logs.

| Mutant | Edit | Killer | Red line |
|---|---|---|---|
| M-H8 | `_onCamera`: `if (level != _level) _onSource();` → `setState(_built.clear);` | **TO2** (also TO1, TO4, TO15, TO16) | TO2 `Expected: <7>` / `Actual: <21>`; TO1 `Expected: {'1': 1, '2': 1, '3': 1, '4': 1, 'L': 1, '7': 2}` / `Actual: {'1': 3, '2': 3, '3': 3, '4': 3, 'L': 3, '7': 6}` |
| M-H9 | `breakpoints[i] <= scale` → `<` | **TO3** | `Expected: <2>` / `Actual: <1>` (camera exactly 0.5, breakpoints [0.25, 0.5, 1.0]) |
| M-H10 | the screen box from corners 0 and 2 only (`k += 2`): exact only for an unrotated box | **TO7** (also TO9, TO12) | TO7 `Expected: a numeric value within <0.000001> of <111.96152422706655>` / `Actual: <171.96152422706655>` (table 1, 30°) |
| M-H11 | `IgnorePointer(` → `IgnorePointer(ignoring: false,` | **TO8** | `Expected: <0>` / `Actual: <1>` (the badge's `onTap` fired) |
| M-H12 | box `performLayout`: `if (data.shown)` → `if (true)` | **TO9** | `Expected: not a numeric value within <0.000001> of <355.2000000000007>` / `Actual: <355.2000000000007>` (table 4, off the canvas, relaid to its new box) |
| M-H18 | `if (built == null \|\| built.value != value)` → `if (true)` | **TO5** (also TO6, TO15, TO16) | `Expected: {'1': 2, '2': 1, '3': 1, '4': 1, 'L': 1, '7': 2}` / `Actual: {'1': 2, '2': 2, '3': 2, '4': 2, 'L': 2, '7': 4}` |
| M-H19 | `_onCamera` without `_measure(camera)` (boxes stale after a camera change) | **TO1** (also TO7–TO13, TO16) | `Expected: a numeric value within <0.000001> of <373.55057958016914>` / `Actual: <648.9705908728556>` |
| M-H19b(design default) | `tableOverlayModes = const {FloorPlanMode.selection, FloorPlanMode.design}` | **TO13** | `Expected: no matching candidates` / `Actual: _TypeWidgetFinder:<Found 7 widgets with type "Badge": [` |

M-H9 was run a second time after the breakpoint loop was made indexed (same killer, same red line).

## The tests (`test/host/table_overlay_test.dart`)

Fixture: `embeddingPlanJson()`, `embeddingCamera()` set after the first fit, or `cameraAt(s)` (scale exactly `s`, world (39,500, −25,500) at the top left) where a test needs an exact scale or tables 1–3 all on the canvas. Expected rectangles come from `embeddingBox` through each table's own transform and the camera, by hand (`canvasBox`), plus the `InteractionLayer`'s top left; `closeTo` 1e-6 px.

- TO1 seven overlays (1, 2, 3, 4, L, 7, 7), two for `7`, each centred on its screen box; after `panBy` + `zoomBy` still (M-H19); 7 builder calls total.
- TO2 50 pans and zooms: 0 builder calls (M-H8).
- TO3 detail level on the breakpoint (M-H9), 0 to 3.
- TO4 a crossing: one call per table; non-crossing zooms: none.
- TO5 one table's status: one call (M-H18); the group status over the table's.
- TO6 `selected`, `focused` follow the controller.
- TO7 box = the screen AABB of 30°, mirrored 90° and scaled tables, after a zoom too (M-H10).
- TO8 a tap on a badge: the badge's `onTap` not called, `onTableTap(['1'])`, selected (M-H11).
- TO9 box: an off-canvas table is not laid out across a zoom; layouts = shown count; panned on it is, at its box (M-H12).
- TO10 natural: across 50 camera changes in steady state `debugAllocations` +0, `debugChildLayouts` +0, `debugPaintOffsets` ≤ the painted count, some culled, 0 builder calls (the plain check).
- TO11 `hideBelowScale`: hidden and not laid out below, laid out and placed at the bound, hidden again below.
- TO12 an `anchor` of (0.5, −1) places as `Align` does.
- TO13 design mode: none by default (M-H19b(design default)); with `{design}` seven, placed on the design canvas; none after switching to the selection mode.
- TO14 no builder: no `TableOverlayLayer`, no `RenderFloorPlanOverlays`, either mode (the plain check; `view_test` / `view_palette_test` pass unedited).
- TO15 a host rebuild with the same builder: no call, same `State`; `resetLayout`: every overlay remounted (documented lifetime, pinned); another builder: every table.
- TO16 a service drag: the overlay stays during the drag and moves 80 px on the drop; one call for that table.
- TO17 bad layouts throw (`validateOverlayLayout`, and the view through `takeException`); no builder → unused.
- TO18 the value types' `==`, `hashCode`, `toString`, defaults.

## Gates (real tails, `export PATH=/root/sdk/flutter/bin:$PATH CI=true`, on the tree committed as `b420493`)

```
### packages/jet_cad_floor_plan :: flutter test
test-exit 0
04:37 +1490: All tests passed!
### packages/jet_cad_floor_plan :: flutter analyze
No issues found! (ran in 4.9s)
### apps/restaurant_demo :: flutter test
test-exit 0
00:24 +39: All tests passed!
### apps/restaurant_demo :: flutter analyze
No issues found! (ran in 4.5s)
### apps/floor_planner :: flutter test
test-exit 0
01:34 +212: All tests passed!
### apps/floor_planner :: flutter analyze
No issues found! (ran in 5.0s)
### dart format --output=none --set-exit-if-changed .
Formatted 250 files (0 changed) in 1.32 seconds.
packages/jet_cad_floor_plan format-exit 0
Formatted 4 files (0 changed) in 0.06 seconds.
apps/restaurant_demo format-exit 0
Formatted 47 files (0 changed) in 0.21 seconds.
apps/floor_planner format-exit 0
### packages/jet_cad_2d :: dart test --file-reporter json:<s>/e.json
engine test-exit 1
### dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d --root packages/jet_cad_2d <s>/e.json
packages/jet_cad_2d: 1255 tests; the standing failures and skips, exactly
compare-exit 0
### packages/jet_cad_2d_flutter :: flutter test --file-reporter json:<s>/r.json
render test-exit 1
### dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d_flutter --root packages/jet_cad_2d_flutter <s>/r.json
packages/jet_cad_2d_flutter: 1363 tests; the standing failures and skips, exactly
compare-exit 0
```

The planner's count went from 1471 to 1490: 18 overlay tests and B5. `git status` showed only this task's files before the commit; no `analysis_options.yaml` was touched or committed.

## Findings

- **F-1, the paint `Offset`.** Flutter's `PaintingContext.paintChild` takes an `Offset`, so a camera frame creates one per painted overlay (none for the culled, none on a repaint without movement). The frame pass itself creates nothing. The spec's "O(overlays on screen) of paint" covers it; `debugAllocations` (0 per frame, TO10) does not count it, `debugPaintOffsets` does. Flag for the reviewer: if "0 per table" is meant to include paint, it cannot be met through `paintChild`.
- **F-2, M-H10's killer.** The spec names "a 45° table"; the fixture's 45° table (`5`) is on the hidden layer and gets no overlay. The 30° table `1` (and the mirrored and scaled ones) kill the mutant the same way.
- **F-3, M-H12's killer reads a stale size.** At the first frame the fit shows the whole page, so table 4's box child is laid out once; the killer zooms with 4 off the canvas and checks its size is *not* the new box's. A culled box child keeps its last size until it comes back (documented in the render object).
- **F-4, the mode-switch listener.** A `setMode` bumps `revision` synchronously, so the outgoing layer recomputes once for the new plan before it is disposed (harmless, one O(tables) pass). Sources that notify during build or layout are deferred to the end of the frame; no test reaches that branch.
- **F-5, hit testing is implemented but unreached** in this task (`IgnorePointer`); Task 4 exercises it (M-H16, M-H17).
- **F-6, the design mode's clip.** The design mode's `tableOverlays` sits inside the rulers' frame like the canvas, so a badge never paints over a ruler (TO13 places it on the design canvas).
