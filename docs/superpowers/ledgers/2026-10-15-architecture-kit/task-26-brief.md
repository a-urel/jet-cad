### Task 26: Integration: the canvas, the tools, the layers, the shell rows and the sample flat's cases (spec C6, C7; Appendix A D-19's sample-flat files, D-22, D-23, D-26, D-29, D-33, D-34, D-48, A.2's `planner_grips`, `editor_panels`, `keyboard_focus` rows; rulings R-P1, R-P5, R-P9, R-P10)

**Files** (the integration package is `I = packages/jet_cad_2d_integration`, the kit `K = packages/jet_cad_2d_kit_architecture`):
- Create (integration test support, public libraries only; Tasks 27 and 28 import them, see "New shared name"):
  - `I/test/support/plans.dart` (plan files built through a scratch controller; the architecture fixtures of today's `wall_fixture.dart`, `wall_shell.dart`, `room_fixture.dart`, `dimension_fixture.dart`, as far as the integration tests use them, re-stated over the kit's public parameters)
  - `I/test/support/units.dart` (the fixture kit `fx` and a unit placed and labelled by hand, ported from 2b's `jet_cad_2d_plan/test/support/unit_fixtures.dart`)
  - `I/test/support/editor_fixture.dart` (2b's `unit_editor_fixture.dart` with the sample flat restored, the 2a/2b editor helpers)
  - `I/test/support/canvas_rig.dart` (cameras, gestures, the status line, the active tool)
  - `I/test/support/layer_plan.dart` (P-6's layer fixture of today's `test/support/layer_fixture.dart`, as a plan file)
  - `I/test/support/fake_page_printer.dart` (copy of `jet_cad_2d_plan/test/support/fake_page_printer.dart`, imports adapted)
- Create (integration tests):
  - `I/test/canvas/touch_tools_test.dart` (TD1)
  - `I/test/shell/planner_shell_test.dart` (the three sample-flat cases)
  - `I/test/canvas/planner_grips_test.dart` (A1-A4 and the fifth case, M-03ao)
  - `I/test/editor/architecture_palette_test.dart` (A12b-arch, IT-letters, IT-ids, IT-guard)
  - `I/test/editor/editor_panels_test.dart` (T5-f, the Wall-tool settings case, V-5's "each selectable", R-3's changeLayer/reshape, R-4's Door tool)
  - `I/test/shortcuts/keyboard_focus_test.dart` (the Wall-tool host case, DS2, DS5, R-3 RP5)
  - `I/test/layers/layer_picker_wall_test.dart` (the app's wall case)
  - `I/test/layers/placer_layer_test.dart` (tools_layer's placer case)
  - `I/test/controller/delete_components_test.dart` (P-1, P-2, P-3)
  - `I/test/dimension/dimension_paint_test.dart` (RR1, RR2, RR3; ruling R-P5, Task 21's carried port)
  - `I/test/dimension/dimension_shell_test.dart` (SL1, SL2, TL9; ruling R-P5, Task 22's carried port)
  - `I/test/room/room_paint_test.dart` (RR1, RR2, RR3, RR4, SR3, OL4; ruling R-P10, Task 18's carried port)
- Create (kit test support and tests, C7: names of the kit, the contract, the engine and the Flutter layer only):
  - `K/test/support/layer_fixture.dart` (today's `layer_fixture.dart` over the kit's test catalog, with `toolOf`)
  - `K/test/layers/tools_layer_test.dart` (9 cases), `K/test/layers/opening_host_layer_test.dart` (6), `K/test/layers/attach_layer_test.dart` (3 tests: the swing loop's two and the missing-layer case), `K/test/intersection_snap_test.dart` (1)
- Modify (kit test): `K/test/room/room_cost_test.dart` (Task 18's RK1, RK2) gains LZ3 (rulings R-P10 and R-P1: LZ3 reads the kit's debug counters, so it runs in the kit over `buildSampleFlat`, see Step 8)
- Modify: `I/pubspec.yaml` **only** to add a dev dependency Step 1 finds missing (`vector_math`, `pdf`); then `dart run tool/ci/check_kit_deps.dart` is part of the gates.

**Interfaces:**
- Consumes:
  - Shared interfaces: `architectureKit`, `ArchitectureTypes`, `ArchitectureTools`, `buildSampleFlat`, `WallParams`, `Justification`, `OpeningParams`, `OpeningKind`, `HingeEnd`, `SwingSide`, `SeparatorParams`, `RoomParams`, `DimensionParams`, `DimKind`, `DimEnd`, `AttachedEnd`, `FixedEnd`, `WallSide`, `BoxParams` (`package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart`); `architectureController({String? json, PlanPermissions permissions})`, `sampleFlatController()`, `planEditorApp(controller, {locale})` (`package:jet_cad_2d_integration/jet_cad_2d_integration.dart`, Tasks 9 and 25); `PlanController(kits:, json:, build:)`, `newPlan(build:)`, `toolNotice`, `textOf` (Tasks 4, 5); `KitNamesWords(names, locale, {decimalSeparator})` (Task 3); `FakePlanServices` (`package:jet_cad_2d_kit/testing.dart`, Task 6); `PlanKit.prepare` (Task 5).
  - Plan library, public (`jet_cad_2d_plan.dart`): `PlanController` (`document`, `activeSelection`, `activeTool`, `selectTool`, `camera`, `execute`, `save`, `undo`, `redo`, `permissions`, `reportLocale`, `select`, `selectedUnits`, `setUnitData`, `units`, `unitDetails`, `deleteSelection`, `symbols`, `symbolsState`, `armSymbol`, `canUndo`, `dispose`), `PlanEditor`, `PlanCanvas`, `PlanToolPalette`, `PlanPermissions`, `PlanStrings*`, `planLocalizationsDelegates`, `planSupportedLocales`, `PagePrinter`, `ensureManifest`; the panel keys `section-<type id>`, `settings-<tool id>`, `property-<spec id>`, `setting-<spec id>`, `<key>-<segment>` (`plan_property_panel.dart:700-744, :795-828`), `tool-<tool id>` (the palette), `status-text`, `osnap-text`, `layer-picker`, `unit-section`, `unit-label`, `unit-rotate-left`, `symbol-section`, `symbol-size-menu`, `symbol-mirror`, `page-preset`, `layers-add`, `chrome-right`.
  - Contract, public (`jet_cad_2d_kit.dart`, `authoring.dart`): `PlanKit`, `SymbolLibrarySource`, `SymbolEntry`, `SymbolComponent`, `UnitComponent`, `UnitKinds`, `kUnitLabelTag`, `kUnitLabelTextAttrs`, `unitLabelHeight`, `unitLabelPayload`, `ParametricCatalog` through `PlanType.registerInto`, `Catalog`, `CatalogSymbol`, `CatalogUnit`, `CatalogPolyline`, `encodeLibrary`.
  - Kit test support from earlier tasks (see "Assumed from earlier tasks"): Task 11's `test/support/wall_fixture.dart` (with the test catalog, R-P6), Task 16's `room_fixture.dart`, Task 18's `test/room/room_cost_test.dart`, Task 20's `dimension_fixture.dart`.
- Produces: test support only (no library code). Its names are listed under "New shared name": Tasks 27 and 28 import them.

**Appendix A rows closed:**
- D-22: `touch_tools_test` TD1 (integration).
- D-23: `planner_shell_test`'s "a click on a wall selects it in the running shell", "cmd+Z undoes a Delete through the command log", "ctrl+Z after deleting two walls brings both back in one step" (integration, over `sampleFlatController()`).
- D-26: the eight palette rows (A12b's architecture rows restored, `planner_draw_test.dart:337-353`) and the letters W D N G M S I B (IT-letters, new).
- D-29: `layers/tools_layer_test` (10: 9 kit, 1 integration), `layers/opening_host_layer_test` (6: kit), `layers/attach_layer_test` (2 definitions, 3 tests: kit), `apps/floor_planner/test/layers/layer_picker_test.dart:352-401` (integration). Appendix A names C6 for the row; its preamble lets C7 decide per case, and these cases name only the kit's tools and functions, the engine and the Flutter layer (C7: kit, tools over `FakePlanServices`).
- D-33: `delete_components_test` P-1, P-2, P-3 (integration).
- D-34's `intersection_snap_test` (1): kit (C7: it uses the engine's index and the D23 plan only; the row says C6, the preamble's rule decides).
- A.2: `planner_grips_test` A1-A4, and its fifth case "replacing the shell mid-drag" (M-03ao), which no sub-project owned: integration.
- A.2: `editor_panels_test`'s architecture remainder (T5-f; "a tool's settings are no edit … the Wall tool"; V-5 "a table, a wall, a room and a dimension are each selectable"; R-3 "full.copyWith(changeLayer: false) … reshape: false"; R-4 "with the Door tool active … its width edits the tool"): integration.
- A.2: `keyboard_focus_test`'s wall cases ("a gesture's keys stay: the Wall tool chosen by the host", DS2, DS5, R-3 RP5): integration.
- D-48: every closed list named by a test (Step 12's table).
- D-19's sample-flat cases (rulings R-P5, R-P10): `dimension_paint_test` RR1, RR2, RR3 (integration), `dimension_shell_test` SL1, SL2, TL9 (integration), `room_paint_test` RR1, RR2, RR3, RR4, SR3, OL4 (integration; SR3 is Review Focus 1's shell case beside Task 17's SP-dashed-open), `room_cost_test` LZ3 (kit). With Tasks 21, 22 and 18 this closes `dimension_paint`, `dimension_shell`, `room_paint` and `room_cost`.

**C7 placement and rulings** (sources under `packages/jet_cad_floor_plan/test/` unless named):

| Source | Cases | Destination | Why |
|---|---|---|---|
| `touch_tools_test.dart` | TD1 | integration | pumps `PlannerShell` → `PlanEditor` |
| `planner_shell_test.dart` | 3 named | integration | the shell → `PlanEditor` |
| `planner_grips_test.dart` | 5 | integration | the shell → `PlanEditor` |
| `planner_draw_test.dart` A12b | the 8 architecture rows | integration | `PlanToolPalette` |
| `host/editor_panels_test.dart` | 5 named | integration | the view's panels |
| `host/keyboard_focus_test.dart` | 4 named | integration | the view's keys |
| `apps/floor_planner/test/layers/layer_picker_test.dart` | :352-401 | integration | the app's right column → `PlanEditor` |
| `layers/tools_layer_test.dart` | 9 (all but the placer) | kit | the kit's tools, the engine, `ToolContext` |
| `layers/tools_layer_test.dart` | the placer case | integration | the symbol placer is the plan library's |
| `layers/opening_host_layer_test.dart` | 6 | kit | `OpeningTool`, `isUsableHost`, the engine |
| `layers/attach_layer_test.dart` | 3 | kit | `attachCandidates`, the engine |
| `intersection_snap_test.dart` | 1 | kit | the engine's index over the D23 plan |
| `delete_components_test.dart` | 3 | integration | a unit's `UnitData` beside walls (the plan's components) |
| `dimension_paint_test.dart` | RR1-RR3 | integration | the shell's pixels over the sample flat (R-P5) |
| `dimension_shell_test.dart` | SL1, SL2, TL9 | integration | the shell's tools and grips on the sample flat (R-P5) |
| `room_paint_test.dart` | RR1-RR4, SR3, OL4 | integration | the shell's pixels and selection on the sample flat (R-P10) |
| `room_cost_test.dart` | LZ3 | kit | the kit's debug counters and `traceRoomAmong`, no plan name (R-P1 decides the package; R-P10 gives the case to this task) |

Plan rulings (the controller confirms each before execution; each becomes a ledger `Ruling:` line):
- **IT-R1 (C6 public only; rulings R-P1, R-P9).** Every integration test file imports the plan library, the kit, the contract, the engine and the Flutter layer through their public libraries only. Where today's test reached a shell internal, the port reads the same value through a public road: the active tool is `InteractionLayer.tools.active` (`tester.widget<InteractionLayer>(...)`, the Flutter layer's public widget; a kit tool reaches it wrapped by the guard, whose `phase` and `isMidShape` forward, `jet_cad_2d_plan/lib/src/kits/guard.dart:346-370`); the selection is `PlanController.activeSelection`; a table is a unit found by its `UNIT` label in the document. Units are placed and labelled by hand (`units.dart`, the plan's placer and label command re-stated over the engine's commands and the contract's label helpers, as Task 23's `place_entry.dart` re-states the placer for the kit), because `placeSymbol` and `addUnitLabelCommand` are not exported. A file that reads an `@internal` member of a public plan class (`selection`, `grips`, `outlines`, `toolContext`) starts with `// ignore_for_file: invalid_use_of_internal_member` (R-P9); this task needs it in `room_paint_test.dart` only (OL4's `outlines`), every other read has a public road.
- **IT-R2 (tables stay tables).** Today's cases that select, edit or delete table `1` keep it: the editor fixture is 2b's unit editor fixture (`fx` units `1`, `2`, `7`, ` 7 `, an unlabelled one, `5` hidden, `L` locked, a chair), now on the sample flat (2b's stand-in lines for the north wall, its inner face, the column and the hairline are dropped: the flat draws them). `setTableData` is `setUnitData`, `selectedTables` is `selectedUnits`, `TableSurvey.withNumber(n)` is the units of `c.units` labelled `n` (2b's renames, C7 class 1).
- **IT-R3 (planner_grips' fixture).** The spec's A.2 calls A1-A4 "stretch, F3 and undo mid-drag on the sample flat's walls"; the source's fixture is two lines on a page (`planner_grips_test.dart:40-52`). The source is the oracle: ported as written, over `architectureController` so the kit is loaded while the generic grips run. The file's fifth case (M-03ao) is ported with it.
- **IT-R4 (window sizes).** `planner_shell_test`'s cases ran at flutter_test's 800 x 600; `PlanEditor`'s columns (240 + 280 px, `plan_editor.dart:933-958`) would leave a 280 px canvas, so they run at 1440 x 900. Their comments' pick-radius bounds hold with room to spare: the page fit there is about 0.06 px/mm, a 6 px pick is about 97 mm, under the 366 mm and 506 mm the comments name.
- **IT-R5 (TD1's camera).** Today's TD1 used the shell's own fit over a document with no page. A plan file has a page (the new plan's, at the origin), which the first fit frames, leaving the D23 plan off the screen; the port sets the camera on the plan's middle at 0.05 px/mm, y up, before the gestures. The fixture changes, the assertions do not.
- **IT-R6 (C7 class 3, the choices).** A `ChoiceProperty` is a `DropdownButton` (`plan_property_panel.dart:728-744`): `SegmentedButton<T>.onSelectionChanged` reads `DropdownButton<Object?>.onChanged`; a tap on a segment `'<x>-<v>'` is the menu opened and its item `'<key>-<v>'` tapped. The asserted values do not change.
- **IT-R7 (one key, two scopes).** Today's shell keyed a field the same whether it edited the object or the active tool's settings (`wall-thickness`, `opening-width`); the plan keys `property-<id>` and `setting-<id>` (`plan_property_panel.dart:702`), never shown together. A ported line keeps its single finder: `field('thickness')` matches either key (`canvas_rig.dart`), and `section(type, tool)` matches `section-<type>` or `settings-<tool>`.
- **IT-R8 (T5-f's placed sofa).** Today's T5-f placed `sofa.two` with `placeSymbol` at an exact transform (`editor_panels_test.dart:178-183`). The port arms `architecture.sofa.two` (`c.armSymbol`) and clicks at (24,600, 13,600), as a user would; no assertion reads the transform.
- **IT-R9 (the palette's rows).** A12b's map gains the eight architecture rows with today's flags (`planner_draw_test.dart:337-353`: every row but Select draws), under the plan's keys `tool-architecture.<tool>`. 2a's port dropped them for want of the tools (`jet_cad_2d_plan/test/editor/palette_draw_test.dart:228-230`); A12b's plan-library copy stays as it is.
- **IT-R12 (the sample flat's shell reads, R-P5's question).** `dimension_shell_test`'s three reads of the shell's internals map to public roads, no assertion changes:
  - SL1's `view.grips!.rotatable` and `view.grips!.pivot` (`dimension_shell_test.dart:369-371`) → `gripsOf(tester).rotatable` and `.pivot`: the `GripCache` the plan hands its tools in their `ToolContext` (`jet_cad_2d_plan/lib/src/controller/session.dart:69-76`), reached as `InteractionLayer.tools.context.grips` (the Flutter layer's public `ToolController.context`, `jet_cad_2d_flutter/lib/src/tool.dart:165`, and `ToolContext.grips`, `:106`). The same cache as `PlanController.grips` (`@internal`), without R-P9's ignore.
  - TL9's `view.tools.active` (`:561`) → `activeTool(tester)` (`InteractionLayer.tools.active`): `plan.line` is the Flutter layer's `LineTool` (`jet_cad_2d_plan/lib/src/tools/generic_tools.dart:134`), unguarded (only kit tools are wrapped), so `isA<LineTool>()`, `hoverVisible`, `hoverKind`, `hoverPoint` read as today (`PlacementTool`'s public members).
  - `view.index.pickInto`/`snapInto` (`:179`, `:577`) → the same calls on a `SpatialIndex(c.document)` the test makes and disposes (Task 22's note: the engine's index over the same document answers alike; a fixture change).
- **IT-R13 (SL1's oracle lines, kit internals).** `oracleEnd`'s attached branch and `oracleFailures` (`dimension_fixture.dart:445-522`) read the kit's `wallsInDocument`, `wallEndPoint` and `layoutDimension`, which the integration package cannot import (R-P1). Ported: `oracleEnd`'s fixed branch (`:447-449`, public: the dimension's group transform), so `:340` and `:384`, `:422` (each the diagonal's fixed end `b`) keep their assertions. Not ported (the controller confirms; Task 21's DM-R2 is the precedent): `:345-349` (the attached end E1/1/left through the oracle; the next two lines, `:350-351`, assert the dimension line's start at the same (25,750, 8,250) within 1e-6) and `:359`, `:427` (`oracleFailures(doc)` empty; `driftOf(doc)` beside each asserts the stored children are what regeneration gives, and Task 20's attach and follow tests carry the oracle over the same closure in the kit).
- **IT-R14 (`room_paint_test`'s SR3, the plan's open path).** Today's SR3 decodes the stripped file with the old catalog and installs a system by hand (`room_paint_test.dart:496-513`). The port opens the stripped plan file through the plan library, as a host does: `architectureController(json: stripped)`; `system.drift()` → `driftOf(c.document)` and `system.diagnostics()` → `ParametricSystem(c.document, kitCatalog()).diagnostics()` (both the engine's, over the kit's types); the edit is executed on `c.document.commands` as today; `system.dispose(); doc.commands.clearHistory();` are dropped (the controller's system stays, its history keeps the edit; no later line reads the depth). The rest is unchanged: a file without the record opens unchanged and its separator draws continuous (Review Focus 1, spec C1.3).
- **IT-R15 (LZ3's place).** R-P10 gives LZ3 to this task "over `sampleFlatController()`"; LZ3 reads `debugRoomGenerates`, `debugTracedSegments`, `RoomInputs` and `traceRoomAmong` (kit internals) and no plan name, so R-P1 puts it in the kit: `startupPlan(m)` + `installParametric(doc)` → a document with the kit's test catalog's system (Task 11's `installParametric`, the page registered) and `buildSampleFlat(doc, words)` run on it (Task 25's own `startup_plan_test` set-up). Assertions unchanged.

#### Assumed from earlier tasks

Each name is used as written; where the earlier task chose another, use that task's and say so in the report.
- Task 9: the integration rig `I/test/support/editor_rig.dart` with `pumpEditor`, `globalOf(tester, c, x, y)`, `status`, `press`, `activeTool`, `pagePlanJson`, `kitCatalog`, `liveOf` (its "New shared name"); this task's support re-exports the five it needs and does not redefine them.
- Task 9: the integration package exists with `architectureController`, `planEditorApp`; its pubspec lists `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_kit`, `jet_cad_2d_plan`, `jet_cad_2d_kit_architecture`, dev `flutter_test`, `vm_service` (Step 1 checks `vector_math` and `pdf`). The kit's words (English, German, Turkish) carry today's tool names: `tool:architecture.{box,wall,door,window,gap,room,separator,dimension}` = Box, Wall, Door, Window, Gap, Room, Separator, Dimension in English.
- Tasks 10-22: each tool's letter as the scope gives it (B, W, D, N, G, M, S, I); the type's property ids `thickness`, `justification` (wall), `width`, `position`, `flip-hinge`, `flip-swing` (opening), `name`, `area` (room), `value`, `kind`, `axes`, `end-1`, `end-2` (dimension), `width`, `height` (box); the wall tool's settings `thickness`, `justification`, the door tool's `width`.
- Task 11 (ruling R-P6): `K/test/support/wall_fixture.dart` with `ParametricCatalog testCatalog()` (every ported type registered under its `ArchitectureTypes` id, each type task appending its line) and `ParametricSystem installParametric(DraftDocument doc)`, and today's names (`kids`, `kindOf`, `payloadOf`, `worldWallOf`, `driftOf`, `enc`, `canon`).
- Task 18: `K/test/room/room_cost_test.dart` (RK1, RK2) with today's `median`, `cell`, `gridWalls`, `stripWalls`, `roomCells`, `addRooms` (`room_cost_test.dart:18-73`); the kit's `debugRoomGenerates` (`src/room/room.dart`) and `debugTracedSegments`, `traceRoomAmong`, `Traced` (`src/room/room_trace.dart`), `RoomInputs` (`src/room/room_inputs.dart`, over a `LiveTypeOf`, Task 16).
- Task 15: `OpeningTool` keeps `debugPreviewBuilds`; `isUsableHost(DraftDocument doc, Handle h)` keeps today's signature (`opening_tool.dart:447-450`).
- Task 16: `K/test/support/room_fixture.dart` with today's names (`W`, `Placement`, `corpusGroups`, `buildPlan`, `boxWalls`, `samplePlan`, `origin`, `Plan`).
- Task 20: `K/test/support/dimension_fixture.dart` with today's names (`groupFor`, `c5Walls`, `bruteCandidates`) and `attachCandidates(doc, index, q, {required LiveTypeOf live, required bool objectSnap, required double thickest})`, `thickestWall(doc, live)`.
- Task 23: the furniture library is `architectureKit.symbols.single`, its keys `architecture.<today's key>`; `architecture.sofa.two` has the family `sofa`.
- Tasks 21, 22: their carried port notes for `dimension_paint_test` and `dimension_shell_test` (`plan-parts/task-21.md` Interface problem 2, `task-22.md` Interface problem 1) are folded into Step 9 below; Task 18's for `room_paint_test` (`task-18.md` Interface problem 1).
- Task 25: `sampleFlatController()`; `buildSampleFlat` names the sample's rooms in the given words (English: Hall, Bedroom 1, Bedroom 2, Kitchen, Bath, Living, Dining) and keeps today's constants `kPlanOriginX = 12000`, `kPlanOriginY = 8000`, `kPlanWidth = 14000`, `kPlanHeight = 9000` (`startup_plan.dart:53-56`; the integration copies the four literals, they are not exported).

- [ ] **Step 1: Precondition.** Tasks 1-25 are committed. From the root:
  - `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice && flutter analyze` and `cd packages/jet_cad_2d_kit_architecture && flutter test && flutter analyze`: `All tests passed!`, `No issues found!`. Any other result is a finding for the task that owns it: stop.
  - `grep -n "vector_math\|pdf\|jet_cad_2d_kit:" packages/jet_cad_2d_integration/pubspec.yaml`. Missing `vector_math` or `pdf`: add under `dev_dependencies`, `vector_math: ^2.2.0`, `pdf: ^3.13.1` (the plan library's constraints, `packages/jet_cad_2d_plan/pubspec.yaml`); missing `jet_cad_2d_kit` (the tests name `PlanKit`, `KitNamesWords`, `FakePlanServices`): add `jet_cad_2d_kit: ^0.1.0` under `dependencies` (Global Constraints: "and what they export"). Then `flutter pub get` at the root, `git status --short` (restore a rewritten `analysis_options.yaml` with `git checkout -- <file>`).
  - Print the kit's tools: `grep -n "letter:" packages/jet_cad_2d_kit_architecture/lib/src/*/*_plan.dart`: eight letters B W D N G M S I. Print the property ids: `grep -n "id: '" packages/jet_cad_2d_kit_architecture/lib/src/*/*_plan.dart`. A difference from "Assumed from earlier tasks" changes this task's keys, not its assertions: write the difference into the report.

- [ ] **Step 2: The plan files and the architecture fixtures.** Create `I/test/support/plans.dart`. The parts copied from today's support files are named by line; every changed region is written out.

```dart
// Plan files for the integration tests (3a Task 26; Tasks 27 and 28 use
// them): a plan is built in a scratch controller's document, the plan
// library's own registration, page and system, then saved; a test opens
// the text with its own controller. The architecture fixtures are today's
// (jet_cad_floor_plan/test/support/wall_fixture.dart, wall_shell.dart,
// room_fixture.dart, dimension_fixture.dart): the wall fixture is Task 12's
// wall_fixture.dart and the room plan model Task 18's room_plans.dart,
// re-exported; the rest is re-stated over the kit's public parameters
// (spec C6: public libraries only).
import 'dart:math' as math;
import 'dart:ui' show Locale;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

// No import of editor_rig.dart or wall_fixture.dart: room_plans.dart
// re-exports every name of theirs this file's body uses (kids, kindOf,
// payloadOf, kitCatalog), and a second import of them is an
// `unnecessary_import` warning; the exports below need no import.
import 'room_plans.dart';

export 'editor_rig.dart' show kitCatalog;
export 'room_plans.dart'
    show W, S, O, Placement, origin, corpus, corpusGroups, km1000,
        km1000Axis, km1000Groups, placements, sampleWalls, sampleOpenings,
        sampleSeparator, sampleColumn, sampleSeeds, twoRoomWalls, boxWalls,
        recordOf, worldPoints, labelsOf, textOf, worldTintOf, pageOf,
        anchorOf, deleteObject, labelStrings, kindsOf;
export 'wall_fixture.dart'
    show ox, oy, far, plan, nextUp, polar, groupAt, oracleMeet, nearestIn,
        addWallLocal, addWall, kids, kindOf, payloadOf, pointsOf, sharedNear,
        isRectNear, enc, canon, worldOutline, walls, xy, facesOf,
        expectMitre, expectSquare, driftOf;

/// A plan file: a scratch controller over [kits] (made by [first], C1.9,
/// when given), [build] run on its document, then saved. Handles [build]
/// allocates survive the save: a controller that opens the text has them.
String planWith(void Function(DraftDocument d) build,
    {List<PlanKit>? kits, PlanBuild? first}) {
  final c = PlanController(kits: kits ?? [architectureKit], build: first);
  try {
    build(c.document);
    return c.save();
  } finally {
    c.dispose();
  }
}

/// The kit's words in English, as the scratch controller's are (C1.9).
final KitWords englishWords =
    KitNamesWords(architectureKit.names, () => const Locale('en'));

/// The sample flat's outer corner and size (startup_plan.dart:53-56;
/// buildSampleFlat keeps them, not exported).
const double kPlanOriginX = 12000.0, kPlanOriginY = 8000.0;
const double kPlanWidth = 14000.0, kPlanHeight = 9000.0;
```

  Then, in this order:
  1. Nothing copied from `jet_cad_floor_plan/test/support/wall_fixture.dart`: `ox`, `oy`, `far`, `plan`, `nextUp`, `polar`, `groupAt`, `oracleMeet`, `nearestIn`, `addWallLocal`, `addWall`, `kids`, `kindOf`, `payloadOf`, `pointsOf`, `sharedNear`, `isRectNear`, `enc`, `canon`, `worldOutline`, `driftOf` are Task 12's integration `wall_fixture.dart` (its public `WorldWall` reproduction), re-exported above.
  2. Besides them, the two world readers Task 28 uses (`worldEndsOf`, `faceOf`), written over the stored parameters:

```dart
/// Wall [h]'s world ends: its stored ends under its group's accumulated
/// transform (today's `WorldWall.s`, `.e`).
({Vector2 s, Vector2 e}) worldEndsOf(DraftDocument doc, Handle h) {
  final p = doc.components.get<WallParams>(h)!;
  final m = doc.tree.accumulatedTransform(h);
  return (
    s: m.transformPoint(Vector2(p.sx, p.sy)),
    e: m.transformPoint(Vector2(p.ex, p.ey)),
  );
}

/// The face line of the wall from [s] to [e] at [offset] along its left
/// normal, as two points (today's `face`, wall_fixture.dart:96-103).
(Vector2, Vector2) faceOf(Vector2 s, Vector2 e, double offset) {
  final dx = e.x - s.x, dy = e.y - s.y;
  final len = math.sqrt(dx * dx + dy * dy);
  final nx = -dy / len * offset, ny = dx / len * offset;
  return (Vector2(s.x + nx, s.y + ny), Vector2(e.x + nx, e.y + ny));
}
```

  3. `walls`, `xy`, `facesOf`, `expectMitre`, `expectSquare` (today's `wall_shell.dart:11-50`) are Task 12's `wall_fixture.dart`'s, re-exported above: nothing copied.
  4. `W`, `S`, `O`, `Placement`, the six placements and `placements` (today's `room_fixture.dart:28-99`) are Task 18's `room_plans.dart`'s, re-exported above; its `_groupFor` is private, so `buildPlan` uses item 6's `groupFor` (the same transform, `dimension_fixture.dart:34-40`). In place of `Plan` and `buildPlan` (`:101-162`), which made a document and its system, write:

```dart
/// The handles [buildPlan] added, in the order given, and its placement.
final class Plan {
  Plan(this.place, this.walls, this.seps, this.openings);
  final Placement place;
  final List<Handle> walls, seps, openings;

  Vector2 at(double x, double y) => place.at(x, y);
}

/// Today's `buildPlan` (room_fixture.dart:118-162) into [doc], which has
/// the plan's system (a [planWith] document): its creation of a document,
/// its system and its DASHED record are the plan library's here (C1.3).
Plan buildPlan(DraftDocument doc, List<W> walls,
    {List<S> seps = const [],
    List<W> wallsAfter = const [],
    List<O> openings = const [],
    Placement place = origin}) {
  final wh = <Handle>[], sh = <Handle>[], oh = <Handle>[];
  var k = 0;
  void addWalls(List<W> ws) {
    for (final w in ws) {
      final h = doc.handleSeed.next();
      final g = place.groups ? groupFor(place, k++) : Transform2.identity();
      final inv = g.invert();
      final s = inv.transformPoint(place.at(w.sx, w.sy));
      final e = inv.transformPoint(place.at(w.ex, w.ey));
      doc.commands.execute(CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: h,
            parent: doc.rootHandle,
            transform: g,
            children: const [])),
        SetComponentCommand<WallParams>(
            h, WallParams(s.x, s.y, e.x, e.y, w.t, w.j)),
      ], label: 'Add wall'));
      wh.add(h);
    }
  }

  addWalls(walls);
  for (final (sx, sy, ex, ey) in seps) {
    sh.add(addSeparator(doc, place.at(sx, sy), place.at(ex, ey),
        at: place.groups ? groupFor(place, k++) : null));
  }
  addWalls(wallsAfter);
  for (final (i, position, width, kind, swing) in openings) {
    oh.add(addOpening(
        doc, OpeningParams(wh[i], position, width, kind, swing: swing)));
  }
  return Plan(place, wh, sh, oh);
}
```

  5. Copy `room_fixture.dart:162-192` (`addSeparator`, `addOpening`), `:551-579` (`attachPage`, `addRoom`) and `:694-697` (`renameRoom`) unchanged (`samplePlan` is not copied: its `buildPlan` call takes a document now). `recordOf`, `worldPoints`, the sample plans, `twoRoomWalls`, `boxWalls`, `labelsOf`, `textOf`, `pageOf`, `anchorOf`, `deleteObject`, `labelStrings` and `kindsOf` are Task 18's `room_plans.dart`'s, re-exported above.
  6. Copy `jet_cad_floor_plan/test/support/dimension_fixture.dart:34-40` (`groupFor`), `:99-101` (`c5Walls`), `:368-403` (`addDimension`, `fixedAt`, `dimTextHandle`, `dimText`) unchanged; `:405-422` (`dimLines`) unchanged. (`dimTextGeometry`, `:424-435`, is not copied: no integration test reads it.)
  7. Write the sample plans the integration tests open:

```dart
/// Today's touch_tools_test `samplePlan()`: D23's nine walls and the
/// column, the separator and the fifteen openings at the origin (no
/// rooms, no page change).
String d23PlanJson() => planWith((d) => buildPlan(
    d, [...sampleWalls(), sampleColumn],
    seps: const [sampleSeparator], openings: sampleOpenings));
```

  The file imports neither `dart:convert` nor `dart:typed_data`: `canon` and `nextUp` are Task 12's `wall_fixture.dart`'s. An import the file no longer uses once written is dropped (`unused_import` is an error).

- [ ] **Step 3: The units, by hand.** Create `I/test/support/units.dart`:

```dart
// The fixture kit `fx` and its units (3a Task 26), ported from
// jet_cad_2d_plan's test/support/unit_fixtures.dart (2b Tasks 6 and 8) and
// symbol_fixtures.dart's leafRecord. The plan's placer and its label
// command are not exported (spec C6), so placeUnit and labelUnit re-state
// their no-thumbnail path over the engine's commands and the contract's
// label helpers: a definition copied once per key and version
// (symbol_placer.dart:100-142), an instance on the given layer
// (:206-219), and a UNIT label owned by the instance, anchored at the
// base point, the height of the first leaf's top, stamped upright
// (unit_label.dart:55-75, 134-186).
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/authoring.dart'
    show
        Catalog,
        CatalogCircle,
        CatalogLine,
        CatalogPolyline,
        CatalogSymbol,
        CatalogUnit,
        encodeLibrary;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart' show PlanController;
import 'package:vector_math/vector_math_64.dart' show Vector2;

const String fxKitId = 'fx';

/// The fixtures' kit: no type, no tool; with [library], a symbol library
/// of those symbols (the Symbols tab offers them).
PlanKit fxKit({List<CatalogSymbol> library = const []}) => PlanKit(
      id: fxKitId,
      version: '1.0.0',
      symbols: [
        if (library.isNotEmpty)
          SymbolLibrarySource(
              label: 'fx',
              read: () async =>
                  encodeLibrary(Catalog(kit: fxKitId, symbols: library))),
      ],
    );
```

  Then copy `jet_cad_2d_plan/test/support/symbol_fixtures.dart:57-70` (`leafRecord`) and `unit_fixtures.dart:45-67` (`tableUnit`, `tableSymbol`), `:125-170` (`entryOf`), `:182-189` (`kDeg37`, `placementAt`), `:301-315` (`addLayer`) unchanged, and the 2b unit editor fixture's symbols `jet_cad_2d_plan/test/support/unit_editor_fixture.dart:41-80` (`embeddingTable`, `embeddingBox`, `editorChair`, `embeddingPlacement`) unchanged. Then write:

```dart
/// [s] placed by [transform] on [layer] (layer 0 by default), one step:
/// its definition copied unless a live one of its key and version is there
/// (the placer's reuse, less its leaf-equality check: fixture symbols are
/// never edited). Returns the instance.
Handle placeUnit(DraftDocument doc, CatalogSymbol s,
    {required Transform2 transform, Handle? layer}) {
  final entry = entryOf(s);
  final commands = <DraftCommand>[];
  Handle? definition;
  for (final h in doc.components.withComponent<SymbolComponent>()) {
    final c = doc.components.get<SymbolComponent>(h)!;
    if (c.key == entry.symbol.key &&
        c.version == entry.symbol.version &&
        doc.tree.definition(h) != null) {
      definition = h;
      break;
    }
  }
  if (definition == null) {
    final copy = doc.handleSeed.next();
    commands
      ..add(AddDefinitionCommand(Definition(
          handle: copy,
          name: entry.symbol.id,
          basePoint: entry.definition.basePoint,
          children: const [])))
      ..add(SetComponentCommand<SymbolComponent>(copy, entry.symbol));
    if (entry.unit case final unit?) {
      commands.add(SetComponentCommand<UnitComponent>(copy, unit));
    }
    for (final leaf in entry.leaves) {
      commands.add(AddEntityCommand(
          record:
              leaf.record.copyWith(handle: doc.handleSeed.next(), owner: copy),
          payload: leaf.payload));
    }
    definition = copy;
  }
  final h = doc.handleSeed.next();
  commands.add(AddNodeCommand(InstanceNode(
      handle: h,
      parent: doc.rootHandle,
      definition: definition,
      layer: layer ?? ReservedHandles.layerZero,
      transform: transform)));
  doc.commands.execute(CompoundCommand(commands, label: 'Place ${s.name}'));
  return h;
}

/// [s] with its base point at [at], [quarterTurns] counter-clockwise and
/// [mirrored] (unit_fixtures.dart:273-283, over the contract's transform).
Handle placeAt(DraftDocument doc, CatalogSymbol s, Vector2 at,
        {int quarterTurns = 0, bool mirrored = false}) =>
    placeUnit(doc, s,
        transform: placementTransform(
            at: at,
            basePoint: Vector2(s.base.$1, s.base.$2),
            quarterTurns: quarterTurns,
            mirrored: mirrored));

/// The box of [definition]'s lowest-handle leaf when it is a circle or a
/// polyline, else empty (the plan's `placedLabelTopOf`,
/// unit_label.dart:134-164, the label height's rule, ruling R-21).
Aabb2 labelTopOf(DraftDocument doc, Handle definition) {
  int? first;
  for (final slot in doc.entities.liveSlots) {
    if (doc.entities.ownerAt(slot) != definition) continue;
    if (first == null ||
        doc.entities.handleAt(slot).value <
            doc.entities.handleAt(first).value) {
      first = slot;
    }
  }
  if (first == null) return Aabb2.empty();
  final p = doc.geometry.read(doc.entities.geomIndexAt(first));
  switch (doc.entities.kindAt(first)) {
    case EntityKind.circle:
      final r = p.scalars[0];
      return Aabb2.raw(
          p.coords[0] - r, p.coords[1] - r, p.coords[0] + r, p.coords[1] + r);
    case EntityKind.polyline:
      final c = p.coords;
      var minX = c[0], maxX = c[0], minY = c[1], maxY = c[1];
      for (var i = 2; i + 1 < c.length; i += 2) {
        minX = math.min(minX, c[i]);
        maxX = math.max(maxX, c[i]);
        minY = math.min(minY, c[i + 1]);
        maxY = math.max(maxY, c[i + 1]);
      }
      return Aabb2.raw(minX, minY, maxX, maxY);
    default:
      return Aabb2.empty();
  }
}

/// [text] as [instance]'s UNIT label, one step; the label's handle.
Handle labelUnit(DraftDocument doc, Handle instance, String text) {
  final node = doc.tree[instance]! as InstanceNode;
  final def = doc.tree.definition(node.definition)!;
  final h = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: h,
      owner: instance,
      kind: EntityKind.attrib,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byBlockLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByBlockColor(),
      lineweight: kByBlock,
      transparency: kByBlock,
      flags: 0,
      text: text,
      tag: kUnitLabelTag,
      textStyle: ReservedHandles.standardTextStyle,
      textAttrs: kUnitLabelTextAttrs,
    ),
    payload: unitLabelPayload(
      anchor: def.basePoint,
      height: unitLabelHeight(labelTopOf(doc, node.definition)),
      instanceToWorld: node.transform,
    ),
  ));
  return h;
}

/// The instances of [doc] whose UNIT label reads [label] trimmed, by
/// handle (today's `TableSurvey.withNumber`, 2b's `withLabel`).
List<Handle> unitsLabelled(DraftDocument doc, String label) {
  final out = <Handle>[];
  for (final slot in doc.entities.liveSlots) {
    final r = doc.entities.read(slot);
    if (r.kind == EntityKind.attrib &&
        r.tag == kUnitLabelTag &&
        r.text.trim() == label.trim()) {
      out.add(r.owner);
    }
  }
  return out..sort((a, b) => a.value.compareTo(b.value));
}

/// Table [n]'s instance; ` 7 ` is the later of the two sevens, null the
/// unlabelled unit (2b's `tableOf`, unit_editor_fixture.dart:228-236).
Handle tableOf(PlanController c, String? n) {
  final d = c.document;
  if (n == null) {
    final labelled = {
      for (final slot in d.entities.liveSlots)
        if (d.entities.read(slot).tag == kUnitLabelTag)
          d.entities.ownerAt(slot),
    };
    return d.tree.nodes
        .whereType<InstanceNode>()
        .where((i) =>
            d.components.get<UnitComponent>(i.definition) != null &&
            !labelled.contains(i.handle))
        .single
        .handle;
  }
  return unitsLabelled(d, n)[n == ' 7 ' ? 1 : 0];
}
```

  `EntityRecord.tag` and `.text` are the engine's record fields (`unitLabelRecord` sets them, `jet_cad_2d_plan/lib/src/units/unit_label.dart:71-72`).

- [ ] **Step 4: The editor fixture.** Create `I/test/support/editor_fixture.dart` from `jet_cad_2d_plan/test/support/unit_editor_fixture.dart` (2b), the sample flat restored:
  - header: `// 2b's unit editor fixture (jet_cad_2d_plan/test/support/unit_editor_fixture.dart), ported for the integration tests (3a Task 26) with today's startup flat restored (jet_cad_floor_plan/test/host/editor_fixture.dart): the stand-in lines for the north wall, its inner face, the column and the parquet hairline are gone, the flat draws them. Same world coordinates, same camera.`
  - imports: `dart:math` as math, `dart:ui` as ui, `package:flutter/material.dart`, `package:flutter/services.dart` show `LogicalKeyboardKey`, `package:flutter_test/flutter_test.dart`, `package:jet_cad_2d/jet_cad_2d.dart`, `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart` show `InteractionLayer`, `SelectionKey`, `ViewportTransform`, `package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart`, `package:jet_cad_2d_plan/jet_cad_2d_plan.dart`, `package:vector_math/vector_math_64.dart` show `Vector2`, `'plans.dart'`, `'units.dart'`.
  - copy `unit_editor_fixture.dart:35-38` (`kEditorSurface`, `kEmbeddingHidden`, `kEmbeddingLocked`), `:82-111` (`EditorTable`, `editorTables`, `editorChairPlacement`, `editorGroupPlacement`, `editorFreeLine`, `editorTextAt`, `editorTextHeight`, `editorTextWords`) unchanged; drop `:112-129` (the stand-ins); add today's `editorColumnCorner` (`jet_cad_floor_plan/test/host/editor_fixture.dart:109`): `final Vector2 editorColumnCorner = Vector2(23500, 13800);`.
  - `unitEditorPlanJson()` (`:131-182`) becomes:

```dart
/// The fixture's plan: the sample flat (C1.9's build, English words),
/// then 2b's units, group, free line, TEXT and chair, over
/// [architectureKit] and [fxKit].
String editorPlanJson() => planWith(
    (doc) {
      final zero = ReservedHandles.layerZero;
      final hidden = addLayer(doc, kEmbeddingHidden, visible: false);
      final locked = addLayer(doc, kEmbeddingLocked, locked: true);
      for (final t in editorTables) {
        final h = placeUnit(doc, embeddingTable,
            transform: t.transform,
            layer: switch (t.layer) {
              kEmbeddingHidden => hidden,
              kEmbeddingLocked => locked,
              _ => zero,
            });
        if (t.label case final label?) labelUnit(doc, h, label);
      }
      final group = doc.handleSeed.next();
      doc.commands.execute(AddNodeCommand(GroupNode(
          handle: group,
          parent: doc.rootHandle,
          transform: editorGroupPlacement,
          children: const [])));
      for (final (a, b) in [
        (Vector2(100, 100), Vector2(900, 400)),
        (Vector2(100, 400), Vector2(900, 100)),
      ]) {
        doc.commands.execute(AddEntityCommand(
            record: draftRecord(doc.handleSeed.next(), group, EntityKind.line,
                layer: zero),
            payload: linePayload(a, b)));
      }
      doc.commands.execute(addDrafted(doc, EntityKind.line,
          linePayload(editorFreeLine.$1, editorFreeLine.$2),
          layer: zero));
      doc.commands.execute(addDrafted(
          doc, EntityKind.text, textPayload(editorTextAt, editorTextHeight),
          layer: zero, text: editorTextWords));
      placeUnit(doc, editorChair, transform: editorChairPlacement);
    },
    kits: [architectureKit, fxKit()],
    first: buildSampleFlat);
```

  - copy `:182-221` (`editorCamera`, `mountUnitEditor` renamed `mountEditor`, `setPermissions`, `canvasOrigin`, `screenOf`) with `PlanController(kits: [fxKit()], json: unitEditorPlanJson())` → `PlanController(kits: [architectureKit, fxKit()], json: json ?? editorPlanJson())` and a named parameter `String? json` added to `mountEditor`; drop `:223-235`'s `unitsIn` and `tableOf` (Step 3's `tableOf` replaces them, public); copy `:237-254` (`centreOf`, `click`) unchanged and `:262-263` (`editorKits`, returning `[architectureKit, fxKit()]`); `press` (`:256-260`) is not copied: Task 9's `editor_rig.dart` has it, the same.
  - copy `jet_cad_2d_plan/test/editor/units_only_select_test.dart:28-124` (`encoded`, `keyOf`, `transformOf`, `onTable`, `topOf`, `boxOf`, `edgeOf`, `startOf`, `isLine`, `selected`, `drag`, `fingerTap`, `rotationGripOf`, `degreesOf`, `canvasRect`) with `c.selection` → `c.activeSelection` (`:69`) and `coordsOf(d, line)` (`:58`, 2a's harness) → `d.geometry.read(d.entities.geomIndexAt(d.entities.slotOf(line)!)).coords`.
  - add 2b's `encodedPlan` for the key tests: `String encodedPlan(PlanController c) => DraftDocumentCodec.encodeToString(c.document);` (`plan_shortcuts_test.dart:141-142`).

- [ ] **Step 5: The canvas rig.** Create `I/test/support/canvas_rig.dart`:

```dart
// Cameras, gestures and read-outs for the integration tests (3a Task 26),
// beside Task 9's editor_rig.dart (re-exported: activeTool, globalOf with
// x and y, globalAt with a point, kitCatalog, press, status),
// over the public widgets: today's PlannerView handles (its camera, its
// selection, its tools) are the controller's camera and selection and the
// InteractionLayer's tool controller (spec C6, ruling IT-R1).
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show GripCache, InteractionLayer, ViewportTransform;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'editor_rig.dart' show press;

export 'editor_rig.dart'
    show activeTool, globalAt, globalOf, kitCatalog, press, status;

Finder byKey(String k) => find.byKey(Key(k));

/// One field whatever its scope: the object's `property-<id>` or the
/// active tool's `setting-<id>` (today's shell keyed both alike; ruling
/// IT-R7).
Finder field(String id) => find.byWidgetPredicate((w) =>
    w.key == Key('property-$id') || w.key == Key('setting-$id'));

/// The section of [typeId] or the settings of [toolId] (today's
/// `<type>-section`, shown for the object and for its tool).
Finder section(String typeId, String toolId) => find.byWidgetPredicate(
    (w) => w.key == Key('section-$typeId') || w.key == Key('settings-$toolId'));

/// [c] in a [PlanEditor] in a [size] window, in [locale], two frames.
Future<void> pumpPlanEditor(WidgetTester tester, PlanController c,
    {Size size = const Size(1440, 900),
    Locale? locale,
    bool layerPanel = true}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      locale: locale,
      supportedLocales: planSupportedLocales,
      localizationsDelegates: planLocalizationsDelegates,
      home: Scaffold(
          body: PlanEditor(controller: c, layerPanel: layerPanel))));
  await tester.pump();
  await tester.pump();
}

/// The camera on world [centre] at [scale] px/mm, y up, turned [turn]
/// radians on the screen; set after the editor's first fit.
Future<void> frameOn(WidgetTester tester, PlanController c, Vector2 centre,
    {required double scale, double turn = 0}) async {
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear =
      Transform2.rotation(turn).multiply(Transform2.scale(scale, -scale));
  final mid = linear.transformPoint(centre);
  c.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
}

/// The selection's grips and box: the cache the plan hands its tools in
/// their context (`InteractionLayer.tools.context.grips`; ruling IT-R12).
GripCache gripsOf(WidgetTester tester) => tester
    .widget<InteractionLayer>(find.byType(InteractionLayer))
    .tools
    .context
    .grips!;

/// A key press and a pump; whether a handler took it: the rig's [press]
/// under today's name.
Future<bool> pressKey(WidgetTester tester, LogicalKeyboardKey key) =>
    press(tester, key);

/// A mouse resting at [at], then a press and a release there.
Future<void> mouseClick(WidgetTester tester, Offset at) async {
  final g = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
  await g.addPointer(location: at - const Offset(3, 3));
  await g.moveTo(at);
  await tester.pump();
  await g.down(at);
  await tester.pump();
  await g.up();
  await tester.pump();
  await g.removePointer();
  await tester.pump();
}

/// The canvas's own focus node.
FocusNode canvasFocus(WidgetTester tester) => tester
    .widget<Focus>(find
        .descendant(
            of: find.byType(InteractionLayer), matching: find.byType(Focus))
        .first)
    .focusNode!;

/// A click a little inside the canvas's top left: the canvas takes focus.
Future<void> focusCanvas(WidgetTester tester) async {
  await tester.tapAt(
      tester.getTopLeft(find.byType(InteractionLayer)) + const Offset(6, 6));
  await tester.pump();
  expect(FocusManager.instance.primaryFocus, same(canvasFocus(tester)),
      reason: 'premise: the canvas focused');
}

/// Whether the canvas (or a node under it) has the focus.
bool canvasFocused() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context != null &&
      context.findAncestorWidgetOfExactType<InteractionLayer>() != null;
}

/// The menu of the choice [id] opened and its value [segment] tapped (a
/// `ChoiceProperty` is a dropdown; ruling IT-R6). Nothing when the menu
/// does not open (a disabled choice): today's tap on a disabled segment.
Future<void> choose(WidgetTester tester, String id, String segment) async {
  final menu = field(id);
  final key = (tester.widget(menu).key! as ValueKey<String>).value;
  await tester.tap(menu);
  await tester.pumpAndSettle();
  final item = byKey('$key-$segment');
  if (item.evaluate().isEmpty) return;
  await tester.tap(item.last);
  await tester.pumpAndSettle();
}

/// The choice [id]'s dropdown.
DropdownButton<Object?> menuOf(WidgetTester tester, String id) =>
    tester.widget<DropdownButton<Object?>>(field(id));
```

- [ ] **Step 6: P-6's layers as a plan.** Create `I/test/support/layer_plan.dart` from `jet_cad_floor_plan/test/support/layer_fixture.dart`:
  - header: `// P-6's layer fixture (jet_cad_floor_plan/test/support/layer_fixture.dart), as a plan file (3a Task 26): layers A (ACI 1), B (ACI 5, locked), C (ACI 3, hidden), the box of four walls on A in rotated groups at the corpus far origin, a door on B, optionally a room on A and a dimension on B; and the picker's extras (a layer D, a line, a region, a symbol on A).`
  - copy `:50-77` (`onLayer`, `addObjectOn`) unchanged.
  - `LayerDoc` (`:30-48`) keeps its fields but `doc` and `system`: the handles live on; the class becomes `final class LayerPlan { LayerPlan(this.place, this.a, this.b, this.c); ... }` with `walls`, `openings`, `room`, `dimension`, `at()` as today.
  - `layerDoc` (`:79-109`) becomes a function over a [planWith] document, the layers added by `AddLayerCommand` as today, no registration, no system, no DASHED (the scratch controller has them):

```dart
/// P-6's layers on [doc], at [place].
LayerPlan layersOn(DraftDocument doc, {Placement place = corpusGroups}) {
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  Handle add(String name, int aci, {bool visible = true, bool locked = false}) {
    final handle = doc.handleSeed.next();
    doc.commands.execute(AddLayerCommand(LayerRecord(
      handle: handle,
      name: name,
      color: IndexedColor(aci),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: visible,
      locked: locked,
    )));
    return handle;
  }

  final a = add('A', 1);
  final b = add('B', 5, locked: true);
  final c = add('C', 3, visible: false);
  return LayerPlan(place, a, b, c);
}
```

  - copy `addWallsOn` (`:111-129`), `layerFixture` (`:131-161`), `addLineOn` (`:163-177`), `addRegionOn` (`:179-209`), `addSymbolOn` (`:211-249`), `layerOf`, `objectLayerOf`, `moveObject` (`:251-262`) with `l.doc` → a `DraftDocument doc` first parameter (`addWallsOn(doc, l, walls, layer)`, `layerFixture(doc, {room, dimension})` calling `layersOn(doc)` and dropping `doc.commands.clearHistory()`, `addLineOn(doc, l, ...)`, `addRegionOn(doc, l, ...)`, `addSymbolOn(doc, l, ...)`); bodies otherwise unchanged. Drop `toolContextOf`, `_pointerAt`, `clickWith` (`:264-303`: the kit's copy has them, Step 7).
  - add the app test's picker fixture (`apps/floor_planner/test/layers/layer_picker_test.dart:33-65`, `PickerDoc`) as a plan:

```dart
/// The app's picker fixture: P-6 without room and dimension, a visible
/// layer D, a line, a region with a second fill and a symbol, all on A.
({String json, LayerPlan l, Handle d, Handle line, Handle wall, Handle door})
    pickerPlan() {
  late LayerPlan l;
  late Handle d, line;
  final json = planWith((doc) {
    l = layerFixture(doc, room: false, dimension: false);
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    d = doc.handleSeed.next();
    doc.commands.execute(AddLayerCommand(LayerRecord(
        handle: d,
        name: 'D',
        color: const IndexedColor(2),
        linetype: zero.linetype,
        lineweight: zero.lineweight,
        transparency: zero.transparency)));
    line = addLineOn(doc, l, l.a, 1250.5, 3400.25, 4100.75, 3650.5);
    addRegionOn(doc, l, l.a, 7300.5, 2100.25, 350);
    addSymbolOn(doc, l, l.a, 2600.5, 1800.75);
  });
  return (
    json: json,
    l: l,
    d: d,
    line: line,
    wall: l.walls.first,
    door: l.openings.single
  );
}
```

  (Today's `PickerDoc.wall` and `.door` are `l.walls.first` and `l.openings.single`: `layer_picker_test.dart:63-64`; check them there before writing.)

- [ ] **Step 7: The kit's layer fixture.** Create `K/test/support/layer_fixture.dart` from `jet_cad_floor_plan/test/support/layer_fixture.dart`, every line kept but:
  - imports: `parametric/catalog.dart`, `dimension.dart`, `opening.dart`, `room.dart`, `separator.dart`, `wall.dart` → `package:jet_cad_2d_kit_architecture/src/dimension/dimension.dart`, `src/opening/opening.dart`, `src/room/room.dart`, `src/wall/wall.dart`, `src/separator_linetype.dart` (show `ensureDashedLinetype`); add `package:jet_cad_2d_kit/jet_cad_2d_kit.dart`, `package:jet_cad_2d_kit/testing.dart`, `package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart` (show `architectureKit`) and `'wall_fixture.dart'` (show `testCatalog`, `installParametric`); `'dimension_fixture.dart'` stays (Task 20's port).
  - `layerDoc` (`:79-109`): `registerAppComponents(doc.components); final system = installParametric(doc);` → `PageComponent.register(doc.components); testCatalog().registerComponents(doc.components); final system = installParametric(doc);` (ruling R-P6's names; today's `registerAppComponents` registered the page, the catalog and the table components, `catalog.dart:55-62`, of which the layer tests read none but the first two).
  - add after `clickWith`:

```dart
/// The kit's tool [toolId] over plan services on [l]'s document: the kit's
/// test catalog (the live types), object snap on, one pixel per mm (as
/// [toolContextOf]'s camera), and each tool's initial settings. The
/// services are disposed at tear-down.
Tool toolOf(LayerDoc l, String toolId) {
  final services = FakePlanServices(
      document: l.doc,
      catalog: testCatalog(),
      settings: {
        for (final t in architectureKit.tools)
          if (t.settings case final s?) t.id: s.initial,
      });
  addTearDown(services.dispose);
  final tool = architectureKit.tools
      .singleWhere((t) => t.id == toolId)
      .create(services);
  addTearDown(tool.dispose);
  return tool;
}
```

- [ ] **Step 8: The kit's layer tests.** Each file is the source, assertions unchanged; the adaptations are listed in full.
  1. `K/test/layers/tools_layer_test.dart` from `layers/tools_layer_test.dart`, every case but "the symbol placer puts the instance on the current layer" (`:230-256`, Step 9):
     - header comment kept, plus `// Ported to jet_cad_2d_kit_architecture (3a Task 26, spec C7): the kit's tools over FakePlanServices; the placer's case runs in jet_cad_2d_integration.`
     - imports: drop `box_tool.dart`, `dimension_tool.dart`, `opening_tool.dart`, `room_inputs.dart`, `room_tool.dart`, `separator_tool.dart`, `wall_tool.dart`, `symbol_library.dart`, `symbol_placer.dart`, `flutter/foundation.dart`, `support/symbol_fixtures.dart`; `box.dart`, `dimension.dart`, `opening.dart`, `room.dart`, `separator.dart`, `wall.dart` → the kit's `src/` files of the same names; add `package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart` (show `ArchitectureTools`); `support/wall_fixture.dart` (Task 11's port) for `worldWallOf`.
     - each tool's construction (`BoxTool()`, `WallTool(settings)` with its `ValueNotifier`, `OpeningTool(OpeningKind.door, settings)`, `SeparatorTool(inputs)` with its `RoomInputs`, `RoomTool(inputs)`, `DimensionTool()`) and its `addTearDown` → `final tool = toolOf(l, ArchitectureTools.<box|wall|door|separator|room|dimension>);` (the services make and dispose the shared `RoomInputs` and `WallBands`, spec C2); the hidden-wall case's `WallTool` likewise.
     - nothing else changes: `toolContextOf`, `clickWith`, `expectCreatedOn`, `onB`, `addWallsOn` are the fixture's.
  2. `K/test/layers/opening_host_layer_test.dart` from `layers/opening_host_layer_test.dart`, every case:
     - imports: `live_objects.dart` dropped; `opening.dart`, `opening_tool.dart` → the kit's `src/opening/opening.dart`, `src/opening/opening_tool.dart`; `flutter/foundation.dart` dropped; add the kit barrel (show `ArchitectureTools`).
     - `openingsOf` (`:21-22`) → `List<Handle> openingsOf(DraftDocument doc) => doc.components.withComponent<OpeningParams>().toList();` (no object of the fixture is frozen: today's `liveObjectsOf` and this list are equal, a fixture change).
     - `hostOfClick`'s tool (`:28-35`) and the fourth case's (`:96-102`) → `toolOf(fx, ArchitectureTools.window)`; the fourth case reads `(tool as OpeningTool).debugPreviewBuilds` (`:103`, `:105`, `:111`, `:113`): the services hand the kit's own tool back, unguarded.
  3. `K/test/layers/attach_layer_test.dart` from `layers/attach_layer_test.dart`, every case:
     - imports: `dimension_attach.dart`, `dimension_geometry.dart`, `opening.dart` → the kit's `src/dimension/dimension_attach.dart`, `src/dimension/dimension.dart` (which re-exports the geometry, Task 20), `src/opening/opening.dart`.
     - `attachCandidates(doc, index, q, objectSnap: true, thickest: thickestWall(doc))` (`:40-41`, `:124-125`) → `attachCandidates(doc, index, q, live: live, objectSnap: true, thickest: thickestWall(doc, live))` with `final live = liveOf(doc);` (Task 16's fixture: the catalog's `typeIdOf`, no frozen object) declared before `got`.
  4. `K/test/intersection_snap_test.dart` from `intersection_snap_test.dart`, the one case, assertions unchanged: imports `support/room_fixture.dart` show `origin, samplePlan` (Task 16's port; the plan's `system` is its own, disposed at tear-down as today, `:94`); `kSnapAperturePixels`, `kIntersectionCandidateCap`, `SnapMask`, `SnapKind`, `resolveDragPoint`, `DragPoint`, `SnapResult` are the engine's and the Flutter layer's, as today.
  5. `K/test/room/room_cost_test.dart` (Task 18's file) gains LZ3 (`room_cost_test.dart:76-174`: `kSampleRebuildSegments` and the case), assertions unchanged (ruling IT-R15):
     - the header's last line (Task 18's "LZ3 … lands with the sample flat (Task 25)") → `// LZ3 runs on buildSampleFlat (3a Task 26, rulings R-P1, R-P10).`
     - imports added: `package:flutter/widgets.dart` show `Locale`, `package:jet_cad_2d_kit/jet_cad_2d_kit.dart` show `KitNamesWords`, the kit barrel (show `architectureKit`, `buildSampleFlat`), `package:jet_cad_2d_kit_architecture/src/room/room_inputs.dart`, `src/room/room_trace.dart`, `src/wall/wall.dart`, `../support/wall_fixture.dart` (show `installParametric`, `testCatalog`), `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart` show `FlutterTextMeasurer` (if Task 18 did not keep it), and `../support/room_fixture.dart`'s `labelStrings`, `driftOf`.
     - `final doc = startupPlan(m); final system = installParametric(doc); addTearDown(system.dispose);` (`:104-106`) →

```dart
      final doc = DraftDocument.empty(measurer: m);
      PageComponent.register(doc.components);
      testCatalog().registerComponents(doc.components);
      doc.header.units = DrawingUnits.millimeters;
      architectureKit.prepare?.call(doc);
      doc.commands.execute(SetComponentCommand<PageComponent>(
          doc.rootHandle, PageComponent(originX: -7425, originY: -5250)));
      final system = installParametric(doc);
      addTearDown(system.dispose);
      buildSampleFlat(
          doc, KitNamesWords(architectureKit.names, () => const Locale('en')));
```

       (the plan's new plan as `newPlanDocument` makes it, then C1.9's build; Task 25's `startup_plan_test` port does the same, its helper reused when it has one).
     - `RoomInputs(doc)` (`:154`) → `RoomInputs(doc, liveOf(doc))` (Task 16's `RoomInputs` over a `LiveTypeOf`; `liveOf` from its fixture); the rest unchanged.
  - Run `cd packages/jet_cad_2d_kit_architecture && flutter test test/layers test/intersection_snap_test.dart test/room/room_cost_test.dart`. Expected: `All tests passed!` (the behaviour exists since Tasks 10-22). A failure is a finding for the type task that owns the code: stop and report it with the red line.

- [ ] **Step 9: The integration ports.** Each file opens with `// Ported from jet_cad_floor_plan/test/<source> (3a Task 26, spec C6); assertions unchanged.` and the source's own header comment.
  1. `I/test/canvas/touch_tools_test.dart` from `touch_tools_test.dart`, TD1 only (TD2 is 2a's):
     - imports: drop `live_objects.dart`, `room.dart`, `planner_shell.dart`, `planner_view.dart`, `support/room_fixture.dart`; add the kit barrel, the plan barrel, `package:jet_cad_2d_integration/jet_cad_2d_integration.dart`, `'../support/plans.dart'`, `'../support/canvas_rig.dart'`.
     - `pumpPlan` (`:21-30`) → `final c = architectureController(json: d23PlanJson()); addTearDown(c.dispose); await pumpPlanEditor(tester, c); await frameOn(tester, c, Vector2(19000, 12500), scale: 0.05);` (ruling IT-R5); `screenOf(tester, view, w)` → `globalAt(tester, c, w)`; `rooms(doc)` → `doc.components.withComponent<RoomParams>().toList()` (nothing frozen); `view.document` → `c.document`; `view.camera.value.scale` → `c.camera.value.scale`; `press(tester, keyM)` → `pressKey`.
     - `finger` (`:37-38`) and `pinch` (`:51-66`) copied unchanged.
  2. `I/test/shell/planner_shell_test.dart` from `planner_shell_test.dart`, the three cases "a click on a wall selects it in the running shell" (`:263-285`), "cmd+Z undoes a Delete through the command log" (`:287-387`, its comment `:287-288` with it), "ctrl+Z after deleting two walls brings both back in one step" (`:389-478`):
     - imports: drop every `jet_cad_floor_plan` import and `flutter/rendering.dart`; add the kit barrel, the plan barrel, the integration library, `'../support/plans.dart'` (show `kPlanOriginX`, `kPlanOriginY`, `kPlanWidth`, `kPlanHeight`), `'../support/canvas_rig.dart'`.
     - helpers copied unchanged: `wallFrom`, `e1Of`, `e4Of`, `openingsOf`, `roomsNamed`, `childrenOf`, `liveHandles`, `lowestY` (`:17-78`, but `dimensionsOn`); `dimensionsOn` (`:45-52`) reads the dimension's references as today's `DimensionType.references` defines them (its attached ends' walls, `dimension.dart:132-153`), the type being kit-internal:

```dart
/// The dimensions measuring [wall], ascending: a dimension references the
/// walls of its attached ends (today's DimensionType.references,
/// jet_cad_floor_plan/lib/src/parametric/dimension.dart:150).
List<Handle> dimensionsOn(DraftDocument doc, Handle wall) => [
      for (final d in doc.components.withComponent<DimensionParams>())
        if ([
          for (final end in [
            doc.components.get<DimensionParams>(d)!.a,
            doc.components.get<DimensionParams>(d)!.b,
          ])
            if (end is AttachedEnd) end.wall
        ].contains(wall))
          d
    ]..sort((a, b) => a.value.compareTo(b.value));
```

     - `pumpSample` (`:80-89`) → `Future<PlanController> pumpSample(WidgetTester tester) async { final c = sampleFlatController(); addTearDown(c.dispose); await pumpPlanEditor(tester, c); return c; }` (1440 x 900, ruling IT-R4; the first fit is the page's, as today's shell's).
     - in each case `tester.widget<PlannerView>(...)` → the controller; `view.camera` → `c.camera`; `view.selection` → `c.activeSelection`; `view.document` → `c.document`; nothing else.
  3. `I/test/canvas/planner_grips_test.dart` from `planner_grips_test.dart`, all five cases (ruling IT-R3):
     - imports: drop the two `jet_cad_floor_plan` imports; add the plan barrel, the integration library, `'../support/canvas_rig.dart'`.
     - `addLine`, `payloadOf`, `mouseDrag`, `cmdZ`, `osnapText` copied unchanged (`:13-32`, `:50-51`, `:80-100`); `selectLine` (`:102-106`) copied with `PlannerView view` → `PlanController c` (its `globalOf` is the rig's).
     - `shellScene(measurer)` (`:34-48`) keeps its body and returns, besides, the plan file: after `doc.commands.clearHistory()`, `final json = ensureManifest(DraftDocumentCodec.encodeToString(doc));` and the record gains `json`.
     - `pumpShell(tester, doc)` (`:53-73`) → over `architectureController(json: s.json)` in `pumpPlanEditor` (1440 x 900), then the same rotated, zoomed camera (`:63-71`) set on `c.camera`; it returns the controller.
     - `globalOf(tester, view, x, y)` → `globalOf(tester, c, x, y)` (Task 9's rig); `view.selection.keys` → `c.activeSelection.keys`; `view.tools.active.phase` → `activeTool(tester).phase`; `s.doc` → `c.document` (the plan's document, which holds the lines under the same handles).
  4. `I/test/editor/editor_panels_test.dart` from `host/editor_panels_test.dart`, the five cases (`:133-212`, `:214-229`, `:233-280`, `:633-653`, `:677-691`):
     - imports: the plan barrel, the kit barrel, `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart` show `SelectionKey`, `'../support/editor_fixture.dart'`, `'../support/units.dart'`, `'../support/canvas_rig.dart'`.
     - `select` (`:37-41`), `fieldOf`, `typeIntoReadOnly`, `typeAndSubmit` (`:44-65`) copied; `fieldOf(tester, key)` reads `tester.widget<TextField>(field(id))` with the old key mapped to an id below; `firstOf<T>(d)` → `d.components.withComponent<T>().first`; `doorOf(d)` → the first `OpeningParams` whose kind is a door, by handle.
     - `t.mountEditor(tester, caps: X)` → `mountEditor(tester, permissions: X)`; `Caps.full` → `PlanPermissions.full`; `s.setCaps(tester, h, X)` → `setPermissions(tester, c, X)`; `s.tableOf(c, '1')` → `tableOf(c, '1')`; `s.encoded(c)` → `encoded(c)`; `s.edgeOf(c, '1')` → `edgeOf(c, '1')`; `t.click(tester, t.screenOf(tester, c, w))` → `click(tester, screenOf(tester, c, w))`; `t.press(tester, k)` → `press(tester, k)`; `t.byKey(k)` → `byKey(k)` (`canvas_rig.dart`'s, the same finder); `h.c` → the controller; `c.activeTool.value == FloorPlanTool.wall` → `== ArchitectureTools.wall`, `.door` likewise; `c.activeDocument` → `c.document`.
     - keys (C7 class 1 and 3, rulings IT-R6, IT-R7): `wall-thickness` → `field('thickness')`; `wall-justification` (`SegmentedButton.onSelectionChanged`) → `menuOf(tester, 'justification').onChanged`; `opening-section` → `section(ArchitectureTypes.opening, ArchitectureTools.door)`; `opening-flip-hinge`, `opening-flip-swing` → `field('flip-hinge')`, `field('flip-swing')`; `opening-width` → `field('width')`; `opening-position` → `field('position')`; `room-name` → `field('name')`; `dimension-kind` → `menuOf(tester, 'kind').onChanged`; the tap on `dimension-vertical` → `choose(tester, 'kind', 'vertical')`; `wall-section` → `section(ArchitectureTypes.wall, ArchitectureTools.wall)`; `room-section`, `dimension-section` → `section-architecture.room`, `section-architecture.dimension`; `table-section` → `unit-section`; `table-number` → `unit-label`; `table-rotate-left|right` → `unit-rotate-left|right`; `symbol-*`, `layer-picker` unchanged.
     - T5-f's sofa (`:175-183`, ruling IT-R8): `await t.librarySettled(tester, c)` … `d.commands.execute(placeSymbol(...)); final placed = …` → 

```dart
      for (var i = 0;
          i < 400 && c.symbolsState.value != SymbolsState.ready;
          i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(c.armSymbol(c.symbols.firstWhere(
              (s) => s.component.key == 'architecture.sofa.two')),
          isTrue);
      await tester.pump();
      await click(tester, screenOf(tester, c, Vector2(24600, 13600)));
      await press(tester, LogicalKeyboardKey.escape);
      final placed = d.tree.nodes.whereType<InstanceNode>().last.handle;
```

       (`armSymbol` arms `plan.symbol`; the click places one instance; Escape returns to Select.)
     - V-5 (`:233-280`): ported whole, the table part included (IT-R2); the world points (25,500, 16,850), (22,857, 15,478), (26,300, 15,000), (25,875, 14,200) are the flat's, unchanged.
  5. `I/test/shortcuts/keyboard_focus_test.dart` from `host/keyboard_focus_test.dart`, the cases "a gesture's keys stay: the Wall tool chosen by the host" (`:436-465`), DS2 (`:566-613`), DS5 (`:659-681`) and R-3 RP5 (`:910-940`):
     - the host: copy `jet_cad_2d_plan/test/shortcuts/plan_shortcuts_test.dart:58-133` (`HostIntent`, `kIntentKeys`, `mountUnitKeys`) with `PlanController(kits: [fxKit()], json: unitEditorPlanJson())` → `PlanController(kits: editorKits(), json: editorPlanJson())` and `FakePagePrinter()` from `'../support/fake_page_printer.dart'`; `mountKeys(tester, json:, camera:, shortcuts:, caps:)` → `mountUnitKeys(tester, permissions: caps, intents: false, shortcuts: shortcuts)` (the editor fixture and camera are its own); `h.reached[k]` → the returned map; `h.shortcuts` → the returned notifier.
     - `entitiesByHandle` (`:176-187`, with `dart:convert`'s `jsonEncode`) copied unchanged, `c.activeDocument` → `c.document`; `encoded(c)` → `encodedPlan(c)`; `dataOf1(c)` → `c.unitDetails.where((d) => d.unit.label == '1').firstOrNull?.data`; `c.setTableData` → `c.setUnitData`; `c.selectedTables` → `c.selectedUnits`; `TableSurvey.of(d).withNumber('1')` → `unitsLabelled(c.document, '1')`; `liveObjectsOf<WallParams>(d).first` → `d.components.withComponent<WallParams>().first`; `FloorPlanTool.wall` → `ArchitectureTools.wall`, `.select` → `'plan.select'`; `t.click`, `t.screenOf`, `t.press` → the editor fixture's; `t.statusText(tester)` → `status(tester)`; `focusCanvas` → `canvas_rig.dart`'s; `Caps.full.copyWith(delete: false)` → `PlanPermissions.full.copyWith(delete: false)`.
  6. `I/test/layers/layer_picker_wall_test.dart` from `apps/floor_planner/test/layers/layer_picker_test.dart:352-401`:
     - the app's open flow (`rig.pumpApp`, `files.scriptOpen`, `host.openFlow`, `:356-363`) → `final p = pickerPlan(); final c = architectureController(json: p.json); addTearDown(c.dispose); await pumpPlanEditor(tester, c);` (today's open is the app's; the plan opened is the same).
     - `view.selection` → `c.activeSelection`; `p.wall`, `p.door`, `p.line` → the record's; `valueOf(tester)` copied from `jet_cad_2d_plan/test/panels/layer_picker_test.dart:179-181`; `wall-section` (for the selected wall) → `section-architecture.wall`; `tool-door` → `tool-architecture.door`; `opening-section` (the Door tool's settings) → `settings-architecture.door`; `tool-wall` → `tool-architecture.wall`; `wall-section` (the Wall tool's settings) → `settings-architecture.wall`.
  7. `I/test/layers/placer_layer_test.dart`: `layers/tools_layer_test.dart:230-256` ("the symbol placer puts the instance on the current layer …"), assertions unchanged:
     - the fixture: `onB()` → a `PlanController(kits: [architectureKit], json: planWith((doc) { l = layerFixture(doc); doc.commands.execute(SetCurrentLayerCommand(l.b)); }))` (today's `onB`, `tools_layer_test.dart:68-74`, inside the plan).
     - the placement (`placeSymbol(doc, entry, at:, quarterTurns: 1, mirrored: true)`): the plan's placer is not exported; the port arms the symbol and places it with the tool, as a host's user does: `entry` (`buildValidLibrary`'s `sofa.three`) → the furniture library's `architecture.sofa.three` (Task 23); the canvas pumped (`pumpPlanEditor`) and focused while Select is active (`focusCanvas`: a click with `plan.symbol` armed would place), then the controller armed with it (`c.armSymbol`), `R` pressed once and `M` once (`quarterTurns: 1`, `mirrored: true`; the armed tool takes R and M, `plan_symbol_tool.dart:383-410`, so M does not reach the Room tool's letter), and one `mouseClick` at `globalAt(tester, c, l.at(3000.5, 2000.25))` after `frameOn(tester, c, l.at(3000.5, 2000.25), scale: 0.25)`; the source's `entry.leaves.length` reads the armed symbol's `PlanSymbol.entry.leaves.length`.
     - the depth (`doc.commands.undoDepth`) is read before the click and `depth + 1` after; `doc` → `c.document`; the rest unchanged.
     - Ruling (IT-R10, the controller confirms): the placement goes through `plan.symbol` instead of the placer it calls (`plan_symbol_tool.dart` → `placeSymbol`); the case asserts the layers only, which the tool does not change.
     - Layer B is locked (`layer_fixture.dart:105`). If `plan.symbol` or the controller's `execute` refuses the placement on a locked current layer (the click commits nothing), that is a finding: stop and report it with the red line; do not change the assertion.
  8. `I/test/controller/delete_components_test.dart` from `delete_components_test.dart`, P-1, P-2, P-3:
     - `rig()` (`tables/table_data_test.dart:45-55`) → `final c = PlanController(kits: editorKits()); addTearDown(c.dispose); final doc = c.document;` (the plan's document carries both systems today's rig installed: the kits' types and the unit labels).
     - `placeTable(doc, at, quarterTurns:, mirrored:)` → `final t = placeAt(doc, tableSymbol(), at, quarterTurns: …, mirrored: …); final label = labelUnit(doc, t, '1');` (Step 3); `t.instance` → `t`; `deleteTable(t)` → `CompoundCommand([RemoveEntityCommand(label), RemoveNodeCommand(t)], label: 'Delete')` (`table_data_test.dart:68-70`); `FloorPlanTableData(hostData())` → a `UnitData` is the plan library's component (`lib/src/units/unit_components.dart:67`, not exported): `c.setUnitData('1', hostData())` sets it, one step (2b's API), and `dataOf(doc, t.instance)` → `c.unitDetails.singleWhere((x) => x.unit.label == '1').data` after the undo; `hostData()` copied (`table_data_test.dart:24-28`).
     - `addWallLocal`, `canon` from `'../support/plans.dart'`; `addOpening(doc, door, params)` (today's `opening_fixture.dart:addOpening(doc, h, o)` with a given handle) → `AddNodeCommand` + `SetComponentCommand<OpeningParams>` written in place, as `opening_fixture.dart:134-145` builds it; `deleteLikeSelectTool` (`opening_fixture.dart:147-154`) copied.
     - Ruling (IT-R11): P-1's "data and a newer release's payload" keeps both: `setUnitData` writes the data, `doc.components.attachUnknown(t, {...})` the payload, as today.
  9. `I/test/editor/architecture_palette_test.dart`: A12b's rows (ruling IT-R9). Copy `jet_cad_2d_plan/test/editor/palette_draw_test.dart:234-276` (A12b) with: the `drawing` map gains, after `'tool-plan.text': true`, the eight rows `'tool-architecture.box': true`, `'tool-architecture.wall': true`, `'tool-architecture.door': true`, `'tool-architecture.window': true`, `'tool-architecture.gap': true`, `'tool-architecture.room': true`, `'tool-architecture.separator': true`, `'tool-architecture.dimension': true` (today's flags, `planner_draw_test.dart:337-353`); its comment's last sentence ("The planner's box … leave with them.") → `// The planner's box, wall, door, window, gap, room, separator and dimension rows are the architecture kit's (3a Task 26, Appendix A D-26).`; `drawController()` and `pumpDesign(tester, c)` → `final c = architectureController(json: drawPlanJson()); addTearDown(c.dispose); await pumpPlanEditor(tester, c);` with `drawPlanJson()` written in the test from `canvas_fixture.dart:383-409`'s document (a 1:20 page at (7000, 3000), grid snap off, one line), saved with `ensureManifest(DraftDocumentCodec.encodeToString(doc))`; the second `pumpDesign` → `await tester.pump()` after the permissions change. The test's name gains nothing: it is today's A12b with its rows back.

  10. `I/test/dimension/dimension_paint_test.dart` from `dimension_paint_test.dart`, RR1, RR2, RR3, assertions unchanged (Task 21's carried port):
      - imports: drop `planner_shell.dart`, `parametric/catalog.dart`, `parametric/dimension.dart`, `planner_view.dart`, `startup_plan.dart`, `support/dimension_fixture.dart`; add the kit barrel (`DimensionParams`), the plan barrel, the integration library, `'../support/plans.dart'` (show `pageOf`, `driftOf`, `kids`, `kindOf`, `dimTextHandle`, `dimText`, `dimLines`).
      - `samplePlan({scale, background})` (`:45-60`) → `PlanController sampleFlat({double scale = 50, int? background})`: `final c = sampleFlatController(); addTearDown(c.dispose);` then, when `scale != 50 || background != null`, the same `SetComponentCommand<PageComponent>` on `c.document` and `c.document.commands.clearHistory()` (the controller's system regenerates: no `installParametric`, no `system.dispose`); `expect(driftOf(c.document), isEmpty)`; callers read `c.document` where they read `doc`.
      - `Rig.of(tester, doc)` (`:85-94`) → `Rig.of(tester, PlanController c)`: `RepaintBoundary(key: capture, child: planEditorApp(c))`; the field `view` → `controller`; `view.camera.value` → `controller.camera.value`.
      - `find.byType(InteractionLayer)` stays; every other line unchanged.
  11. `I/test/dimension/dimension_shell_test.dart` from `dimension_shell_test.dart`, SL1, SL2, TL9, assertions unchanged but IT-R13's lines (Task 22's carried port, ruling IT-R12):
      - imports: drop the six `jet_cad_floor_plan` imports and `support/dimension_fixture.dart`; add the kit barrel, the plan barrel, the integration library, `'../support/plans.dart'` (show `pageOf`, `driftOf`, `kids`, `kindOf`, `dimTextHandle`, `dimText`, `dimLines`), `'../support/canvas_rig.dart'` (show `activeTool`, `gripsOf`).
      - `samplePlan({gridSnap})` (`:48-60`) → `PlanController samplePlan({bool gridSnap = true})`: `sampleFlatController()` (disposed at tear-down); for `gridSnap: false`, the page command on `c.document` and `c.document.commands.clearHistory()`; `expect(driftOf(c.document), isEmpty)` and `expect(c.document.commands.undoDepth, 0)` kept.
      - `pumpShell(tester, doc, key)` (`:82-93`) → `pumpShell(tester, c, key)`: `MaterialApp(home: Scaffold(body: PlanEditor(key: ValueKey(key), controller: c)))` at 1440 x 900 (the plan's own first fit, as today's shell's); helpers (`pinCamera`, `globalOf`, `worldAt`, `pickRadius`, `tapWorld`, `dragGlobal`, `pressKey`, `undoKey`, `objectSnapOff`, `pickAt`, `worldBoundsOf`, `inside`, `:95-202`) and `wallsOf`, `dimsOf`, `sampleValues`, `childrenOf` (`:62-80`) copied with `PlannerView view` → `PlanController c`, `view.camera` → `c.camera`, `view.selection` → `c.activeSelection`, `view.document` → `c.document`, `view.index` → an `index` parameter (`SpatialIndex(c.document)`, made and disposed by each case).
      - `oracleEnd`: copy `dimension_fixture.dart:445-449`'s fixed branch only; its attached branch `throw UnsupportedError('kit internal (ruling IT-R13)')`. The lines of IT-R13 are left out with a comment `// Not ported (ruling IT-R13): <the line>`.
      - SL1's `view.grips!` (`:369-371`) → `gripsOf(tester)`; TL9's `view.tools.active` (`:561`) → `activeTool(tester)`.
  12. `I/test/room/room_paint_test.dart` from `room_paint_test.dart`, all six cases, assertions unchanged (Task 18's carried port, rulings IT-R14, R-P9):
      - first line: `// ignore_for_file: invalid_use_of_internal_member` (OL4 reads `PlanController.outlines`, R-P9).
      - imports: drop the eight `jet_cad_floor_plan` imports and `support/room_fixture.dart`; add the kit barrel (`RoomParams`, `SeparatorParams`), the plan barrel, the integration library, `'../support/plans.dart'` (show `pageOf`, `driftOf`, `kitCatalog`, `deleteObject`, `kids`, `kindOf`, `recordOf`, `labelStrings`, `labelsOf`, `anchorOf`, `enc`).
      - `sample({rooms, background, grid})` (`:58-79`) → `PlanController sample(...)`: `sampleFlatController()` (disposed at tear-down), the deletes and the page command on `c.document`, `expect(driftOf(c.document), isEmpty)`, `c.document.commands.clearHistory()`; no system made or disposed.
      - `Shot.of(tester, doc)` (`:118-150`) → `Shot.of(tester, PlanController c)`: `MaterialApp(home: Scaffold(body: PlanEditor(controller: c)))` in the capture boundary, 1800 x 1200; `view.camera` → `c.camera`; the field `view` → `controller`; `shot.view.document` → `shot.controller.document`; `view.selection` → `controller.activeSelection`; OL4's `view.outlines.debugWorldSegmentsOf` (`:557`) → `controller.outlines.debugWorldSegmentsOf` (R-P9).
      - SR3 (`:491-542`) per IT-R14: `enc(sample(grid: false))` → `sample(grid: false).save()` (the plan file, its manifest kept; the tables' `linetypes` edited as today); `DraftDocumentCodec.decodeString(...)` and `installParametric(doc)` → `final c = architectureController(json: jsonEncode(saved)); addTearDown(c.dispose); final doc = c.document;`; `system.drift()` → `driftOf(doc)`; `system.diagnostics()` → `ParametricSystem(doc, kitCatalog()).diagnostics()`; `system.dispose(); doc.commands.clearHistory();` dropped; `Shot.of(tester, doc)` → `Shot.of(tester, c)`.

- [ ] **Step 10: The new tests: the letters, the ids, the guard.** Add to `I/test/editor/architecture_palette_test.dart`:

```dart
/// The kit's tools, their letters and their English labels (D-26; the
/// letters are spec C2's; the labels today's strings).
const List<(String, LogicalKeyboardKey, String)> kArchitectureTools = [
  (ArchitectureTools.box, LogicalKeyboardKey.keyB, 'Box'),
  (ArchitectureTools.wall, LogicalKeyboardKey.keyW, 'Wall'),
  (ArchitectureTools.door, LogicalKeyboardKey.keyD, 'Door'),
  (ArchitectureTools.window, LogicalKeyboardKey.keyN, 'Window'),
  (ArchitectureTools.gap, LogicalKeyboardKey.keyG, 'Gap'),
  (ArchitectureTools.room, LogicalKeyboardKey.keyM, 'Room'),
  (ArchitectureTools.separator, LogicalKeyboardKey.keyS, 'Separator'),
  (ArchitectureTools.dimension, LogicalKeyboardKey.keyI, 'Dimension'),
];

  testWidgets(
      'IT-letters each architecture letter arms its tool, the status line '
      'reads its word, and an idle Escape returns to Select (D-26, D-48)',
      (tester) async {
    final c = architectureController(json: drawPlanJson());
    addTearDown(c.dispose);
    await pumpPlanEditor(tester, c);
    await focusCanvas(tester);
    for (final (id, key, word) in kArchitectureTools) {
      await pressKey(tester, key);
      expect(c.activeTool.value, id, reason: '$key');
      expect(status(tester), word, reason: id);
      await pressKey(tester, LogicalKeyboardKey.escape);
      expect(c.activeTool.value, 'plan.select', reason: '$id: Escape');
    }
  });

  testWidgets(
      'IT-ids every architecture tool id is armed by selectTool and its '
      'palette row (D-48: the closed tool enum is the kit\'s ids)',
      (tester) async {
    final c = architectureController(json: drawPlanJson());
    addTearDown(c.dispose);
    await pumpPlanEditor(tester, c);
    for (final (id, _, word) in kArchitectureTools) {
      expect(c.selectTool(id), isTrue, reason: id);
      await tester.pump();
      expect(status(tester), word, reason: id);
      expect(c.selectTool('plan.select'), isTrue);
      await tester.tap(byKey('tool-$id'));
      await tester.pump();
      expect(c.activeTool.value, id, reason: 'the row of $id');
      expect(c.selectTool('plan.select'), isTrue);
      await tester.pump();
    }
  });

  testWidgets(
      'IT-guard a panel field keeps the architecture letters: typed into the '
      'room\'s name, W D N G M S I B arm nothing; on the canvas W arms the '
      'Wall tool (D-48: the guard is built from the kit\'s letters)',
      (tester) async {
    final c = sampleFlatController();
    addTearDown(c.dispose);
    await pumpPlanEditor(tester, c);
    final hall = c.document.components.withComponent<RoomParams>().first;
    expect(c.document.components.get<RoomParams>(hall)!.name, 'Hall',
        reason: 'premise: the sample\'s first room');
    c.activeSelection.replace([SelectionKey.root(hall)]);
    await tester.pump();
    await tester.tap(field('name'));
    await tester.pump();
    final node = tester.widget<TextField>(field('name')).focusNode!;
    expect(node.hasFocus, isTrue, reason: 'premise: the field focused');
    for (final (id, key, _) in kArchitectureTools) {
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(c.activeTool.value, 'plan.select', reason: '$id typed');
      expect(node.hasFocus, isTrue, reason: '$id: the field keeps the focus');
    }
    // The control: the canvas focused, W is the Wall tool's.
    await focusCanvas(tester);
    await pressKey(tester, LogicalKeyboardKey.keyW);
    expect(c.activeTool.value, ArchitectureTools.wall);
  });
```

  The file's imports: `package:flutter/material.dart`, `package:flutter/services.dart` show `LogicalKeyboardKey`, `package:flutter_test/flutter_test.dart`, `package:jet_cad_2d/jet_cad_2d.dart`, `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart` show `FlutterTextMeasurer`, `SelectionKey` (`drawPlanJson`'s document is measured as `canvas_fixture.dart:387` measures it), the kit barrel, the plan barrel, the integration library, `'../support/canvas_rig.dart'`.

- [ ] **Step 11: Run.** `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice test/canvas test/shell test/editor test/shortcuts test/layers test/controller test/dimension/dimension_paint_test.dart test/dimension/dimension_shell_test.dart test/room/room_paint_test.dart`. Expected: `All tests passed!`. A ported case that fails is a finding (the code under it is the earlier tasks'): stop and report the red line and the source line it ports; do not change an assertion. The three new tests pass because the kit's letters and the guard exist since Tasks 9-22; Step 15 shows each red under its mutation.

- [ ] **Step 12: D-48, the closed lists, each proven through the kit's hooks.** Write this table into the task report (and Task 29 copies it into the results note); every test named must exist in the tree (`grep -rn "<name>" packages/jet_cad_2d_integration/test packages/jet_cad_2d_kit_architecture/test`):

| Today's closed list (umbrella Facts, `kit-architecture-design.md:89-100`) | The kit's hook | Test(s) that prove it |
|---|---|---|
| `isParametricObject` (`layers/layer_picker.dart:23-29`) | `PlanType` registered, `typeIdOf` (E1) | `layer_picker_wall_test` (the wall's picker, below its section); T5-f (the picker for a wall, a door, a room, a dimension) |
| `ObjectGrips._of` (`object_grips.dart:80-86`) | `PlanType.grips` | Task 28's O13a (a dimension's end grip) and O13b (a window's slide grip) through `plan.select`; Task 12's WG-refuse-short |
| `FloorPlanTool` enum (`editor_capabilities.dart:13-30`) | `PlanTool.id` | IT-ids |
| palette `_entries` and letters (`planner_shell.dart:517-623`) | `PlanTool.letter`, `icon`, `needs` | A12b's restored rows; IT-letters |
| `kShellLetterKeys` (`shortcut_guard.dart:8-25`) | the letters in use (`planLetterKeys`) | IT-guard |
| per-tool strings (`l10n/strings.dart:61-110`) | `tool:` words | IT-letters (English), Task 27's PW1 (`Duvar`) and Q0-E3b (`Bemaßung`) |
| the Selection panel's per-type sections (`selection_panel.dart:149-158, :1251-1430`) | `PlanType.properties`, `title`, `section` | T5-f; Task 27's WS1, IP-title |
| `pickedColors` (`colors/color_picker.dart:17-35`) | `PlanType.colour` | Task 27's CP1, CP2 |
| `exportOmitOwners` (`export/export_bytes.dart:28-29`) | `PlanType(exported: false)` | Task 17's D-30 test (the separator in neither PDF nor PNG) |
| the room inputs (`room_inputs.dart:96-148, :296-314`) | `RoomInputs` over `PlanServices.shared` and `liveTypeIdOf` | Task 16's RR-live; TD1 (the Room tool places one room in the sample's kitchen); room_paint's RR1-RR4; Task 19's RT-frozen-wall |

  (The umbrella says "nine further closed lists" and names ten: the table keeps all ten.)

- [ ] **Step 13: Format and the gates.**
  - `cd packages/jet_cad_2d_integration && dart format . && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_kit_architecture && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - From the root: `dart run tool/ci/check_kit_deps.dart` (the kit's new test files name neither the plan library nor another kit; the integration package is not bound). Expected: its one line, exit 0.
  - `grep -rn "package:jet_cad_2d_plan/src\|package:jet_cad_2d_kit_architecture/src" packages/jet_cad_2d_integration`: prints nothing (C6, R-P1). `grep -rln "invalid_use_of_internal_member" packages/jet_cad_2d_integration/test`: `room_paint_test.dart` only (R-P9).
  - `grep -rn "jet_cad_2d_plan" packages/jet_cad_2d_kit_architecture/test`: prints nothing.
  - Non-ASCII: `grep -n "—\|²\|°" packages/jet_cad_2d_integration/test/shell/planner_shell_test.dart packages/jet_cad_2d_integration/test/editor/editor_panels_test.dart` and compare each hit with its source line.
  - `flutter analyze` fails on an `unnecessary_import` warning as on an `unused_import` error (`analysis_options.yaml`: `unused_import: error`): the support files re-export one another (`room_plans.dart` re-exports the rig's and the wall fixture's names, the kit's `dimension_fixture.dart` re-exports `room_fixture.dart`, which re-exports `wall_fixture.dart`), so an import listed in this task whose names another import already provides (e.g. the kit `layer_fixture.dart`'s `'wall_fixture.dart' show testCatalog, installParametric` beside `'dimension_fixture.dart'`) is dropped; the names stay reachable.
  - `git status --short`: this task's files only (no `analysis_options.yaml`).

- [ ] **Step 14: Commit.**

```bash
git add packages/jet_cad_2d_integration/test/support/plans.dart packages/jet_cad_2d_integration/test/support/units.dart packages/jet_cad_2d_integration/test/support/editor_fixture.dart packages/jet_cad_2d_integration/test/support/canvas_rig.dart packages/jet_cad_2d_integration/test/support/layer_plan.dart packages/jet_cad_2d_integration/test/support/fake_page_printer.dart packages/jet_cad_2d_integration/test/canvas/touch_tools_test.dart packages/jet_cad_2d_integration/test/shell/planner_shell_test.dart packages/jet_cad_2d_integration/test/canvas/planner_grips_test.dart packages/jet_cad_2d_integration/test/editor/architecture_palette_test.dart packages/jet_cad_2d_integration/test/editor/editor_panels_test.dart packages/jet_cad_2d_integration/test/shortcuts/keyboard_focus_test.dart packages/jet_cad_2d_integration/test/layers/layer_picker_wall_test.dart packages/jet_cad_2d_integration/test/layers/placer_layer_test.dart packages/jet_cad_2d_integration/test/controller/delete_components_test.dart packages/jet_cad_2d_integration/test/dimension/dimension_paint_test.dart packages/jet_cad_2d_integration/test/dimension/dimension_shell_test.dart packages/jet_cad_2d_integration/test/room/room_paint_test.dart packages/jet_cad_2d_kit_architecture/test/room/room_cost_test.dart packages/jet_cad_2d_kit_architecture/test/support/layer_fixture.dart packages/jet_cad_2d_kit_architecture/test/layers/tools_layer_test.dart packages/jet_cad_2d_kit_architecture/test/layers/opening_host_layer_test.dart packages/jet_cad_2d_kit_architecture/test/layers/attach_layer_test.dart packages/jet_cad_2d_kit_architecture/test/intersection_snap_test.dart
git commit -m "$(cat <<'EOF'
test(integration): the canvas, tools, layers and shell rows (3a Task 26)

The architecture kit inside the plan library's widgets: the Room tool
under a pinch, the sample flat's wall click and its delete undone by
cmd+Z and ctrl+Z, the grips through the editor, the palette's eight
rows and letters, the panels' architecture cases, the wall cases of the
keyboard tests, the layer picker for a wall, the placer's layer and a
wall's components on delete. The layer rules for live objects and the
phantom intersection snap run in the kit, over FakePlanServices. The
sample flat's dimension and room paint cases, the dimension shell cases
and the room rebuild bound (LZ3) close their files.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

  (If Step 1 changed `packages/jet_cad_2d_integration/pubspec.yaml`, add it to the `git add` line, and only it.)

- [ ] **Step 15: Mutation check** (committed files only; after each: run the named test, see it red, quote the red line, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0). Integration tests run from `packages/jet_cad_2d_integration` with `flutter test --enable-vmservice <file>`; kit tests from `packages/jet_cad_2d_kit_architecture` with `flutter test <file>`.
  - M-IT-1 `packages/jet_cad_2d_kit_architecture/lib/src/wall/wall_plan.dart`: the wall tool's `letter: 'W'` → `letter: 'Q'` → IT-letters red (`W` arms nothing) and IT-guard red (its control).
  - M-IT-2 `packages/jet_cad_2d_kit_architecture/lib/src/kit.dart`: `doorPlanTool,` deleted from `tools:` → A12b red (`tool-architecture.door` missing from the palette), IT-ids red.
  - M-IT-3 `packages/jet_cad_2d_plan/lib/src/shortcuts/plan_shortcut_guard.dart`: in `planLetterKeys`, `if (e.key case final key?) key,` → `if (e.kitId == kPlanKitId) if (e.key case final key?) key,` (the guard keeps the generic letters only) → IT-guard red (a typed letter arms its tool).
  - M-IT-4 `packages/jet_cad_2d_kit_architecture/lib/src/room/room_tool.dart`: the `SetComponentCommand<ObjectLayer>` of the room's creation compound deleted → `tools_layer_test` "the Room tool creates its room … on the current layer" red.
  - M-IT-5 `packages/jet_cad_2d_kit_architecture/lib/src/opening/opening_tool.dart`: `isUsableHost` answering `true` → `opening_host_layer_test` "a wall on the hidden C hosts nothing" red.
  - M-IT-6 `packages/jet_cad_2d_kit_architecture/lib/src/wall/wall_plan.dart`: the thickness spec's `gate: PlanGate.reshape` deleted → T5-f red (the thickness field editable under `reshape: false`).
  - M-IT-7 `packages/jet_cad_2d_kit_architecture/lib/src/opening/opening_plan.dart`: delete `gate: PlanGate.reshape` from the `flip-hinge` `ActionProperty` (C1.7 then no longer hides it under `reshape: false`) → T5-f red (`field('flip-hinge')` found under `reshape: false`). (Deleting its `visible:` would not do: the gate alone still hides it for a door under `reshape: false`.)
  - M-IT-8 `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart`: in the private constructor, Task 5's `if (made) _prepare(document);` → `_prepare(document);` (the kits' `prepare` also run on a decoded `json`) → `room_paint_test` SR3 red (the loaded separator draws dashed; Review Focus 1).
  - M-IT-9 `packages/jet_cad_2d_kit_architecture/lib/src/room/room_tool.dart`: the room tool's commit seeded at the snapped point with `+ Vector2(1e6, 0)` (outside every wall) → TD1 red (`hasLength(1)`: the room dissolves). If it stays green, report it (do not change TD1).
  Quote each red line.

#### Interface problem

1. **Settled by rulings R-P1 and R-P9.** This task reads no kit internal from the integration package: the active tool is `InteractionLayer.tools.active`, the grips `InteractionLayer.tools.context.grips`, units are placed by hand; cases needing kit internals run in the kit (the layer tests, LZ3). Only `room_paint_test`'s OL4 reads an `@internal` member (`outlines`), under R-P9's ignore. Two lines families cannot be reached publicly and are ruled out (IT-R13: the dimension oracle's attached branch and `oracleFailures`), with the controller's confirmation.
2. **The kit's tool letters and property ids are other tasks' choices.** This task's keys (`property-thickness`, `setting-width`, ...) and IT-letters' table assume the ids and letters the scopes give (Step 1 prints them). A different id changes a finder, never an assertion.

#### New shared name

Test support in `packages/jet_cad_2d_integration/test/support/`, created here, imported by Tasks 27 and 28 (an earlier task that already made an integration support file of the same purpose — a wall fixture for Task 12's `WG-refuse-short`, Task 21's `test/dimension/dimension_plans.dart` — keeps its own; the reconcile pass merges duplicates):
- `plans.dart`: `String planWith(void Function(DraftDocument d) build, {List<PlanKit>? kits, PlanBuild? first})`, `KitWords englishWords`, Task 9's `kitCatalog()` re-exported, `List<Handle> driftOf(DraftDocument)`, `kPlanOriginX`, `kPlanOriginY`, `kPlanWidth`, `kPlanHeight`, `({Vector2 s, Vector2 e}) worldEndsOf(DraftDocument, Handle)`, `(Vector2, Vector2) faceOf(Vector2 s, Vector2 e, double offset)`, `final class Plan { Placement place; List<Handle> walls, seps, openings; Vector2 at(double, double); }`, `Plan buildPlan(DraftDocument doc, List<W> walls, {List<S> seps, List<W> wallsAfter, List<O> openings, Placement place})`, `String d23PlanJson()`, and today's names, re-exported from Task 12's `wall_fixture.dart` and Task 18's `room_plans.dart` or copied unchanged (`ox`, `oy`, `far`, `plan`, `nextUp`, `polar`, `groupAt`, `oracleMeet`, `nearestIn`, `addWallLocal`, `addWall`, `kids`, `kindOf`, `payloadOf`, `pointsOf`, `worldOutline`, `sharedNear`, `isRectNear`, `enc`, `canon`, `walls`, `xy`, `facesOf`, `expectMitre`, `expectSquare`, `W`, `S`, `O`, `Placement`, `origin`, `corpus`, `corpusGroups`, `km1000`, `km1000Axis`, `km1000Groups`, `placements`, `addSeparator`, `addOpening`, `recordOf`, `worldPoints`, `sampleWalls`, `sampleOpenings`, `sampleSeparator`, `sampleColumn`, `sampleSeeds`, `twoRoomWalls`, `boxWalls`, `attachPage`, `addRoom`, `labelsOf`, `textOf`, `pageOf`, `anchorOf`, `deleteObject`, `renameRoom`, `labelStrings`, `kindsOf`, `groupFor`, `c5Walls`, `addDimension`, `fixedAt`, `dimTextHandle`, `dimText`, `dimLines`).
- `units.dart`: `fxKitId`, `PlanKit fxKit({List<CatalogSymbol> library})`, `leafRecord`, `tableUnit`, `tableSymbol`, `entryOf`, `kDeg37`, `placementAt`, `addLayer`, `embeddingTable`, `embeddingBox`, `editorChair`, `embeddingPlacement`, `Handle placeUnit(DraftDocument, CatalogSymbol, {required Transform2 transform, Handle? layer})`, `Handle placeAt(DraftDocument, CatalogSymbol, Vector2, {int quarterTurns, bool mirrored})`, `Aabb2 labelTopOf(DraftDocument, Handle definition)`, `Handle labelUnit(DraftDocument, Handle instance, String text)`, `List<Handle> unitsLabelled(DraftDocument, String label)`, `Handle tableOf(PlanController c, String? n)`.
- `editor_fixture.dart`: `kEditorSurface`, `kEmbeddingHidden`, `kEmbeddingLocked`, `EditorTable`, `editorTables`, `editorChairPlacement`, `editorGroupPlacement`, `editorFreeLine`, `editorTextAt`, `editorTextHeight`, `editorTextWords`, `editorColumnCorner`, `String editorPlanJson()`, `editorCamera()`, `Future<PlanController> mountEditor(WidgetTester, {PlanPermissions permissions, String? json})`, `setPermissions`, `canvasOrigin`, `screenOf`, `centreOf`, `click`, `List<PlanKit> editorKits()`, `encoded`, `encodedPlan`, `keyOf`, `transformOf`, `onTable`, `topOf`, `boxOf`, `edgeOf`, `startOf`, `isLine`, `selected`, `drag`, `fingerTap`, `rotationGripOf`, `degreesOf`, `canvasRect`.
- `canvas_rig.dart`: `byKey`, `field`, `section`, `pumpPlanEditor`, `frameOn`, `gripsOf`, `pressKey` (the rig's `press`), and Task 9's `activeTool`, `globalAt` (a `Vector2`), `globalOf`, `kitCatalog`, `press`, `status` re-exported, `mouseClick`, `canvasFocus`, `focusCanvas`, `canvasFocused`, `choose`, `menuOf`.
- `layer_plan.dart`: `LayerPlan`, `layersOn`, `onLayer`, `addObjectOn`, `addWallsOn`, `layerFixture`, `addLineOn`, `addRegionOn`, `addSymbolOn`, `layerOf`, `objectLayerOf`, `moveObject`, `pickerPlan`.
- `fake_page_printer.dart`: `PrintCall`, `FakePagePrinter`.

Kit test support, created here: `packages/jet_cad_2d_kit_architecture/test/support/layer_fixture.dart` with today's names and `Tool toolOf(LayerDoc l, String toolId)`.

---

