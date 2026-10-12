# Report: plan colours Slice 2, Task 4 (export and print carry the colours, PC-7)

Status: DONE (one commit, `f0be47cb`, on `feat/plan-colors-slice-2`).

## What was implemented

- `lib/src/colors/table_color_underlay.dart` (new): `tableColorUnderlay(DraftDocument, double opacity)`, as the brief
  specifies (alpha `round(255 * opacity)`; `TableSurvey` order = ascending instance handle; `FloorPlanTableColor.colorValue`
  null skips (uncoloured, unknown name, kept payload); `document.tables.layers[node.layer]` not visible skips;
  `PolygonTop` closed + `triangulateSimplePolygon`, skipped when empty; `CircleTop`; `node.transform` as placement).
- `export_bytes.dart`: `exportBytes` and `exportPdfBytes` take `tableColorOpacity = kTableColorOpacity` and pass
  `underlay:` to `exportPagePng` / `exportPagePdf`.
- `page_flows.dart`: `exportOnce` and `printOnce` take `tableColorOpacity` (default 0.35); `PageFlows` gains
  `double Function() tableColorOpacity = _defaultOpacity` (optional, so `view_test.dart` / `page_flows_test.dart`
  construct it unedited), read in `export` and `print` at the call.
- `floor_plan_view.dart`: `_flowsFor` passes `_tableColorOpacity` (new private method): ambient `FloorPlanTheme`
  extension `.merge(widget.theme)`, else `widget.theme`, else 0.35 (the scope's own resolution).
- `floor_plan_controller.dart`: `exportPlan(choice, {name, double? tableColorOpacity})`, `printPlan({printer, name,
  double? tableColorOpacity})`; a given value that is not finite or outside [0, 1] throws
  `ArgumentError.value(v, 'tableColorOpacity', 'must be in [0, 1]')` synchronously, before `_pageFlow`; docs say where
  the opacity comes from.
- `test/colors/table_color_export_test.dart` (new): EX1..EX5 (+ EX3b, a premises test).

## Files

- packages/jet_cad_floor_plan/lib/src/colors/table_color_underlay.dart (new)
- packages/jet_cad_floor_plan/lib/src/export/export_bytes.dart
- packages/jet_cad_floor_plan/lib/src/host/page_flows.dart
- packages/jet_cad_floor_plan/lib/src/host/floor_plan_view.dart
- packages/jet_cad_floor_plan/lib/src/host/floor_plan_controller.dart
- packages/jet_cad_floor_plan/test/colors/table_color_export_test.dart (new)

## Tests

The fixture is the Task 3 fill tests' (imported with `show` from `test/service/table_fill_test.dart`: `fillDoc`,
`fillJson`, `specs`, `insideTop`, `composite`, `controllerOver`, `pumpPlan`, ...): nine tables, all turned and mirrored
at 38 m+ off the origin; asymmetric off-centre quadrilateral tops (A, C, U, H, M, R) beside off-centre circles (B, K);
teal/purple/"magenta"; U unnumbered, K locked, H hidden, R inside a teal room; page 1:50 A4 landscape. Expected pixels are
forward arithmetic from literals (`composite`, and `pixelAt` which is RC8's page-number formula), sampled at `insideTop`
(off the number label, which sits at the base point outside the top).

- Premises: fixture shape (turned, mirrored, names, layers).
- EX1: `tableColorUnderlay(doc, 0.35)`: six fills A,B,C,U,K,R in that (ascending) order; argb `(89<<24)|rgb`; placement
  == the instance's transform (per element, and turned); polygon `xy` == the quad's literal ring with first point
  repeated, `count` 5, 6 triangle indices all < count; circles (600, 300, 400); none for H, M, N (matched by
  placement); alphas 153 / 255 / 0 for 0.6 / 1 / 0.
- EX2: PNG via `exportBytes` at 96 dpi: A, C, U teal@89 over white (0xA6D6D1), B and K purple@89, N, H, M white,
  the room's tint alone, R = teal@51 over purple@89.
- EX3: `controller.exportPlan(png)` with no view: default and 0.35 (alpha 89), 0.6 (153) for A, B, K, 1 (opaque), 0
  (white, room tint stays); 1.5, -0.1, NaN, Infinity throw `ArgumentError` for `exportPlan` and `printPlan`
  synchronously, `pageFlowReady` stays true, the printer is not called, and the next export runs.
- EX3b: `printPlan` PDFs (trailer `/ID` blanked, it is random per write): graphics-state `/ca` alphas `0.34902` by
  default and for 0.35, `0.6` for 0.6, `0` for 0; equal bytes for equal opacity.
- EX4: a `FloorPlanView` with `theme: FloorPlanTheme(tableColorOpacity: 0.6, statusFillOpacity: 0.8)`, `onExportDialog`
  answering PNG, Export driven by Cmd+E and Print by Cmd+P (FakePagePrinter): export pixel alpha 153, print `/ca 0.6`.
  Then, with no flows rebuilt: a host rebuild with 1 (opaque), with a theme lacking the field (0.35), with no theme
  (0.35), the ambient `ThemeData` extension alone (0.6), the view's other field over the ambient (0.6 kept), the view's
  1 over the ambient 0.6.
- EX5: the differential: the design canvas (`pumpPlan`, white page, light) vs the PNG export at the default opacity:
  A, B, C, U, K, R each within 1 per channel, and neither equal to the paper.

### RED

First run of `flutter test --enable-vmservice test/colors/table_color_export_test.dart` before any lib change: compile
errors, e.g. `test/colors/table_color_export_test.dart:236:40: Error: No named parameter with the name
'tableColorOpacity'.` (and the missing `table_color_underlay.dart` import) -> `Some tests failed ... loading`.

### GREEN

`flutter test --enable-vmservice test/colors/table_color_export_test.dart` -> `00:02 +7: All tests passed!`
(premises, EX1, EX2, EX3, EX3b, EX4, EX5), after the three small test fixes listed under Deviations.

## Gates (all green)

- `packages/jet_cad_floor_plan`: `flutter test --enable-vmservice --file-reporter json:<run.json>` -> `02:08 +1977: All
  tests passed!`; from the repo root `dart run tool/ci/expect_failures.dart --package packages/jet_cad_floor_plan --root
  packages/jet_cad_floor_plan <run.json>` -> `packages/jet_cad_floor_plan: 1977 tests; the standing failures and skips,
  exactly`. `flutter analyze` -> `No issues found!`. `dart format --output=none --set-exit-if-changed .` -> `Formatted 293
  files (0 changed)`.
- `apps/floor_planner`: `flutter test --enable-vmservice` -> `00:38 +212: All tests passed!`; analyze `No issues found!`;
  format `47 files (0 changed)`.
- `apps/restaurant_demo`: `flutter test --enable-vmservice` -> `00:17 +68: All tests passed!`; analyze `No issues
  found!`; format `9 files (0 changed)`.
- `jet_cad_2d` / `jet_cad_2d_flutter` untouched (edited only in Task 1). `analysis_options.yaml` not committed (git status
  shows only the six task files). Existing tests unedited.

## Mutants (each applied, killer run, seen red, reverted exactly; originals copied aside and `diff`ed clean after)

Command each time: `cd packages/jet_cad_floor_plan && flutter test --enable-vmservice test/colors/table_color_export_test.dart`

| Mutant | Change | Red |
|---|---|---|
| M-C7 (floor plan) | both `placement: node.transform` -> `Transform2.identity()` | EX1 (`Expected: a numeric value within <1e-9> of <-0.4999...>  Actual: <1.0>`), EX2/EX3/EX5 (`Expected: a value less than or equal to <1>  Actual: <89>`), EX4 (`Actual: <153>`) |
| M-C8 (export) | `final alpha = 255;` | EX1 (`Expected: <1493207419>  Actual: <4278225275>`), EX2 (`Actual: <166>`), EX3 (`<166>`), EX3b (`Expected: contains '0.34902'  Actual: Set:['1', '0.2']`), EX4 (`<102>`), EX5 (`<166>`) |
| M-PC7-a | the `layers[node.layer] ... !l.visible` check deleted | EX1 (`Expected: an object with length of <6>`), EX2 (`Actual: <89>`, the hidden table's pixel) |
| M-PC7-b | `exportPlan` passes `kTableColorOpacity` instead of its parameter | EX3 only (`Actual: <64>` at 0.6) |
| M-C23 | `PageFlows.export` passes `kTableColorOpacity` (`tableColorOpacity()` not called) | EX4 (`Actual: <64>`) |

Extras (not in the brief), both red then reverted:
- `PageFlows.print` passes the constant: EX4 (`Expected: contains '0.6'  Actual: Set:['0.34902', '1', '0.2']`).
- `_tableColorOpacity` ignores the ambient extension (`final theme = widget.theme;`): EX4 (`the ambient 0.6: 0xa6d6d1, want
  0x66b8b0`).

## Deviations (brief's helper references vs the real API; intent kept)

- The brief's RC8 reference: RC8 uses its own `fixture()` and a local `pixelAt`; I reused its formula but took the
  fixture from Task 3's `table_fill_test.dart` (imported with `show`), so the export tests and the canvas tests describe
  one plan. Coupling note: a change to that file's exported helpers breaks this test's imports.
- EX4: "drive its Export as `page_flows_test.dart` drives it": that file uses its own `pumpFlows`/`chord`/`letRun`;
  I wrote local equivalents (Cmd+E and Cmd+P with `sendKeyDownEvent`, `runAsync` waits) rather than import them, and used
  `themeAnimationDuration: Duration.zero` (a `ThemeData` swap otherwise animates the extension through `lerp`, which
  made the first ambient leg read 0.35: a test fix, not a code finding).
- `_flowsFor`: the brief's inline expression became a private method `_tableColorOpacity` with an extra `mounted`
  guard: `PageFlows.export` calls it after the dialog's `await`, when the view may be gone (PF20); an unmounted State's
  `context` must not be read, so a gone view reads its own `widget.theme`. Behaviour while mounted is exactly the brief's.
- EX3b added (PDF alphas) so the Print leg of `printPlan` is pinned; PDFs are not byte-identical per write
  (random trailer `/ID`), so the comparison blanks it, as Task 1's `page_underlay_test` does.
- Test names mention only the brief's mutant ids.

## Self-review

- `tableColorUnderlay` mirrors the fill painter's rules (visible layer, known colour, same top via `tableTopOf`,
  ascending survey order); it does not need the number label or a status (the sheet shows colour only, no status).
- Frame-path non-negotiables: nothing touched in the painters or the query path; the underlay is built once per export,
  not per frame. `query_allocation_test` / `paint_allocation_test` untouched and green in the full run.
- Opacity validation happens before `_pageFlow` and before any state change; `exportPlan` stays a non-`async` method, so
  the `ArgumentError` is a synchronous throw as the brief says ("before anything runs").
- No component type or handle crosses the barrel: `FloorPlanTableColor` and the underlay stay internal;
  `kTableColorOpacity` was already Task 3's.

## Concerns

- `apps/floor_planner` calls `exportBytes` / `exportPdfBytes` (document_host.dart:595, 616) without an opacity, so the
  app's exports and prints carry the table colours at the default 0.35 (it has no `FloorPlanTheme`); fine for now, an
  app that themes would need to pass it. The restaurant demo uses `exportPlan` and gets 0.35.
- The EX2/EX3/EX5 pixel comparisons sample interiors at 96 dpi (13.2 mm per pixel) with a 1-unit tolerance; the
  anti-aliased edges are never sampled, and each sample is 250 mm+ inside its top.
- The new test imports helpers from another test file (`table_fill_test.dart`); intended, but a refactor of that
  file's exports must keep them.
