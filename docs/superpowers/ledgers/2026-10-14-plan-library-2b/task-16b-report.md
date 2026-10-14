# Task 16, Part B: report

Status: DONE_WITH_CONCERNS. The concerns are listed at the end: one ported assertion was dropped (DS4), one brief mutation did not turn its named test red (M-SV-R2), and there are four scope decisions for the controller.

Commits, on b79df762:
- `99165864 feat(plan): PlanEditor's service mode, the plan kept in place`
- `e5835933 test(plan): port the chrome kept in place (F-2, F-3) for PlanEditor`
- `91aacf3b test(plan): SV-12 pins the idle keys across a load in design too`
- `de40ee6a test(plan): theme_canvas's service runs of M-H33 and selectionOnLight`

## What was implemented

### B3: the controller (`lib/src/controller/plan_controller.dart`)
- `_PlanCamera`, which adds `panUnheard`. The camera is constructed as `_PlanCamera`.
- `_defaultChromeOrigins` and `@visibleForTesting planCanvasSeeds`.
- `_canvasIn`, `_canvasAt`, `_assumed` and `_chromeAt`.
- `@internal canvasAssumed`, `canvasMeasured` and `chromeMoved`, plus `_reframe`.
- `canvasPlaced` records `_canvasIn[mode]`.
- `setMode` reframes, then takes the new mode's rect, before `_mode.value` changes.
- All of the above is the brief's code verbatim. `kServiceBarHeight` is imported with `show`.

### B4: the editor (`lib/src/editor/plan_editor.dart`)
- The service options, each with a one-line doc ending "passed to the service view", and the class doc paragraph.
- The state gained:
  - `_serviceView()`, memoized with `??=` and cleared at the top of `didUpdateWidget`;
  - `_designOverlays()`, memoized by `identical(widget, …)`;
  - the R-13 block (`_measureAfterFrame`, `_chromeOrigin`, `_assumeCanvases`, `_keepPlanInPlace`, `_measureChrome`, `_scheduleCanvasMoved`, `_canvasMoved`, `_canvasOrigin`);
  - `_laidOutMode = null` on a controller swap.
- `build` is now `PlanThemeScope` → `_ChromeOrigins` → `Builder(_modes)`. 2a's subtree moved unchanged into `_editor`; the only change is `PlanCanvas(…, unitOverlays: _designOverlays())`.
- Deviation: I did not add `widget.controller.mode.addListener(_onController)`. The editor already listens to the controller, and `setMode` notifies it. Part A's review flagged the same duplicate listener as redundant. The mode tests pass without it.

### B7: the barrel
- The four new exports, sorted.
- `kUnitColourOpacity` added to the theme export and `UnitProblem` to the problems export.
- Making `UnitProblem` reachable through the barrel turned 2a's `test/controller/unit_colour_test.dart` import of `unit_problems.dart` into `unnecessary_import`. I removed that import line.
- Public names audit: no public API type a host needs is unexported. `PlanSwatch` comes from `jet_cad_2d_kit`. The remaining public lib types (`ServiceRecord`, `UnitIndex`, the painters, `UnitData`, …) are package plumbing that tests import by path.

### B8: example, README, CHANGELOG
- The example is the brief's text.
- The README Dart block is the example, whole.
- The service-mode paragraph is added. The first paragraph's last sentence was already the brief's.
- The CHANGELOG 2b block sits under `## 0.8.0 (unreleased)`, after 2a's list.

### Lib change outside the brief: `lib/src/canvas/plan_canvas.dart`
This is for carry item "2a's parked snappingAllowed-after-swap":
- On a controller swap, `didUpdateWidget` now runs `if (!old.isDisposed) old.snappingAllowed = true;`.
- `dispose` does not reset it. A canvas replaced in the same frame would have its dispose run after the new canvas's `initState`, and resetting there would undo the new canvas's setting (the idle-keys trap). Today the snap belonged to the shell, never to the controller.
- Pinned by the new test CV-6b with mutation M-CV-6c. See Concern 4.

## Files

- Lib: `plan_controller.dart`, `plan_editor.dart`, `plan_canvas.dart`, `jet_cad_2d_plan.dart`, `example/main.dart`, `README.md`, `CHANGELOG.md`.
- New tests:
  - `test/editor/editor_service_mode_test.dart` (SV-8 … SV-12);
  - `test/editor/editor_service_view_test.dart` (49 tests);
  - `test/editor/editor_modes_test.dart` (32 tests);
  - `test/service/view/{service_keys, service_options, band_view, unit_groups_gesture, unit_groups_context, theme_service, status_caption, unit_groups_look, unit_fill_view}_test.dart`;
  - `test/theme/theme_service_mode_test.dart`.
- Grown tests:
  - `test/barrel_test.dart` (ED-9 set, B3, B5, B6's unit half, B-R10's label half);
  - `test/example_test.dart` (ED-8b);
  - `test/service/view/service_bar_test.dart` (BT1 unskipped, its plan_service_bar `as host` import dropped);
  - `test/editor/unit_inspector_test.dart` (the two mode tests);
  - `test/canvas/{dark_canvas, theme_canvas, plan_canvas}_test.dart`;
  - `test/editor/editor_words_test.dart`;
  - `test/export/page_flows_test.dart`;
  - `test/controller/unit_colour_test.dart` (one import removed).

## Ports

Every ported file's header names its source and what it ports. Expectations are unchanged except:
- type and field renames inside expected values (ruling R-13): `PlanUnit(5, table, 4, k, …)` in B3; `unit-*` keys inside `repaints` maps;
- `PlanExport.fileName` → `name` (2a's rename).

The brief's lists:
- **editor_service_view_test** (49): V1s, V2s, V3-V6, V7a-h (8), V8-V13, V15, V18 (touch), V19, V16, V17, V18 (rulers), VZ1-VZ12, VF1-VF7 (VF3 runs twice), RV1-RV3.
  - VZ9 places its unit through `placeSymbol(…, units: c.unitIndex)`, so it is numbered as today's placer numbered it.
  - VF4 swaps the labels through `decodePlan` and `encodePlan`.
- **editor_modes_test**:
  - from bars: the "canvas re-measured" group (3 tests), the eight R-3 tests, K1;
  - TO13, TO14, TO23 and TO32 (TO32 with `unitOverlayModes: {PlanMode.design}`);
  - from `chrome_change_test.dart`: F-2 (6 tests) and F-3 (10 tests). No task had placed these (see Concern 2).
  - The editor capabilities map to `Caps(permissions, rulers, panels)`. Permissions are set on the controller from a listener, outside the build. `readOnly` means no left column.
- **service_keys_test** (10): M-H41b, T6-g, "undo() and exportPlan" (service half), DS4 (minus its last two lines: Concern 1), T6-a (service), T6-a scoped, and from host_text_keys: two "selection" field tests, the service canvas-focused test and S25 (service).
  - `exportPlan(png96)` is ported as 2a's `exportAs(c, png96)`, not as the brief's `c.export('plan.pdf', …)`. The ported assertion reads PNG pixel sizes, so a PDF export would break it.
- **barrel**: B3, B5 (through PlanServiceView), B6's unit half, B-R10's label half.
- **B2b (R-15)**:
  - service_options SO1-SO6: `serviceMoves` → `permissions.serviceMove`.
  - band_view RBV1-RBV8: over PlanEditor, because RBV4 switches modes.
  - unit_groups_gesture TG-G1-14.
  - unit_groups_context TG-CX1 and TG-CX2.
  - theme_service: all 13 source tests, 14 runs. The page-less zone case clears the zone plan's default page; Task 15's zone fixture has a page and today's had none. Invariant 4 keeps today's flow through the dialog (`service-export`) rather than the brief's `c.export`, which is the stronger check.
  - status_caption: 4 tests.
  - unit_groups_look: TG-V1-6, TG-Z3, TG-Z4.
  - unit_fill_view: TF6 and TF7b.
  - theme_service_mode: P-6, M-H30 and the ambient switch, each run for service, plus the two G-5 tests, R-1 and R-2.
    - Not ported again, because 2a ported them in design form: the T1-c host rebuild (editor_theme_test, TH17), S-12 (ED-7) and "through the barrel alone" (editor_theme_test).
- **unit_inspector_test**: "none without a builder …; none in the selection mode" replaces Task 10's partial version of the same test, keeping its lines. T6-e is added as a new group. `mountInspector` gained a `mode:` argument.
- **Carry items** (each with a named mutation below):
  - SW2's service half, its own test in `editor_words_test`;
  - LK1's service-bar step, appended to 2a's LK1, which is retitled;
  - dark_canvas wrapped in the mode loop: 5 service runs, design unchanged;
  - theme_canvas: the 8 looped tests plus R-1 run in both modes; invariant 4's service run is theme_service_test's;
  - page_flows: PF2's selection half, PF17 and PF23's S-22 block, each through PlanEditor;
  - snappingAllowed: CV-6b plus the lib change above;
  - PlanShortcuts remount: SV-12. The mode switch does remount the editor's PlanShortcuts.
- `pagePlan()` is used by editor_service_view_test and PF2's half.

## TDD evidence

The library steps (B3, B4, B7, B8) were written before the new tests were first run, so there is no compile-error RED.

The RED evidence is the mutations below. Each was run on committed code, and each turns its test red at the quoted line. Alongside them, M-SV-R2 left T2-f green while turning F-3 red (Concern 2).

GREEN runs:
- `flutter test test/editor/editor_service_mode_test.dart test/example_test.dart test/barrel_test.dart` gave `+8: All tests passed!` (before SV-11 and SV-12 were added).
- Per file, after each port:
  - editor_service_view `+49`;
  - editor_modes `+32`;
  - service_keys `+10`;
  - service_options `+6`;
  - band_view `+8`;
  - unit_groups_gesture `+14`;
  - unit_groups_context `+2`;
  - unit_groups_look `+8`;
  - theme_service `+14`;
  - status_caption `+4`;
  - unit_fill_view `+2`;
  - theme_service_mode `+7`;
  - unit_inspector `+6`;
  - dark_canvas `+10`;
  - theme_canvas `+21`;
  - plan_canvas `+13`;
  - page_flows `+23`;
  - editor_words `+13`;
  - service_bar `+23` (no skip);
  - editor_service_mode `+5`.

## Gates (packages/jet_cad_2d_plan, at de40ee6a)

- `dart format .`: `Formatted 284 files (0 changed)`.
- `flutter test --enable-vmservice`: `01:53 +1498: All tests passed!`. Nothing skipped; BT1's skip is gone.
- `flutter test`: `01:42 +1491 ~7: All tests passed!`. The 7 skips are Task 14's allocation tests, which need the VM service.
- `flutter test --enable-vmservice test/invariants`: `00:09 +13: All tests passed!`.
- `flutter analyze`: `No issues found! (ran in 3.7s)`.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 284 files (0 changed)`, exit 0.
- `dart pub publish --dry-run`: `Package has 0 warnings.`
- No standing failure appears in this package and there is no new failure. Only this package was touched; no pubspec, `tool/ci` or `analysis_options.yaml` changed. `git status --short` is clean.
- Escape trap:
  - The non-ASCII characters in the new and changed files are the source's own literals. The source writes 'Rückgängig' and 'Drucken…' as literal UTF-8; `od -c` shows the same bytes (`303 274`, `303 244`, `342 200 246`) as `shell_words_test.dart`.
  - The T6-e arrows are literal, as in the source.
  - The other non-ASCII characters are in comments (`…`, `·`) or are 2a's lines moved unchanged.

## Mutations

All were run on committed files. Each was reverted with `git checkout -- <file>`, and `git diff --quiet` then exited 0.

### The brief's (B12)

| Mutation | Test | Failing line (quoted) |
|---|---|---|
| M-SV-8 `_modes` returns `_editor(context)` | SV-8 | `Expected: exactly one matching candidate` / `Actual: _TypeWidgetFinder:<Found 0 widgets with type "PlanServiceView": []>` (editor_service_mode_test.dart line 52) |
| M-SV-9 `onUnitHover:` deleted | SV-9 | `Expected: same instance as <Closure: (String?) => void>` / `Actual: <null>` (line 113) |
| M-SV-10 `_service = PlanServiceView(` | SV-10 | `Expected: <0>` / `Actual: <12>` (line 163) |
| M-SV-R1 `_reframe`'s panBy deleted | V7a | `Expected: <-46.5>` / `Actual: <-310.5>` (editor_service_view_test.dart line 287) |
| M-SV-R2 `chromeMoved` returns at once | T2-f: **stays green** (`+1: All tests passed!`). F-3 "design: the left column hidden" is red | `Expected: a numeric value within <0.000001> of <562.3005795801691>` / `Actual: <322.30057958016914>` (editor_modes_test.dart line 124) |
| M-SV-R3 `canvasAssumed` returns at once | R-3 "the service bar hidden from the start" | `Expected: [0.37, 0.0, 0.0, -0.37, -14348.25, -9407.5]` / `Actual: [0.37, 0.0, 0.0, -0.37, -14348.25, -9363.5]` / `Which: at location [5] is <-9363.5> instead of <-9407.5>` (line 145) |
| M-SV-R4 `canvasMeasured`'s panBy deleted | V7b | `Expected: a numeric value within <1e-9> of <312.2375>` / `Actual: <182.2375>` (editor_service_view_test.dart line 331) |
| M-SV-R5 `final left = 240.0;` | R-3 "the editor's rulers and left column gone and back" | `Expected: [0.37, 0.0, 0.0, -0.37, -14876.25, -9455.5]` / `Actual: [0.37, 0.0, 0.0, -0.37, -14636.25, -9455.5]` / `Which: at location [4] is <-14636.25> instead of <-14876.25>` (line 145) |
| M-ED-8b the button switches to design (example and README) | ED-8b. ED-8 and ED-README stay green | `Expected: exactly one matching candidate` / `Actual: _TypeWidgetFinder:<Found 0 widgets with type "PlanServiceView": []>` (example_test.dart line 40) |
| M-ED-9 the `PlanServiceView` export removed | barrel_test fails to compile (B5 uses the name through the barrel) | `test/barrel_test.dart:172:15: Error: Method not found: 'PlanServiceView'.` |
| M-ED-9b (assertion-level variant) `show PlanLongPress` only | ED-9 | `Which: does not contain 'PlanFloorDrag'` |

### The dispatch's and the carry items'

| Mutation | Test | Failing line (quoted) |
|---|---|---|
| M-SV-3c `_printAllowed() => controller.permissions.print` | SV-11 | `Expected: an object with length of <1>` / `Actual: []` (editor_service_mode_test.dart line 187) |
| M-SV-3a `_exportAllowed() => controller.permissions.export` | PF23's S-22 block | `Bad state: No element` at `page_flows_test.dart:894:16` (`got.single`: nothing exported) |
| M-PF2s pageFlows `document: () => document` | PF2's selection half | `Expected: not [` / `Actual: [` (page_flows_test.dart line 843: the moved copy's bytes equal the design's) |
| M-PF17 `_settle()` commented out in `guarded` | PF17 | `Expected: contains '42'` / `Actual: ['1', '2', '3', '4', '5', 'L', '7', '7', null, '9']` (line 864) |
| M-PS-idle PlanShortcuts' `initState` does not call `_applyIdleKeys()` | SV-12 (at its premise, the first mount) | `Expected: Set:['1']` / `Actual: Set:[]` (editor_service_mode_test.dart line 227) |
| M-PS-remount `PlanShortcuts(key: ObjectKey(c.document), …)` in `_editor` | SV-12 (the load step) | `Expected: Set:['1']` / `Actual: Set:[]` (line 257) |
| M-CV-6c the swap reset in PlanCanvas deleted | CV-6b | `Expected: true` / `Actual: <false>` (plan_canvas_test.dart line 215) |
| M-SW2s service Undo tooltip `'Undo'` | SW2 (service half) | `Expected: 'Rückgängig'` / `Actual: 'Undo'` (editor_words_test.dart line 177) |
| M-LK1s service Print tooltip `'Print…'` | LK1 | `Expected: empty` / `Actual: ['Print…']` (line 361) |
| M-DC-1s service `sheetArgb: null` | dark_canvas "service mode M-DC-1 …"; all 5 design runs stay green | `Expected: '0x1e1f22'` / `Actual: '0xffffff'` (dark_canvas_test.dart line 94) |
| M-TC-s1 service `planPaperPaletteFor(paper, null)` | theme_canvas M-H33 (service), selectionOnDark (service), only selectionOnLight (service), R-1 (service) | `Expected: a value less than or equal to <3>` / `Actual: <156>` (theme_canvas_test.dart line 102) |
| M-TC-s2 service `selectionStrokePixels: kSelectionStrokePixels` | selectionWidth: 4 (service) | `Expected: <4>` / `Actual: <2.0>` (line 231) |

The first run of M-TC-s1 left M-H33 (service) and "only selectionOnLight (service)" green. Three loop calls lacked `viewMode`, so both tests ran in design twice. That is fixed in de40ee6a and the run above is after the fix.

## Self-review

- Names: the lib code is the brief's verbatim, apart from the listener deviation in B4.
- Fixtures: the embedding, editor and zone plans are turned, mirrored and scaled 40 m off the origin. The new plans (options, band, gesture, look) are built from today's placements over the `fx` kit and are never at the identity.
- The old packages are untouched. Nothing is imported from `jet_cad_floor_plan`.

## Concerns (for the controller)

1. **DS4 lost its last two lines.** The dropped lines are `expect(c.deleteSelection(), isFalse, reason: 'no editor mounted'); expect(c.designJson(), before);`. Their premise cannot hold under 2a spec P2: `deleteSelection()` is the controller's own command and refuses only "with nothing selected, under `delete: false` from a widget, and for a locked object". It acts with no widget mounted. The lines are left as a comment in service_keys_test.dart and the test's title is trimmed. **A ruling is needed** (A12: a dropped ported assertion).
2. **M-SV-R2 did not turn T2-f red.** T2-f only re-measures across switches. The killer of `chromeMoved` is chrome_change_test.dart's F-3, which neither the 2b plan nor the audit had placed. I ported F-3 and F-2 into editor_modes_test.dart in commit e5835933 (16 tests, assertions unchanged); M-SV-R2 is red there. Still unplaced: F-1 ("the canvas kept across a change of both side columns"). It is design-only and 2a's domain, and is reported here only. **Rulings are needed** on the F-2/F-3 port and on F-1.
3. **Two brief mappings were kept closer to the oracle:**
   - service_keys ports `exportPlan(png96)` as `exportAs(c, png96)`, because the brief's `c.export('plan.pdf', …)` would break the PNG-size assertion;
   - theme_service invariant 4 keeps the dialog flow rather than `c.export`.
4. **The snappingAllowed item has no oracle test.** I treated it as a defect fix: two lines in `plan_canvas.dart` and the new test CV-6b. If wrong: revert the line and drop CV-6b.
5. Item counts against the brief: theme_service is 13 tests in 14 runs. The editor_service_view count matches the brief's 48 with VF3's two runs (49 runs).

## Fix round 1

Commit: `2ca9c84f test(plan): theme_canvas's mode premise back; SV-9 checks onPageFlowError` (on de40ee6a). Both issues are addressed; nothing is left open. Both changes are test-only.

1. **(Important) `test/canvas/theme_canvas_test.dart`**
   - `pumpView` now takes `PlanMode viewMode` as a required positional argument (`pumpView(tester, v, mode, viewMode, {theme, ambient})`), as the oracle does.
   - `viewOf`'s `viewMode` is now `required` as well, so no call can fall back to design.
   - `pumpView` ends with today's premise, restored as `expect(find.byType(PlanServiceView), findsNWidgets(viewMode == PlanMode.service ? 1 : 0));`, preceded by `expect(v.c.mode.value, viewMode);`.
   - The design-only T2-a now passes `PlanMode.design` explicitly.
   - Run: `flutter test test/canvas/theme_canvas_test.dart` gave `+21: All tests passed!`.
   - M-TC-s1 (the service view's `paper: planPaperPaletteFor(paper, null)`), on 2ca9c84f, `flutter test test/canvas/theme_canvas_test.dart --plain-name "(service)"`: four tests red, each at `Expected: a value less than or equal to <3>` (theme_canvas_test.dart line 107):
     - M-H33(the editor's selection) (service): `Actual: <156>`;
     - selectionOnDark on the dark canvas (service): `Actual: <176>`;
     - only selectionOnLight (service): `Actual: <156>`;
     - R-1 (service): `Actual: <150>`.
     - Summary line: `+5 -4: Some tests failed.`
     - Reverted; `git diff --quiet` exit 0.
2. **(Minor) SV-9 (`test/editor/editor_service_mode_test.dart`)**
   - The editor is now given `onPageFlowError: flowError`, and the test checks `expect(v.onPageFlowError, same(flowError));`.
   - Run: `flutter test test/editor/editor_service_mode_test.dart` gave `+5: All tests passed!`.
   - M-SV-9b (`onPageFlowError: widget.onPageFlowError,` deleted from `_serviceView`): SV-9 red at `Expected: same instance as <Closure: (Object) => void>` / `Actual: <null>` (editor_service_mode_test.dart line 130). Reverted; `git diff --quiet` exit 0.

Gates (packages/jet_cad_2d_plan):
- `dart format .`: 0 changed.
- `flutter test --enable-vmservice`: `01:53 +1498: All tests passed!`.
- `flutter analyze`: `No issues found! (ran in 3.9s)`.
- `dart format --output=none --set-exit-if-changed .`: exit 0.
- `git status --short`: clean.
