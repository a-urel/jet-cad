# Task 16, Part A: report

Status: DONE_WITH_CONCERNS (one ported test, TO32, needs Part B; see Concerns).

Commit: `b79df762 feat(plan): PlanServiceView, the service bar and unit overlays` (on `2daafc79`).

## What was implemented

- **A5** `lib/src/service/view/plan_service_bar.dart`: verbatim from the brief (`kServiceBarHeight`, `PlanServiceAction`, `PlanServiceBar`, `validatePlanServiceBar`).
- **A6** `lib/src/service/view/unit_overlays.dart`: a copy of `jet_cad_floor_plan/lib/src/host/table_overlay.dart` with the renames from the brief's table (`PlanUnitOverlay`, `PlanUnitOverlayBuilder`, `PlanOverlaySize`, `PlanOverlayLayout`, `validatePlanOverlayLayout`, `UnitOverlayLayer` marked `@internal`, `PlanUnitOverlayParentData`, `RenderPlanUnitOverlays`; `groupIdsByLabel`; `c.camera`). The `PlanUnitOverlay` class and `_sources` / `_recompute` are the brief's code. Doc comments say unit and label instead of table and number. The render object's body is unchanged.
- **A7** `lib/src/export/editor_page_flows.dart`: `export()` and `exportRunnable` read `controller.activeDocument`. `_exportAllowed` and `_printAllowed` are true in `PlanMode.service`. Task 15's opacity plumbing was already there and is untouched.
- **A8** `lib/src/canvas/plan_canvas.dart`: `PlanCanvas.unitOverlays`, handed to `PlanCanvasView.unitOverlays`.
- **A9** `lib/src/service/view/plan_service_view.dart`: the brief's code verbatim, with two comments reworded so they no longer cite the brief ("this task's plan decision", "see Assumed from earlier tasks"). No code differs from the brief.
- **A1** `test/support/service_fixtures.dart`: verbatim from the brief (`pagePlan`, `kToolbarNumbers`, `toolbarPlanJson`, and the re-exports).
- **A2** `test/support/service_host.dart`: the brief's code, with two import fixes (see Brief mismatches).
- **A3** `test/service/view/plan_service_view_test.dart` (SV-1 to SV-7): the brief's code, with import fixes.
- **A4** the four ported files (details below).

## Brief mismatches found (the committed code won)

1. `PlanMode` lives in `service/service_session.dart` and `plan_controller.dart` does not re-export it. `show PlanMode` is added to `service_host.dart`, the SV test and each ported file. The brief's A2 note anticipated this.
2. In the SV test, `PlanExportDialog` is declared in `export/export_dialog.dart`, not `registries.dart`, so I added `import 'package:jet_cad_2d_plan/src/export/export_dialog.dart' show PlanExportDialog;`. The imports of `units/unit_detail.dart` and `support/test_kit.dart` were unused (`unused_import` is an error in this package) and are removed.
3. `service_host.dart` needed `import 'package:vector_math/vector_math_64.dart' show Vector2;`. Its import of `package:jet_cad_2d/jet_cad_2d.dart` was unused and is removed.
4. The fixture trapezoid's key is `fx.trapezoid.two`, not `test.table.trapezoid` as the brief says. `onSurveyed` compares against `trapezoidTable.key`, as the source did.
5. VE18: the source's `setTablesData({...})` maps to `PlanController.setUnitsData(Map<String, Map<String, String>>)`. The brief names `setUnitData`, which takes one label. Using `setUnitsData` keeps the single `isTrue` expect unchanged. It runs in design, through a `before:` hook of `mount`, before `pumpService`.

## Ported tests

All `expect`s are unchanged except the class names inside expected `toString` text (`FloorPlanServiceBar(...)` became `PlanServiceBar(...)`, and `FloorPlanTableOverlay(...)` became `PlanUnitOverlay(...)`). Each file's header lists what it ports and what it leaves to Part B.

- `test/service/view/service_bar_test.dart` (from `bars_test.dart`):
  - BC1, all eight cases.
  - BT1's service half: the 16 expects, with `skip: 'through the barrel from Part B, Step B7'`. It reads `host.` from `plan_service_bar.dart` imported `as host`. I ran it once with the skip removed and it passed (`00:00 +1: All tests passed!`), then restored the file.
  - BT2's service case. The source's mode loop runs `[PlanMode.service]`.
  - M-H40's service test, and the service half of the [redo, undo, merge, export, split] test.
  - "today's rules inside the subset" and "the selection mode: no bar ...". `canvasIn` is measured from `PlanServiceView`.
  - "the service bar: leading ..." and T2-b's service test.
  - The mergeCandidate group: M-H44 (the line `final host.PlanController hc = c;` goes through the barrel, imported `as host`), S-5, T2-d and "its notifications".
  - T2-c "undo() acts", and T2-e's service half (its loop runs `[PlanMode.service]`).
  - R-5, kept in the source's group "the review fixes ...".
  - Part B ports "the canvas re-measured", the R-3 tests and K1.
- `test/service/view/unit_overlay_test.dart` (from `table_overlay_test.dart`): TO1-TO12, TO15-TO22, TO24-TO31 and TO33, 29 tests in all. TO13, TO14 and TO23 go to Part B as the brief says, and so does **TO32** (see Concerns).
- `test/service/view/view_events_test.dart`: VE1-VE18, 18 tests. VE11 switches to `PlanMode.design` and back to service (the brief says "and back"), then makes the source's one `reason: 'mode switch'` expect after both switches.
- `test/service/view/unit_groups_toolbar_test.dart`: TB1-TB7. The mode is switched to service before the view is mounted.

## TDD evidence

I wrote the library files (A5-A9) before running the new tests. To get honest RED evidence, I moved `plan_service_view.dart` aside and ran the SV test:

RED: `flutter test test/service/view/plan_service_view_test.dart` with the view file moved out:
```
test/service/view/plan_service_view_test.dart:20:8: Error: Error when reading 'lib/src/service/view/plan_service_view.dart': No such file or directory
test/support/service_host.dart:41:5: Error: Type 'PlanServiceView' not found.
test/service/view/plan_service_view_test.dart:64:30: Error: Method not found: 'PlanServiceView'.
```
This is the expected RED, since `PlanServiceView` does not exist. The file was moved back afterwards.

GREEN: `flutter test test/service/view/plan_service_view_test.dart`:
```
00:01 +7: All tests passed!
```
The ported files, each run alone:
- unit_groups_toolbar `00:01 +7: All tests passed!`
- view_events `00:01 +18: All tests passed!`
- unit_overlay `00:02 +29: All tests passed!`
- service_bar `00:01 +22 ~1: All tests passed!` (BT1 skipped)

## Gates (packages/jet_cad_2d_plan)

- A10: `flutter test test/service/view test/canvas test/export test/editor` gave `00:28 +301 ~1: All tests passed!`.
- A10: `flutter test --enable-vmservice` (the whole package) gave `01:09 +1311 ~1: All tests passed!`. The one skip is BT1.
- Allocation files: `flutter test --enable-vmservice test/invariants` gave `00:09 +13: All tests passed!`. They ran, for example `pick_allocation_test.dart: the hall PA5 a pick on the lowest seat's top allocates nothing per seat: every top above it visited`.
- A11: `dart format .`, then:
  - plain `flutter test` gave `00:57 +1304 ~8: All tests passed!` (BT1 plus the 7 allocation tests that need the VM service);
  - `flutter analyze` gave `No issues found! (ran in 4.2s)`;
  - `dart format --output=none --set-exit-if-changed .` gave `Formatted 271 files (0 changed)`, `format exit 0`.
- No new failures. No standing failure appears in this package.
- `git status --short` after the pub operations showed only Part A's files, and no `analysis_options.yaml`.
- Escape trap: the only non-ASCII characters in the new files are the brief's `→` in the bar header and `ğ` in VE18. The VE18 bytes match the source byte for byte (`od -c`: `304 237`). No `\u` or `\x` escapes are in the sources.

## Mutations (on b79df762)

After each mutation, `git checkout -- <file>` and `git diff --quiet -- <file>` exited 0.

| Mutation | Test | Failing line (quoted) |
|---|---|---|
| M-SV-1: both `addListener` lines in `_listen` deleted | SV-1 | `Expected: exactly one matching candidate` / `Actual: _TypeWidgetFinder:<Found 0 widgets with type "InteractionLayer": []>` |
| M-SV-2: `exportName: 'plan'` | SV-2 | `Expected: 'hall'` / `Actual: 'plan'` |
| M-SV-3a: `_exportAllowed() => controller.permissions.export` | SV-3 | `Bad state: No element` at `plan_service_view_test.dart:151:20` (`exports.single`: no export arrived) |
| M-SV-3b: `if (keys && _c.permissions.undo)` on the Undo chords | SV-3 | `Expected: <40556.21778264911>` / `Actual: <41456.21778264911>` (`plan_service_view_test.dart:146:5`) |
| M-SV-4: `final merges = true;` | SV-4 | `Expected: no matching candidates` / `Actual: _KeyWidgetFinder:<Found 1 widget with key [<'service-merge'>]: [` (`:169:5`) |
| M-SV-5: `_unitColourOpacity` returns `kUnitColourOpacity` | SV-5 | `Expected: <0.8>` / `Actual: <0.35>` (`:203:5`) |
| M-SV-6: `... \|\| d.unit.generatedBy != null) continue;` | SV-6 | `Expected: ['12', 'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'B1', 'B2', 'B3', 'B4', 'B5']` / `Actual: ['12']` (`:237:5`) |
| M-SV-7: `_s.host = _host;` deleted | SV-7 | `Expected: ['A1', '12']` / `Actual: []` (`:266:5`) |
| M-SV-B1: `children.add(const SizedBox(width: 8));` deleted | BC1 | `Which: at location ['service-merge'] is <108.0> instead of <116.0>` (`service_bar_test.dart:218:9`) |
| M-SV-B2: `validatePlanServiceBar` returns at once | BT2 | `Expected: <Instance of 'ArgumentError'>` / `Actual: <null>` (`service_bar_test.dart:287:11`) |
| M-SV-O1: `InputClaim(child: built.widget)` became `built.widget` | TO28 | `Expected: empty` / `Actual: ['1', '1']` (`unit_overlay_test.dart:1081:5`) |
| M-SV-O2: `_built.clear();` deleted | TO19 | `Expected: {'1': 2, '2': 2, '3': 2, '4': 2, 'L': 2, '7': 4}` / `Actual: {'1': 1, '2': 1, '3': 1, '4': 1, 'L': 1, '7': 2}` (`unit_overlay_test.dart:813:5`) |
| M-SV-E1: `\|\| !identical(_c.activeDocument, _document)` deleted | VE15 | `Expected: ['layout']` / `Actual: ['layout', 'moved 1']` (`view_events_test.dart:541:7`) |

M-SV-3a turns SV-3 red through a `StateError`, not a `TestFailure`: with service export refused, the settle loop runs out with no export, and `exports.single` throws.

## Self-review

- The names match the shared interfaces and the brief's Produces: `PlanServiceAction`, `PlanServiceBar`, `PlanUnitOverlay`, `PlanUnitOverlayBuilder`, `PlanOverlaySize`, `PlanOverlayLayout`, `PlanServiceView` (every constructor parameter as listed), `kServiceBarHeight`, `validatePlanServiceBar`, `validatePlanOverlayLayout`, `overlayDetailLevel`, `UnitOverlayLayer`, `RenderPlanUnitOverlays`, `PlanUnitOverlayParentData`, and `PlanCanvas.unitOverlays`.
- The old packages are untouched, and the overlay port does not import `jet_cad_floor_plan`.
- The fixtures are not degenerate:
  - embedding plan: turned, mirrored and scaled units 40 m off the origin, with a non-identity camera;
  - Task 5's rows: one turned, one curved;
  - toolbar plan: units turned and mirrored, plus an asymmetric trapezoid.
- Every new SV test has a named mutation that turns it red (table above).

## Concerns

1. **TO32 cannot run on the service view alone, so I left it to Part B.**
   - It is a design-mode test in the source: `controller(design: true)` with `modes: {design}`. It shows and hides a layer through `SetLayerCommand`, which needs `Capability.structure` (`layer_commands.dart:316`). The service copy runs under `DraftPermissions.runtime` (`structure: false`), so the command is refused there.
   - Its assertions are unchanged; it needs `PlanEditor`'s design canvas with `unitOverlayModes: {PlanMode.design}`, which is Part B.
   - The brief listed it in Part A (TO24-TO33). Part B's list should gain TO32.
2. BT1 is skipped as the brief asks. Part B Step B6 must remove the skip and the `plan_service_bar.dart ... as host` import.
