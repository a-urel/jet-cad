# Task 3 report: the view's option, through real pointers

Status: DONE (one pin noted, RBV6). Commit: e6ff7337 `feat(floor-plan): FloorPlanView.floorDrag`.

## Implemented
- `FloorPlanView({..., FloorPlanFloorDrag floorDrag = FloorPlanFloorDrag.pan})` after `longPress`, field documented per the brief; the options record passes `floorDrag: widget.floorDrag` (read at each press through the existing `options: () => ...` closure).
- Barrel: `FloorPlanFloorDrag` added to the `show` list of `floor_plan_types.dart`.
- `test/host/barrel_test.dart` enumerates the barrel's names (B1): `'FloorPlanFloorDrag'` added as the named exception.
- New `test/host/band_view_test.dart` (RBV1-RBV8, 8 tests) on a real `FloorPlanView`: own plan (`bandPlan()`): tables 1 (turned a quarter, mirrored), 2, 3 (locked layer), 4 (unnumbered), 5 and 6 (group 'g', 5 turned 3 quarters), 7 (hidden layer), a planter; the camera is the view's own fit (y-flipped, scaled, off the origin). All positions fractional offsets from the sheet centre.

## Files
- packages/jet_cad_floor_plan/lib/src/host/floor_plan_view.dart
- packages/jet_cad_floor_plan/lib/jet_cad_floor_plan.dart
- packages/jet_cad_floor_plan/test/host/barrel_test.dart
- packages/jet_cad_floor_plan/test/host/band_view_test.dart (new)

## TDD evidence
RED (before the implementation), `flutter test --enable-vmservice test/host/band_view_test.dart` from packages/jet_cad_floor_plan:
```
test/host/band_view_test.dart:156:19: Error: No named parameter with the name 'floorDrag'.
                  floorDrag: floorDrag,
...
00:00 +0 -1: Some tests failed.
```
GREEN (after): `00:05 +14: All tests passed!` (band_view_test + barrel_test); the band file alone `+8: All tests passed!`.

## Gates
- `flutter test --enable-vmservice` (packages/jet_cad_floor_plan, whole suite, run before the last edit that removed one unused import line from the new test): `02:34 +2008: All tests passed!`. After that edit the new file and barrel_test re-ran green.
- `flutter analyze`: `No issues found!`
- `dart format --output=none --set-exit-if-changed .`: `Formatted 296 files (0 changed)`
- `apps/floor_planner` `flutter test`: `+212: All tests passed!`
- `apps/restaurant_demo` `flutter test`: `+68: All tests passed!`
- `git status` clean after the commit; no analysis_options.yaml touched.

## Mutants (each applied, seen red, reverted by copying the saved file back; `git diff` afterwards showed only the intended files)
- M-RB3 (view passes `pan` always): RBV1 red at band_view_test.dart:219 (`Expected {1,2} Actual {5}`); also RBV2 (:281), RBV3 (:302), RBV5 (:381), RBV6 (:412), RBV7 (:436). RBV4 stayed green under it (pan: nothing bands) which is why RBV4 now carries a premise band (below).
- M-RB3b (`banding` mapped to `ToolPhase.idle`): RBV4 red at :345 (`Expected: empty, Actual: [(2, Offset(654.7, 398.0))]` -- the secondary click opened a menu mid-band); RBV1 red at :268 (`Expected {1} Actual {5}`: the tap after the cancelled band does not select).
- M-RB4 (`_startsBand` returns false when `!_pans`): RBV2 red at :281 (`Expected {1,2} Actual {5}`); only RBV2 fails.
- M-RB21 (`_startsBand` false when `longPress == contextMenu`): RBV7 red at :444 (`Expected {1,2} Actual {1}`); only RBV7 fails.
- Extra, M-RB17 at the view (band Escape gated on `idleKeys()`): RBV4 red at :336 (`Expected {5} Actual {1,2}`: Escape under `shortcuts: false` no longer ends the band).

## Findings and deviations
- RBV4 Escape under `shortcuts: false` DOES reach the tool: the key event comes through the focused canvas (a press asks for the focus). Evidence: the premise idle Escape leaves the selection `{5}` (idleKeys false), while Escape mid-band ends the band so the up changes nothing; and the M-RB17 mutant above turns exactly that red. So no concern on this item.
- RBV4 mode switch: the brief says "nothing selected"; the selection is carried across the mode switch, so with `{5}` preselected the test asserts `{5}` (band dropped, selection as it was). Stronger than "empty" for a preselected state; deviation noted.
- RBV4 got two additions after M-RB3 showed it vacuous under `pan`: a premise band (no Escape) that selects `{1,2}`, and after the mid-band secondary click (a stylus with the secondary button, since a second mouse pointer of the same device is awkward) the band is asserted to go on and finish `{1,2}`.
- RBV6 (zone focus) is a pin, not a mutant's killer: the tool never sees the focus, so M-RB20 has no place to be applied. It also sets a status on 2 and a group status on 'g'; a second band over the group takes `{5,6}` whole.
- RBV7 uses the table-2 top's left edge from the symbol's geometry (top spans x 300..1500 about base 900), minus 10 px of screen; chairs lie within 225 units of the middle so 10 px left of the top is clear of them. A reach-only finger there bands (right to left, to table 1: `{1}`, table 2 not touched), a tap there selects table 2 (`onTableTap` '2'), a finger on the top moves it (undoDepth +1).
- Touch drags: `glide` moves in <=12 px steps with a pump between so the hold-back releases on the second step; two-finger pan and the mid-band second finger use separate `createGesture`s via `startGesture`.
- RBV1's fit reset uses `c.fitToView()` (no `fitToPlan` exists).

## Self-review
- No existing public signature changed; `floorDrag` is named, optional, default `pan`. No handle or component type crosses the barrel.
- Existing tests unedited except barrel_test's name set (the named exception).
- Only mutants named in the brief plus one extra were used; none left applied.

## Concerns
None blocking.
