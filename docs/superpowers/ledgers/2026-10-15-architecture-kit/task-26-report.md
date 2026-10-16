# Task 26 report: integration, the canvas, the tools, the layers, the shell rows and the sample flat's cases

**Status: DONE_WITH_CONCERNS.** Commit `675f7f2f test(integration): the canvas, tools, layers and shell rows (3a Task 26)`, on top of 45be3170. No library code changed. Everything is green, and all nine named mutations go red.

The concerns are three deviations from the brief, each with evidence (see "Deviations"). They need the controller's confirmation:
- **TL9.** It reads `c.toolFor(...)` under R-P9's ignore, so `dimension_shell_test.dart` carries `invalid_use_of_internal_member` alongside `room_paint_test.dart`.
- **IT-R12's `SpatialIndex(c.document)`.** This breaks the editor's index. The port reads the editor's own index instead.
- **A12b.** The brief's single `tester.pump()` after the permissions change is replaced by a re-pump, as the source does.

## Implementation summary

### Step 1: preconditions

Both suites were green on a clean HEAD:
- Integration: `00:15 +99: All tests passed!`, analyze `No issues found!`.
- Kit: `00:18 +597: All tests passed!`, analyze `No issues found!`.

The integration pubspec lacked `pdf`. I added it under dev (`pdf: ^3.13.1`) because `fake_page_printer.dart` needs `PdfPageFormat`. `vector_math` and `jet_cad_2d_kit` were already present. `flutter pub get` rewrote no `analysis_options.yaml`.

The kit's letters and ids match the brief:
- Letters: `letter: 'B'`, `'W'`, `'I'`, `'M'`, `'S'`, and D/N/G through `_openingPlanTool`.
- Property ids: thickness, justification, width, position, flip-hinge, flip-swing, name, area, value, kind, axes, end-1, end-2, and the box's width and height.

### New integration support (R-P14: reused and re-exported, never copied)

**`plans.dart`**
- New here: `planWith`, `englishWords`, `kPlan*`, `c5Walls`, `Plan`, `buildPlan`, `attachPage`, `renameRoom`, `d23PlanJson`.
- `buildPlan` wraps `dimension_plans.dart`'s `buildPlanIn`, which gained `wallsAfter`. This gives one builder, not two.
- Re-exported from their owners:
  - from `room_plans`: the plan model, `groupFor`, the sample plans, `recordOf`, `worldPoints`, `addRoom`, `labelsOf`, `textOf`, `worldTintOf`, `pageOf`, `anchorOf`, `deleteObject`, `labelStrings`, `kindsOf`;
  - from `wall_fixture`: `ox`, `oy`, ..., `kids`, `canon`, `enc`, `driftOf`, `walls`, `xy`, `facesOf`, `expectMitre`, `expectSquare`, `insideRing`, `faceOf`;
  - from `dimension_plans`: `addSeparator`, `addOpening`, `addDimension`, `fixedAt`, `dimText`, `dimTextHandle`, `dimLines`;
  - from `opening_support`: `worldEndsOf` (its record also has `d`);
  - from `editor_rig`: `kitCatalog`.

**Changes to existing support files**
- `wall_fixture.dart`: gains `faceOf(s, e, offset)`, and `face` now delegates to it (one implementation).
- `dimension_plans.dart`:
  - gains `dimTextHandle` and `dimLines`, and `dimText` now uses `dimTextHandle`;
  - `buildPlanIn` gains `wallsAfter`;
  - its own `byKey` is removed in favour of a re-export of `canvas_rig.dart`'s.
- `editor_rig.dart`: `pumpEditor` gains `window` (the surface size, 1440 x 900 by default).

**`canvas_rig.dart`**
- Copies nothing from the rig:
  - `pumpPlanEditor` is the rig's `pumpEditor` plus one frame;
  - `pressKey` is the rig's `press`.
- New: `byKey`, `field`, `section`, `frameOn`, `gripsOf`, `indexOf`, `mouseClick`, `canvasFocus`, `focusCanvas`, `canvasFocused`, `choose`, `menuOf`.
- `indexOf` is new and not in the brief. It returns `InteractionLayer.tools.context.index` (see the IT-R12 deviation).

**`units.dart`**
- `fxKit` (with an optional library).
- Copied: `leafRecord`, `tableUnit`, `tableSymbol`, `entryOf`, `kDeg37`, `placementAt`, `addLayer`, and 2b's editor symbols.
- New: `placeUnit`, `placeAt`, `labelTopOf`, `labelUnit`, `unitsLabelled`, `tableOf`.

**`editor_fixture.dart`**
- 2b's unit editor fixture on the sample flat. `editorPlanJson` is `planWith(..., kits: [architectureKit, fxKit()], first: buildSampleFlat)`.
- `mountEditor({permissions, json})`, `setPermissions`, `canvasOrigin`, `centreOf`, `editorKits`, `editorColumnCorner`.
- 2b's selection helpers, with `c.selection` read as `c.activeSelection` and `coordsOf` inlined.
- Thin delegates under 2b's names (the reconcile log allows this): `screenOf` is the rig's `globalAt`, `click` is `mouseClick`, and `encodedPlan` is `encoded`.

**`layer_plan.dart`**
- `LayerPlan`, `layersOn`, `onLayer`, `addObjectOn`, `addWallsOn`, `layerFixture(doc, ...)`, `addLineOn`, `addRegionOn`, `addSymbolOn`, `layerOf`, `objectLayerOf`, `moveObject`, `pickerPlan`.
- `pickerPlan`'s `wall` and `door` are `l.walls[0]` and `l.openings[0]`, as in the source's `PickerDoc` (`:63-64`).

**`fake_page_printer.dart`**
- A copy of the plan's, over the public `PagePrinter`.

### Kit support and tests (C7)

- `test/support/layer_fixture.dart`: today's fixture over the kit's own files.
  - `PageComponent.register` and `testCatalog().registerComponents` replace `registerAppComponents`.
  - `toolOf(LayerDoc, toolId)` builds the tool over `FakePlanServices`.
  - The `'wall_fixture.dart' show testCatalog, installParametric` import is dropped: `dimension_fixture` → `room_fixture` already re-exports both.
- `tools_layer_test` (9 cases), `opening_host_layer_test` (6), `attach_layer_test` (3) and `intersection_snap_test` (1).
- `room/room_cost_test` gains LZ3 with the brief's set-up (`buildSampleFlat` over `installParametric`).
  - It does not reuse `sample_flat_test.dart`'s `sampleFlat` helper. That helper lives inside a test file (with a `main`), so it is not shared support, and it installs a catalog of the kit's guarded types, not the test catalog `liveOf` reads.

## TDD evidence

These are ports over behaviour that has existed since Tasks 9-25. Each file was written before its first run.

The first runs that went red were real failures of the brief's text against correct code, and each became a deviation:
- A12b: `Expected: <false> Actual: <true>`, `tool-plan.line draws: disabled`.
- SL1 clause 5: `SlotStateError(slot 557): not live` in `DraftPainter.paint`.
- TL9: `Expected: <Instance of 'LineTool'> Actual: <Instance of 'GuardedTool'>`.
- P-1: `Binding has not yet been initialized`, from `PlanController.setUnitData` → `settlePendingInput` → `FocusManager.instance`.

Every other ported case was green on its first run. Each new case's RED is its mutation, below.

## Gates

| Package | Command | Result |
|---|---|---|
| integration | `flutter test --enable-vmservice` | `00:42 +138: All tests passed!` (99 before, plus 39 new) |
| integration | `flutter analyze` | `No issues found! (ran in 3.0s)` |
| integration | `dart format --output=none --set-exit-if-changed .` | `Formatted 50 files (0 changed)`, exit 0 |
| kit | `flutter test` | `00:20 +617: All tests passed!` (597 before, plus 20) |
| kit | `flutter analyze` | `No issues found! (ran in 3.2s)` |
| kit | `dart format --output=none --set-exit-if-changed .` | `Formatted 129 files (0 changed)`, exit 0 |
| kit | `dart pub publish --dry-run`, after the commit | `Package has 0 warnings.` Before the commit it reported 1 warning: the modified `room_cost_test.dart` |
| root | `dart run tool/ci/check_kit_deps.dart` | `kit dependencies: 2 package(s) checked, none names the plan library or another kit`, exit 0 |

The greps from Step 13:
- `package:jet_cad_2d_plan/src` and `package:jet_cad_2d_kit_architecture/src` in the integration package: nothing.
- `invalid_use_of_internal_member` among this task's files: `room/room_paint_test.dart` and `dimension/dimension_shell_test.dart` (the second is the TL9 deviation). The other hits are earlier tasks' files.
- `jet_cad_2d_plan` in the kit's tests: only `test/support/place_entry.dart:2`. That is a comment from Task 23, and `check_kit_deps` passes.
- Non-ASCII: every non-ASCII string literal in the 14 ported files is present byte for byte in its source. I checked this with a script over the source/port pairs; the `'Masa 4.ğ'` and `'7f3c-ä'` literals come from `table_data_test.dart`'s `hostData`.

`git status --short` after the commit is clean, and no `analysis_options.yaml` was touched.

## Mutation results

All were run on committed files. Each was reverted with `git checkout -- <file>`, and `git diff --quiet` then exited 0.

| Id | Mutation | Red (quoted) |
|---|---|---|
| M-IT-1 | `wall_plan.dart` `letter: 'W'` → `'Q'` | IT-letters: `Expected: 'architecture.wall' Actual: 'plan.select'`. IT-guard: the same, in its control |
| M-IT-2 | `kit.dart`: `doorPlanTool,` deleted | A12b: `Which: has too few elements (14 < 15)`. IT-ids: `Expected: true Actual: <false>`. IT-letters is red too |
| M-IT-3 | `plan_shortcut_guard.dart`: `if (e.kitId == kPlanKitId) if (e.key case final key?) key,` | IT-guard: `Expected: 'plan.select' Actual: 'architecture.box'`, `architecture.box typed` |
| M-IT-4 | `room_tool.dart`: the `SetComponentCommand<ObjectLayer>` line deleted | tools_layer "the Room tool creates its room ...": `Expected: <19> Actual: <null>`, `the object takes the layer` |
| M-IT-5 | `isUsableHost` → `return true \|\| ...` | opening_host_layer "a wall on the hidden C hosts nothing": `Expected: null Actual: <29>`. Locked B, the stale-hover case, the overlap case and the `isUsableHost` case are red too |
| M-IT-6 | `wall_plan.dart`: thickness `gate: PlanGate.reshape` deleted | T5-f: `Expected: true Actual: <false>`. R-3 is red too |
| M-IT-7 | `opening_plan.dart`: flip-hinge `gate: PlanGate.reshape` deleted | T5-f: `Expected: no matching candidates Actual: _WidgetPredicateWidgetFinder:<Found 1 widget ...` |
| M-IT-8 | `plan_controller.dart:378`: `if (made) _prepare(document);` → `_prepare(document);` | SR3: `Expected: false Actual: <true>` on `doc.tables.linetypes.contains(ReservedHandles.dashedLinetype)` |
| M-IT-9 | `room_tool.dart`: `final seed = _raw.clone() + Vector2(1e6, 0);` | TD1: `Expected: an object with length of <1> Actual: []`, `a finger's tap still places` |

## Ported-test accounting

Change classes:
- (1) ids, keys and renames;
- (2) tags → fields;
- (3) widget form;
- (F) a fixture change the brief names;
- (D) a deviation, see below.

| Old case (source) | New case | Classes |
|---|---|---|
| touch_tools TD1 | integration `canvas/touch_tools_test` TD1 | F (IT-R5: plan file, `frameOn`); `screenOf` → `globalAt`; `press` → `pressKey` |
| planner_shell "a click on a wall selects it" | `shell/planner_shell_test` | F (IT-R4, `sampleFlatController`); `view.*` → controller; `childrenOf` → `kids`; `dimensionsOn` over `AttachedEnd` |
| planner_shell "cmd+Z undoes a Delete" | same file | as above |
| planner_shell "ctrl+Z after deleting two walls" | same file | as above |
| planner_grips A1, A2, A3, A4, M-03ao | `canvas/planner_grips_test` (5) | F (IT-R3); `view.tools.active.phase` → `activeTool(tester).phase`; `osnapText` → room_plans' `osnap`; `payloadOf` and `globalOf` from support |
| planner_draw A12b, the architecture rows | `editor/architecture_palette_test` A12b | F (IT-R9); D (re-pump) |
| (new) IT-letters, IT-ids, IT-guard | same file | new; RED under M-IT-1/2/3 |
| editor_panels T5-f | `editor/editor_panels_test` | 1 (keys), 3 (IT-R6 dropdown, IT-R7 `field`/`section`), F (IT-R8 armed sofa); `select(c, h)` → room_plans' `select(c, [h])` |
| editor_panels "a tool's settings are no edit ... Wall tool" | same | 1, 3 |
| editor_panels V-5 "each selectable" | same | 1 (`table-*` → `unit-*`), 3 |
| editor_panels R-3 changeLayer/reshape | same | 1, 3 |
| editor_panels R-4 Door tool | same | 1, 3 |
| keyboard_focus "a gesture's keys stay: the Wall tool" | `shortcuts/keyboard_focus_test` | F (2b's `mountUnitKeys`, `intents: false`); 1 (2b's renames) |
| keyboard_focus DS2 | same | as above |
| keyboard_focus DS5 | same | as above |
| keyboard_focus R-3 RP5 | same | as above |
| apps layer_picker `:352-401` | `layers/layer_picker_wall_test` | F (the open flow → `pickerPlan`); 1 (keys) |
| tools_layer: the placer's case | `layers/placer_layer_test` | F (IT-R10: `plan.symbol`, R, M, click) |
| tools_layer: the other 9 | kit `layers/tools_layer_test` | F (`toolOf`) |
| opening_host_layer, 6 cases | kit `layers/opening_host_layer_test` | F (`toolOf`, `openingsOf`) |
| attach_layer, 3 tests | kit `layers/attach_layer_test` | F (`live:`) |
| intersection_snap, 1 case | kit `intersection_snap_test` | imports only |
| delete_components P-1, P-2, P-3 | `controller/delete_components_test` | F (IT-R2, IT-R11: units, `setUnitData`); a binding init |
| dimension_paint RR1, RR2, RR3 | `dimension/dimension_paint_test` | F (`sampleFlat`, `Rig` over `pumpEditor`); `kDimLineweight` written out (print only) |
| dimension_shell SL1, SL2, TL9 | `dimension/dimension_shell_test` | F; IT-R12 (`gripsOf`); D (index, TL9); IT-R13: 3 lines not ported (`:345-349` oracle attached end; two `oracleFailures` lines) |
| room_paint RR1, RR2, RR3, RR4, SR3, OL4 | `room/room_paint_test` | F (`sample`, `Shot` over `pumpEditor`); IT-R14 (SR3); R-P9 (OL4 outlines); `pointInRing` → wall_fixture's `insideRing` |
| room_cost LZ3 | kit `room/room_cost_test` LZ3 | F (IT-R15 set-up); `RoomInputs(doc, liveOf(doc))` |

No assertion was dropped, weakened or loosened. The IT-R13 lines are left in the file as `// Not ported (ruling IT-R13): ...` comments.

## D-48: the closed lists (Step 12)

| Today's closed list | The kit's hook | Test(s) that prove it |
|---|---|---|
| `isParametricObject` | `PlanType` registered, `typeIdOf` (E1) | `layer_picker_wall_test` (the wall's picker, below its section); T5-f |
| `ObjectGrips._of` | `PlanType.grips` | Task 28's O13a and O13b (not yet in the tree); Task 12's WG-refuse-short (`wall/wall_grips_test.dart`) |
| `FloorPlanTool` enum | `PlanTool.id` | IT-ids |
| palette `_entries` and letters | `PlanTool.letter`, `icon`, `needs` | A12b's restored rows; IT-letters |
| `kShellLetterKeys` | the letters in use (`planLetterKeys`) | IT-guard |
| per-tool strings | `tool:` words | IT-letters (English); Task 27's PW1 and Q0-E3b (not yet in the tree) |
| the Selection panel's per-type sections | `PlanType.properties`, `title`, `section` | T5-f; Task 27's WS1 and IP-title (not yet in the tree) |
| `pickedColors` | `PlanType.colour` | Task 27's CP1 and CP2 (not yet in the tree) |
| `exportOmitOwners` | `PlanType(exported: false)` | Task 17's D-30 (`separator/separator_export_test.dart`) |
| the room inputs | `RoomInputs` over `shared` and `liveTypeIdOf` | Task 16's RR-live (`room_inputs_services_test`); TD1; room_paint's RR1-RR4; Task 19's RT-frozen-wall |

## Files changed

- Created, integration:
  - `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_integration/test/support/{plans,units,editor_fixture,canvas_rig,layer_plan,fake_page_printer}.dart`
  - `test/canvas/{touch_tools,planner_grips}_test.dart`
  - `test/shell/planner_shell_test.dart`
  - `test/editor/{architecture_palette,editor_panels}_test.dart`
  - `test/shortcuts/keyboard_focus_test.dart`
  - `test/layers/{layer_picker_wall,placer_layer}_test.dart`
  - `test/controller/delete_components_test.dart`
  - `test/dimension/{dimension_paint,dimension_shell}_test.dart`
  - `test/room/room_paint_test.dart`
- Modified, integration: `pubspec.yaml` (pdf), `test/support/editor_rig.dart` (`window`), `test/support/wall_fixture.dart` (`faceOf`), `test/dimension/dimension_plans.dart` (`wallsAfter`, `dimTextHandle`, `dimLines`, `byKey` re-exported).
- Created, kit: `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_kit_architecture/test/support/layer_fixture.dart`, `test/layers/{tools_layer,opening_host_layer,attach_layer}_test.dart`, `test/intersection_snap_test.dart`.
- Modified, kit: `test/room/room_cost_test.dart` (LZ3).

## Deviations

### 1. TL9's active tool (IT-R12, second bullet; IT-R1's "room_paint only")

The brief assumes plan.line is unguarded. It is not:
- `PlanController._guardTool` is "The decorator every tool of a document's map wears (spec P4)" (`plan_controller.dart:934-945`).
- So `activeTool(tester)` is a `GuardedTool`. The run gave `Expected: <Instance of 'LineTool'> Actual: <Instance of 'GuardedTool'>`.

The port reads `c.toolFor(c.activeTool.value)!`. That is R-P9's listed `@internal` road, which returns the tool "without the guard" (`:2297-2303`). The file therefore starts with `// ignore_for_file: invalid_use_of_internal_member`. The assertions are unchanged, and all TL9 lines pass.

I also confirmed the same lines pass when the tool is read as the guard's `inner` in an experiment that was not committed.

Alternatives, if the controller prefers: export `GuardedTool.inner`'s road (a library change), or skip TL9.

### 2. A second `SpatialIndex` over the editor's document (IT-R12, third bullet)

- **What happens.** `SpatialIndex(doc)` installs itself as `document.commands.onAfterMutate`, a single slot (`spatial_index.dart:162-174`). A test-made index takes that slot from the editor's index.
- **Evidence.** After SL1 clause 5's drag, the editor painted a stale slot: `SlotStateError(slot 557): not live` at `DraftPainter.paint`. Without the extra index, the same clause passed.
- **The port.** It reads the editor's own index through the public `ToolContext.index` (`canvas_rig.dart`'s `indexOf`), the same index as today's `view.index`. No assertion changed.

### 3. A12b's second pump (Step 9 item 9)

- **The fault.** The brief's `await tester.pump()` after the permissions change leaves the palette as it was: `tool-plan.line draws: disabled`, `Expected: <false> Actual: <true>`.
- **The fix.** The source re-pumps its composition (`pumpDesign`), so the port re-pumps the editor (`pumpPlanEditor`). The assertions are unchanged.

### 4. Smaller adaptations (fixture and harness only)

- `delete_components_test` calls `TestWidgetsFlutterBinding.ensureInitialized()`. The reason: `setUnitData` settles pending panel input through `FocusManager`.
- `editor_panels_test`'s R-3 and R-4 cases sit in their source group, "the review's killers (Task 5 review R-2, R-3, R-4)". The keyboard cases sit in their source groups too.
- `room_paint_test` finds a furniture region with wall_fixture's crossing-number `insideRing`, because the kit's `pointInRing` is not exported.
- `dimension_shell_test`'s `wallsOf` became wall_fixture's `walls`, and `childrenOf` became `kids`. Local variables named `kids` were renamed to `children` because the function name would shadow them.
- `dimension_shell_test`'s `pressKey` is the rig's `press` plus one frame (a parameter by pump count).
- Kept as local variants, with the reasons:
  - `dimension_shell_test`'s `undoKey` sends Ctrl+Z, while the support's `undoKey`s send Meta+Z.
  - `dimension_shell_test`'s `tapWorld` adds a 500 ms frame for the double-tap window.
  - `planner_grips`' `cmdZ` sends `metaLeft` down and up around Z, while the support's variants use `meta` and `sendKeyEvent`.
  - `planner_grips`' `mouseDrag` takes screen offsets: A1 drops at a pixel offset, which `dragWorld` cannot express.
- `dimsOf` and `lum` stay test-local, as in their sources: both `dimension_paint` and `dimension_shell` define them.
- `placer_layer_test` used a probe that was not committed to confirm that R and M reached the armed tool. The placed transform was `Transform2(0.0, -1.0, -1.0, 0.0, ...)`: mirrored and turned a quarter.

## Concerns

1. Deviations 1 and 2 bend rulings IT-R1 and IT-R12, and need the controller's confirmation (`Ruling:` lines).
2. The D-48 table names tests from Tasks 27 and 28 that are not yet in the tree: O13a, O13b, PW1, Q0-E3b, WS1, IP-title, CP1, CP2.
3. Near-duplicates from earlier tasks remain, as parked in Task 18's Minors for the final wave: the `undoKey`, `tapWorld` and `dragWorld` variants across `room_plans`, `opening_support` and `wall_shell`. This task added no new copies.

## Fix report, round 1 (review: Needs fixes)

Commit: `c52df050 test(integration): P-1 asserts the restored data; shared symbolsReady (3a Task 26 fix)`, on top of 675f7f2f.

### 1. IMPORTANT: P-1's vacuous undo check

**The fix.** `delete_components_test.dart`'s last P-1 line is now:

```dart
expect(c.unitDetails.singleWhere((x) => x.unit.label == '1').data,
    equals(hostData()));
```

A comment above it says why the matcher changed (C7 class 3, the API's form). Today's `dataOf` returned a nullable component. `PlanUnitDetail.data` is a non-nullable map that defaults to `const {}` (`unit_detail.dart:85`), so `isNotNull` held whatever came back.

`setUnitData` stores the map unchanged (`UnitData(data)`, `plan_controller.dart:1428`), so I used `equals`.

### Mutations

Both were run on committed files and reverted; `git diff --quiet` exited 0 afterwards.

**M-P1a, test side: the data is never written.** I deleted the `setUnitData('1', hostData())` line.
- New matcher, red: `Expected: {'zeta': 'Masa 4.ğ', 'id': '7f3c-ä', 'alpha': ''} Actual: {}`, `Which: has different length and is missing map key 'zeta'`.
- Old `isNotNull` under the same mutation, green: `+1: All tests passed!`. That run is the vacuity, shown.

**M-P1b, library side: the restored data is never read back.** In `plan_controller.dart`'s unitDetails builder I replaced `final data = d.components.get<UnitData>(u.instance)?.data ?? const <String, String>{};` with `const data = <String, String>{};`.
- New matcher, red: `Expected: {'zeta': 'Masa 4.ğ', 'id': '7f3c-ä', 'alpha': ''} Actual: {}`.

A mutation that drops the undo itself goes red earlier, at `expect(canon(doc), before)`, so it does not single out this line. M-P1b is the one that does.

### 2. Minor: one shared library wait

`canvas_rig.dart` gains `Future<bool> symbolsReady(WidgetTester tester, PlanController c)`.
- It is bounded: at most 400 rounds of a 20 ms `runAsync` wait and a pump.
- It returns whether the state is ready.

It replaces the loops in `editor_panels_test.dart` (T5-f) and `placer_layer_test.dart`. Each call site is now `expect(await symbolsReady(tester, c), isTrue, reason: 'premise: the furniture library loaded')`.

`furniture_load_test.dart` keeps its own `settle`. Its shape differs:
- it runs in plain `test`s with no `WidgetTester` (no pump, no `runAsync`);
- it waits while the state is `loading`, not until `ready`;
- it has its own 500 x 1 ms bound.

### 3. Minor: the `section` name clash

`canvas_rig.dart`'s `section(typeId, toolId)` is renamed `sectionFinder`. Its three callers, all in `editor_panels_test.dart`, are updated. `opening_support.dart`'s `section` getter is unchanged.

### Gates

- integration `flutter test --enable-vmservice`: `00:41 +138: All tests passed!`
- `flutter analyze`: `No issues found! (ran in 3.2s)`
- `dart format --output=none --set-exit-if-changed .`: `Formatted 50 files (0 changed)`, exit 0
- `dart run tool/ci/check_kit_deps.dart`: `kit dependencies: 2 package(s) checked, none names the plan library or another kit`
- `git status --short`: clean after the commit
