# Task 2 report: the band in the selection tool

**Status:** DONE_WITH_CONCERNS (all concerns are test-side deviations from the brief's sketch, each explained below; the implementation follows the sketch verbatim).

**Commit:** `8210ef06 feat(floor-plan): a band selects tables in the selection mode` (on `feat/rubber-band`, after `9926758d`).

## What was implemented

- `packages/jet_cad_floor_plan/lib/src/host/floor_plan_types.dart`: `enum FloorPlanFloorDrag { pan, band }` after `FloorPlanLongPress`, with the brief's doc text verbatim. `FloorPlanLongPress.contextMenu`'s doc now names the band as a touch screen's multiple selection.
- `packages/jet_cad_floor_plan/lib/src/service/table_select_tool.dart`:
  - `ServiceOptions` gains `FloorPlanFloorDrag floorDrag` as its last field. `kDefaultServiceOptions.floorDrag` is `pan`.
  - `_Gesture.banding` maps to `ToolPhase.dragging`. New fields: `_reachOnly`, `_bandMode`, `_bandPainter`.
  - `_reachOnly` is set at the down by one extra pick, a finger only.
  - `_startsBand` is checked at the slop, before today's branches. The `banding` move case updates the band's screen end and its mode.
  - `_band` runs at the up: both corners under the camera at the up, then `_bandKeys` (`forEachInstanceInBand` with `snapping()`, kept to `picker.candidates`, groups by the mode's rule), then one `replace`.
  - `onKey` takes every key mid-band; Escape ends the band whatever `idleKeys` says. `_reset` clears `_reachOnly`.
  - `paintOverlay` paints through the kept `SelectionBandPainter` only while banding. The header comment now names RB-2 to RB-5.
  - All of this is the brief's code verbatim, except that `dart format` reflowed the `phase` switch.
- `packages/jet_cad_floor_plan/lib/src/host/floor_plan_view.dart`: the `options` record literal gains `floorDrag: FloorPlanFloorDrag.pan`. Task 3 wires the widget field.
- New tests:
  - `packages/jet_cad_floor_plan/test/service/table_band_test.dart`: RB1, RB2, RB5, RB5b, RB6 to RB15 and RB13b, 15 `testWidgets`.
  - `packages/jet_cad_floor_plan/test/invariants/band_allocation_test.dart`: RB16.
- `jet_cad_2d` and `jet_cad_2d_flutter` are not edited. The M-RB19 mutant was applied to `selection_band.dart` and reverted by copying the file back; its md5 `f83e11a2…` is unchanged and git shows no change.

## Deviations from the brief and why

1. **The three "named exception" test files needed no edit.** `test/service/service_options_test.dart`, `test/host/table_groups_context_test.dart` and `test/host/table_overlay_test.dart` hold no `ServiceOptions` record literal. They pass `serviceMoves:` / `longPress:` to `FloorPlanView(...)`, which is unchanged. `grep -rn "ServiceOptions\|serviceMoves:"` over `test/` finds no record literal. The only literal outside the tool is the one in `floor_plan_view.dart`. No existing test was edited.
2. **`ellTable` is two leaves, not one L polyline.** RB6 as written cannot be met with one polyline in the real index. `SpatialIndex._leafPasses` (`jet_cad_2d/lib/src/index/spatial_index.dart:502-513`) passes a leaf in window mode when **the leaf's own local box, lifted to the world**, is enclosed. One L polyline's local box is the whole 1200 x 1200 square. So "every leaf enclosed" would equal "the instance box enclosed", and M-RB6 could not be told apart.
   - With one polyline, RB6 was red against the correct implementation: `Expected: {SelectionKey(2C)} Actual: {}`.
   - The fixture now holds two bars of the same L: (0..1200 x 0..500) and (0..500 x 500..1200). Base (600, 600), turned 37° at (-6000, -3000), seats 3, as the brief says.
   - RB6 asserts its premise against each leaf's world box: both leaves' boxes are inside the band, the empty quadrant's corner (local 1200, 1200) is outside, and the instance's world box `maxY` is past the band.
   - Only the test fixture changed; the implementation's behaviour did not. The constant's doc comment records why.
3. **RB16 measures against a baseline, and watches `_ByteDataView` as well.** Two findings while building it:
   - **A floor of 3, whatever the frame count.** With no frame at all, the meter reads `{Paint: 2, _NativePath: 1}` in every epoch: the painter's own kept objects, live since the tool was built. This is the meter's documented failure mode 1. Measured: zero frames 3, 1,000 frames 3, another 1,000 frames 3. A literal "≤ 2 in total" is therefore unreachable. The test takes a no-frame baseline epoch and holds the measured epoch's **excess over it** to ≤ 2. The control loop runs after the measure because its live objects otherwise leak into the measured epoch: one early run read `{Paint: 102, _NativePath: 101}`.
   - **The JIT can scalar-replace a per-call `Paint`.** In one mutant run, M-RB19 **survived** with `Paint: 2` over 1,000 frames, while `_ByteDataView` (the `Paint`'s `ByteData`, which escapes to the engine) read 1,002. Another run read `{Paint: 3, _ByteDataView: 946}`. So the watched set is `{'Paint', '_ByteDataView', 'Path', '_NativePath'}`. `Path`'s VM class is `_NativePath` (the meter reports `Path: 0` always), and `Paint`'s is `Paint`.
   - `_Uint8List` (the view's buffer) is not watched: the meter's own round trip makes about 900 of them per epoch (measured 902 to 927).
   - A control loop proves the meter sees ≥ 100 `Paint`, `_ByteDataView` and `_NativePath` when 100 of each are built.
   - Without `--enable-vmservice` the test skips with `vmServiceUnavailableReason` (checked).
4. **Fixture placements** follow the brief; none overlap, so nothing moved. Band rects are computed from the leaves under each table's transform, padded. Premises are asserted in the tests:
   - every band's press is a pick-miss;
   - RB2's press is past a finger's 240 mm reach;
   - RB5b's press misses at reach 0 and hits 2 at reach 240;
   - RB7's chair band misses 1's top, and the quadrant band is under the box's top corner;
   - RB8: the zoom maps the press to the target's corner, and the old press world point misses 2;
   - RB9: the planter is inside;
   - RB10: the chair band misses 4 and 6, and 6 is outside the two-member window.
5. **Mutant mechanics:**
   - M-RB9 (candidate filter dropped) also needed `!locked[h]!` relaxed to `!(locked[h] ?? false)`. Otherwise the planter's missing entry throws a null-check, which would be a crash rather than the behaviour.
   - M-RB6 and M-RB7b are written as box-based takes from `picker.candidates`: `c.box.transformedBy(c.inverse.invert())` enclosed (window) or intersecting (crossing), in place of the band query.

## TDD evidence

**RED.** `cd packages/jet_cad_floor_plan && flutter test --enable-vmservice test/service/table_band_test.dart`, with the record field added but no band in the tool: 13 failed, 2 passed (RB1 and RB5 pin today's behaviour). Excerpts:

- RB2: `Expected: Set:[… 9, 1, 2] Actual: Set:[SelectionKey( 2C)]`. The Shift drag panned.
- RB5b: `Expected: null Actual: Transform2(1.0, 0.0, 0.0, 1.0, 400.0, -600.0)`. The reach-only press moved table 2.
- RB8: `Expected: within 0.000001 of 1700.0 Actual: 500.0`. The band drag panned the camera.
- RB14: `Expected: KeyEventResult.handled Actual: KeyEventResult.ignored`.
- RB15: `Expected: [drawRect, drawRect] Actual: []`.
- RB6, RB7, RB9 to RB13b: selections unchanged or empty where a band should have taken.

All are expected: there was no band, so drags panned, the overlay was empty and keys were ignored.

RB16 was written after the implementation, as the brief's Step 6 orders. Its red is M-RB19 (below).

**GREEN:**
- `flutter test --enable-vmservice test/service/table_band_test.dart test/invariants/band_allocation_test.dart`: `00:03 +16: All tests passed!`
- RB16 alone, 3 runs: `+1: All tests passed!` each.

## Gates

- `packages/jet_cad_floor_plan`:
  - `flutter test --enable-vmservice --file-reporter json:…/fp_run2.json`: exit 0, `02:30 +2000: All tests passed!`
  - `dart run tool/ci/expect_failures.dart --package packages/jet_cad_floor_plan --root packages/jet_cad_floor_plan …/fp_run2.json` (from the repo root): `packages/jet_cad_floor_plan: 2000 tests; the standing failures and skips, exactly`, exit 0.
  - `flutter analyze`: `No issues found!`
  - `dart format --output=none --set-exit-if-changed .`: `Formatted 295 files (0 changed)`, exit 0.
- `apps/floor_planner`, `flutter test`: exit 0, `01:11 +212: All tests passed!`
- `apps/restaurant_demo`, `flutter test`: exit 0, `00:31 +68: All tests passed!`
- `jet_cad_2d` and `jet_cad_2d_flutter` were not changed, so their suites were not re-run.
- `pick_allocation_test`, `query_allocation_test` and `paint_allocation_test` are untouched. `pick_allocation_test` is green in the planner run.
- No `analysis_options.yaml` is in the working tree's changes or the commit.

## Mutants

Each was applied by a script (`scratchpad/mutants.py`: exact-string replace, run the killer with `--plain-name`, restore by `shutil.copyfile` from a copy). The tool's md5 `e21c2876…` and the painter's md5 `f83e11a2…` are unchanged after every run. Lines refer to `test/service/table_band_test.dart` at the commit.

| Mutant | Change | Killer | Failing line / output |
|---|---|---|---|
| M-RB1 | `return band \|\| (!e.isTouch);` (modifier check dropped) | RB1 | 411 `expect(r.paint().calls, isEmpty, reason: 'no band painted')`, Actual 2 calls |
| M-RB2 | `return band \|\| _toggle;` (`!isTouch` dropped) | RB2 | 441 `expect(after.e, isNot(closeTo(before.e, 1)), reason: 'a finger pans')`, Actual 700.0 |
| M-RB5 | `if (_hit != null && !band) return false;` (band starts on a table) | RB5 | 454 `expect(r.paint().calls, isEmpty)`, Actual 2 calls |
| M-RB5b | `_reachOnly = false;` | RB5b | 499 `selectionPreviewTransform isNull`, Actual `Transform2(1,0,0,1,400,-600)` |
| M-RB6 | window takes a candidate whose world box is enclosed | RB6 | 538 `{r.key('9')}`, Actual `{}` |
| M-RB7 | mode not updated mid-band, `_band` uses `_bandMode` | RB7 | 582 `crossing.named('drawRect') hasLength(1)`, Actual 2 |
| M-RB7b | crossing takes a candidate whose world box intersects | RB7 | 570 `r.selection.isEmpty ... 'no leaf touched'`, Actual false |
| M-RB8 | `final a = _pressWorld;` | RB8 | 618 `{r.key('2')}`, Actual `{}` |
| M-RB9 | candidate filter dropped (`passing.add(h)`) | RB9 | 633 the whole-floor set, "larger than expected" (the planter) |
| M-RB10 | `} else {` (lock filter dropped) | RB10 | 647 `isEmpty ... 'locked: nothing'`, Actual false |
| M-RB10b | `const QueryFilter.picking()` | RB10 | 650 `{r.key('7')}`, Actual `{}` |
| M-RB11 | `const String? id = null;` (no group expansion) | RB10 | 659 `{4, 5, 6}`, Actual `{5}` |
| M-RB12 | `BandMode.window => members.any(` | RB10 | 665 `isEmpty`, Actual false |
| M-RB13 | `ctx.selection.toggle(keys)` for the union | RB11 | 678 `{1, 2}`, Actual `{2}` |
| M-RB14 | empty rule swapped (modifier empty clears, plain empty returns) | RB12 | 689 `{r.key('1')}`, Actual `{}` |
| M-RB15 | plain branch `toggle([k])` per key | RB13 | 704 `expect(notified, 1)`, Actual 2 |
| M-RB16 | `case _Gesture.banding: _tap(ctx);` | RB13 | 704 `expect(notified, 1)`, Actual 0 (see note) |
| M-RB17 | band Escape gated `&& idleKeys()` | RB14 | 753 `phase idle`, Actual `dragging` |
| M-RB17b | non-Escape keys mid-band return `ignored` | RB14 | 750 `onKey(_z) handled`, Actual `ignored` |
| M-RB18b | `if (_gesture != _Gesture.banding) return;` removed | RB15 | 775 `paint().calls isEmpty, reason: 'idle'`, Actual 2 calls |
| M-RB19 | `selection_band.dart`: `canvas.drawRect(rect, Paint()..color = ...)` per call | RB16 | `band_allocation_test.dart` final expect: 5 of 5 runs red, Actual 2000, 1888, 945, 1888, 2000 (e.g. `{Paint: 3, _ByteDataView: 946, Path: 0, _NativePath: 1} over 1000 frames, {Paint: 2, _ByteDataView: 2, …} with none`) |

Note on M-RB16: the routed `_tap` on a floor press clears an already empty selection, so the first red is the notification count. The floor-tap recorder assertion later in RB13 (`r.floors isEmpty`) would also fail, but the test stops at the first failure.

## Self-review

- The diff matches the brief's Step 4 code; no other behaviour was touched.
- The extra finger pick runs at a finger's down only. `pick_allocation_test` is untouched and green.
- `_lastTap` is cleared at the slop before `_startsBand`, so a band never completes a double tap (RB13, RB13b).
- A band starts whatever `userCamera` says: `_startsBand` runs before the `_pans` branch, as RB-2 requires. RB4 (the band under `userCamera: false`) is not in this task's test list; the spec places it with RB3, so Task 3 presumably covers both. Not tested here.
- `selectedTables` notifying at most once (RB13's view half) and the absence of `onTableHover` at the view are view-level. Here RB13 checks the `SelectionController` notification count and that the tool's `onTableHover`, `onFloorTap` and `onTableDoubleTap` recorders stay empty.

## Concerns

1. The `ellTable` fixture differs from the brief's constant: two leaves instead of one L polyline. This was forced by the index's per-leaf-box window rule; with the brief's constant RB6 is unsatisfiable. A reviewer may want the spec's RB6 wording, or the plan's fixture, amended to say "each leaf's box".
2. RB16's "≤ 2 in total" is applied to the excess over a no-frame baseline (a constant 5 of the painter's own live objects). `_ByteDataView` is watched alongside `Paint` because the JIT can scalar-replace a per-call `Paint`. Watching `Paint` alone let M-RB19 survive once.
3. The named exceptions in the three test files turned out to be empty (no literals there). This is not a finding, only a mismatch between the plan and the files.
