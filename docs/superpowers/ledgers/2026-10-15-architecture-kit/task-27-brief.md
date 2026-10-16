### Task 27: Integration: the panels and the words (spec C6, C7, C1.1, C1.2, C1.6; Appendix A D-20, D-21, D-24, D-32, D-39, D-46; rulings R-P1, R-P9)

**Files** (`I = packages/jet_cad_2d_integration`, `K = packages/jet_cad_2d_kit_architecture`):
- Create (integration test support): `I/test/support/q0_plan.dart` (the decimal-separator fixture as a plan file), `I/test/support/recording_plan_strings.dart` (copy of `jet_cad_2d_plan/test/support/recording_plan_strings.dart`, imports through the plan's barrel), `I/test/support/rooms_plan.dart` (the colour picker's two-room plan as a plan file).
- Modify (integration test support): `I/test/support/units.dart` (Task 26) gains `diningTableTwo`, the library table of DT1, LK2 and OV-H.
- Create (integration tests):
  - `I/test/panels/wall_section_test.dart` (WS1-WS6, WS7 (Wall), WS8, WS9, WS10 ×2, WS11)
  - `I/test/panels/selection_page_test.dart` (SE11, SE12, SE13, SE15, SE16 with their Wall lines)
  - `I/test/panels/colour_row_test.dart` (the fixture case, CP1, CP2, CP3, CP4, CP5, CP6b over rooms)
  - `I/test/panels/decimal_separator_test.dart` (Q0-E1, Q0-E2, Q0-E3, Q0-E3b)
  - `I/test/panels/titles_test.dart` (IP-title, IP-door-actions: new)
  - `I/test/l10n/determinism_test.dart` (DT1), `I/test/l10n/leak_test.dart` (LK2), `I/test/l10n/overflow_test.dart` (OV-H, each language), `I/test/l10n/panel_words_test.dart` (PW1, PW2), `I/test/l10n/numbered_names_test.dart` (NN3), `I/test/l10n/locale_separator_test.dart` (NS3)
- Create (kit tests, C7 and R-P1): `K/test/room/decimal_separator_test.dart` (Q0-S1, Q0-S2), `K/test/words/value_words_test.dart` (VW3's Room notice)

**Interfaces:**
- Consumes:
  - Task 26's integration support (its "New shared name"): `plans.dart` (`planWith`, `englishWords`, `kitCatalog`, `driftOf`, `ox`, `oy`, `plan`, `polar`, `groupAt`, `nextUp`, `addWall`, `kids`, `kindOf`, `payloadOf`, `enc`, `canon`, `worldOutline`, `sharedNear`, `nearestIn`, `walls`, `expectMitre`, `buildPlan`, `Placement`, `corpus`, `corpusGroups`, `W`, `twoRoomWalls`, `addSeparator`, `attachPage`, `addRoom`, `labelsOf`, `textOf`, `recordOf`, `pageOf`, `labelStrings`, `addDimension`, `FixedEnd`-built ends, `dimText`), `units.dart` (`fxKit`, `placeAt`, `labelUnit`, `tableSymbol`, `unitsLabelled`), `canvas_rig.dart` (`byKey`, `field`, `section`, `pumpPlanEditor`, `globalAt`, `pressKey`, `canvasFocus`, `choose`, `menuOf`, and Task 9's `globalOf`, `activeTool`, `status`, `press`, `kitCatalog` it re-exports), `editor_fixture.dart` (`kEditorSurface`).
  - Shared interfaces: `architectureKit`, `ArchitectureTypes`, `ArchitectureTools`, `buildSampleFlat`, `WallParams`, `Justification`, `BoxParams`, `RoomParams`, `OpeningParams`, `OpeningKind`, `HingeEnd`, `SwingSide`, `DimensionParams`, `SeparatorParams`; `architectureController`, `sampleFlatController`, `planEditorApp`; `PlanController.toolNotice`, `textOf` (Task 4), `newPlan(build:)` (Task 5), `KitNamesWords`, `KitWords.text` (Task 3).
  - Plan library, public: `PlanEditor`, `PlanPropertyPanel`, `PlanPagePanel`, `PlanStrings`, `PlanStringsEn`, `PlanStringsTr`, `PlanStringsDe`, `PlanLocalizations`, `planLocalizationsDelegates`, `planSupportedLocales`, `PlanPermissions`, `UnitLabelProblem`, `UnitLabelWarning`, `SymbolsState`; keys `section-<type>`, `settings-<tool>`, `property-<id>`, `setting-<id>`, `color-picker`, `color-swatch-<name>`, `layer-picker`, `page-scale`, `layer-name-<hex>`, `layer-name-field-<hex>`, `symbol-rotation`, `unit-label`, `symbol-size-menu`, `symbol-section`, `unit-section`, `tab-symbols`, `symbol-cell-<id>`, `status-text`.
  - Kit test support: Task 16's `room_fixture.dart`, Task 20's `dimension_fixture.dart` (today's names: `buildPlan`, `attachPage`, `addRoom`, `addDimension`, `labelStrings`, `dimText`, `pageOf`, `kids`, `enc`, `driftOf`, `corpus`, `W`).
- Produces: test support only; `diningTableTwo` (in `units.dart`) and `q0PlanJson`, `roomsPlanJson` (below, "New shared name").

**Appendix A rows closed:**
- D-20: `selection_panel_test` WS1, WS2, WS3, WS4, WS5, WS6, WS7 (Wall), WS8, WS9, WS10 (its loop's two), WS11 (WS7 (Box) is 2a's); `selection_page_test` SE13, SE15, SE16's Wall lines restored (`selection_panel_test.dart:960-961, :1005-1006, :1032-1033`); SE11's and SE12's Wall lines (`:923-924`, `:938-939`), which 2a's `jet_cad_2d_plan/test/panels/selection_panel_test.dart:396-397, :411-412` replaced by its B stand-in, restored the same way (the coordinator's decision, D-20 completed).
- D-21: `color_picker_test` CP2 (tint pixels over two rooms, a wall, a separator); CP1's separator line and its Wall-tool lines (restored by porting CP1 whole over rooms).
- D-24: `l10n/determinism_test` DT1, `leak_test` LK2, `overflow_test` OV-H (each root object of the sample plan, three languages), `panel_words_test` PW1 and PW2's Wall section words and edits, `numbered_names_test` NN3, `value_words_test` VW3's Room-notice line (kit), `host/new_plan_separator_test` NS3's room-label line.
- D-32: `decimal_separator_test` (6): Q0-S1, Q0-S2 kit; Q0-E1, Q0-E2, Q0-E3, Q0-E3b integration.
- D-39: 2a's room cases of `color_picker_test`, which 2a ported over the box kit's colour target (`jet_cad_2d_plan/test/panels/colour_row_test.dart:10-16`), run again over real rooms: the fixture case, CP1, CP3, CP4, CP5, CP6b (CP2 is D-21's; CP6 is a pure function 2a ported, no room in it).
- D-46: titles by `title` (IP-title: a door's section says Door, a window's Window), `TextDisplay` through the real kit (Q0-E1's area and value rows; Task 21's PN cases), `ActionProperty` and `visible` through the real kit (IP-door-actions; Task 26's T5-f). `ValueDisplay`'s units: the architecture kit uses none (spec C1.1 chose `TextDisplay` for the area and the value, as drawn); the row closes by that ruling, the panel's `ValueDisplay` remaining 2a's (its tests over the test kits).

**C7 placement and rulings:**

| Source (`jet_cad_floor_plan/test/`) | Cases | Destination | Why |
|---|---|---|---|
| `selection_panel_test.dart` | WS1-WS11 | integration | the shell's Selection panel → `PlanEditor`'s property panel |
| `jet_cad_2d_plan/test/panels/selection_page_test.dart` (2a's port) | SE13, SE15, SE16 | integration | the Wall lines need the kit inside `PlanEditor` |
| `jet_cad_2d_plan/test/panels/selection_panel_test.dart` (2a's port) | SE11, SE12 | integration | likewise (their Wall lines; the rest of 2a's file stays 2a's) |
| `colors/color_picker_test.dart` | fixture, CP1-CP5, CP6b | integration | the shell's colour row |
| `decimal_separator_test.dart` | Q0-S1, Q0-S2 | kit | the kit's room and dimension, the engine; no plan name |
| `decimal_separator_test.dart` | Q0-E1, E2, E3, E3b | integration | the panel's rows and the status line |
| `l10n/determinism_test.dart` | DT1 | integration | the view's UI edits |
| `l10n/leak_test.dart` | LK2 | integration | the view in Turkish |
| `l10n/overflow_test.dart` | OV-H | integration | the view at 656 x 700 |
| `l10n/panel_words_test.dart` | PW1, PW2 | integration | the view's panels |
| `l10n/numbered_names_test.dart` | NN3 | integration | the plan builds the sample in its language (`newPlan(build:)`, C1.9) |
| `l10n/value_words_test.dart` | VW3's Room line | kit | the kit's words over `KitNamesWords`; no plan name |
| `host/new_plan_separator_test.dart` | NS3 | integration | the controller's load path |

Plan rulings (the controller confirms; each becomes a ledger `Ruling:` line):
- **IP-R1 (C7 classes 1 and 3; Task 26's IT-R6, IT-R7).** Keys: `wall-thickness` → `field('thickness')` (either scope); `wall-justification` → the choice `justification` (`menuOf(...).value` for `SegmentedButton.selected`, wrapped in a one-element set where today compared a set; `onChanged` for `onSelectionChanged`); a tap on `wall-left|centre|right` → `choose(tester, 'justification', 'left|centre|right')`; `wall-section` → `section(ArchitectureTypes.wall, ArchitectureTools.wall)`; `box-width`, `box-height` → `field('width')`, `field('height')`; `room-area` → `property-area`, `dimension-value` → `property-value` (`TextDisplay` rows, a `Text` keyed `property-<id>` as `ValueDisplay`'s are, `plan_property_panel.dart:745-750`); `room-name` → `field('name')`; `opening-section` → `section-architecture.opening`. The asserted values do not change.
- **IP-R2 (a kit tool's private state; R-P1).** Lines that read the Wall tool's settings object (`(view.tools.active as WallTool).settings.value.thickness`, `selection_panel_test.dart:396-397` in WS3 and `:754`, `:776` in WS10) cannot be written in the integration package (the kit's `WallTool` and `WallSettings` are internal) nor in the kit (the case drives the plan's panel). Not ported; each is covered in the same case by an observable equal to it: the field shows the kept value (`:395`, `:777`) and the next wall the tool draws has it (`:399-403`, `:771-772`). WS6's `view.tools.active as PlacementTool` + `.isPending` (`:499-523`) → `activeTool(tester).isMidShape`: `PlacementTool.isMidShape` is `isPending` (`jet_cad_2d_flutter/lib/src/draw/placement_tool.dart:70-76`) and the guard forwards it (`jet_cad_2d_plan/lib/src/kits/guard.dart:363-370`); the asserted values are unchanged.
- **IP-R3 (the Dimension tool's notice; spec C1.2).** `noticeCases`' `tool.notice.value` (`decimal_separator_test.dart:187`), a `String` today, is a `KitText` now, put into words when read: `c.textOf(c.toolNotice.value!)` (the controller's public notice, Task 4) equals the same `want`. Its two premises over the tool's private state, `tool.points` hasLength 2 (`:184`) and `tool.hoverKind` isNull (`:186`), are not ported: the status line `'$label — $want'` asserted next (`:188`) holds only with two points placed and a free hover (an attached end gives another length than 345.7).
- **IP-R4 (DT1 and LK2's library table).** Today's furniture library carried a servable dining table (`dining.table.square.two@2`); the architecture kit's are plain symbols (decision 3), so the table these cases place is the fixture kit's: `fx.dining.table.two`, named `Square dining table, 2 seats`, a unit of kind `table` seating 2, offered by `fxKit(library: [diningTableTwo])` beside the architecture kit. Its cell key is `symbol-cell-fx.dining.table.two@1`; `table-number` is `unit-label`; `table-section` is `unit-section`. Every assertion keeps its value (DT1's `"7"` and the English name; LK2's six kinds).
- **IP-R5 (LK2's allowlist).** Today's recording language recorded every architecture word because the planner asked its strings for them. The kit's words come from `KitNames`: the leak check also allows a text that is one of the kit's Turkish words or one of its `text:` templates filled (each `{name}` matching any non-empty run). The check, `expect(leaks, isEmpty)`, is unchanged.
- **IP-R6 (PW1's justification words).** `Sol`, `Orta`, `Sağ` are the choice's three words; a dropdown shows the chosen one only, so PW1 opens the menu to find the other two and closes it by choosing `Orta` again (no step: the same value, WS4's rule). C7 class 3.
- **IP-R7 (CP3's two command lines; R-P1).** CP3's direct calls of today's `recolorCommand` (`color_picker_test.dart:497-507`: the command for the selection, and `null` for a colour a room already has) call the plan's internal `recolour` (`jet_cad_2d_plan/lib/src/panels/colour_row.dart`). Not ported; CP3's swatch taps, which make the same two claims through the panel (a tap on the colour a room has adds no step; a tap on teal with A teal and B purple changes B only), are.
- **IP-R8 (WS9's malformed file).** Today's WS9 decodes a document whose wall A's fill names B's outline and hands it to the shell. The port loads the same JSON as a plan file (`architectureController(json:)`). If the plan's load locks A as broken (2a's `lockBroken`, `plan_controller.dart:749`) instead of refusing the edit at its commit, the field is read-only and the case's premise differs: that is a finding for the controller, not an assertion to change.

#### Assumed from earlier tasks

Each name is used as written; a different one is used as the earlier task made it, the difference reported.
- Task 26's integration support, as its "New shared name" lists.
- Task 9's words (English, German, Turkish, from `jet_cad_floor_plan/lib/src/l10n/strings_{en,de,tr}.dart`): `type:architecture.wall` = Wall / Wand / Duvar; `property:architecture.wall.thickness` = Thickness / Dicke / Kalınlık; `...justification.left|centre|right` (Turkish Sol, Orta, Sağ); `tool:architecture.dimension` = Dimension / Bemaßung; `text:architecture.room-occupied` = `Already a room: {name}` in English; the sample's room words (Turkish `Hol`, `Yatak odası {n}`, `Mutfak`, `Yemek odası`; German `Küche`; English `Bedroom {n}`); `tool:architecture.door` = Door, `tool:architecture.window` = Window (the opening's `title`, Task 14).
- Task 14: the opening's properties `width`, `position`, `flip-hinge`, `flip-swing`, the flips `visible` for doors only and gated by `reshape`; the title hook answers `tool:architecture.door|window|gap` by kind.
- Task 16, 20 (kit test support): `room_fixture.dart`, `dimension_fixture.dart` with today's names.
- Task 22: the Dimension tool implements `ToolNotice` with `text:architecture.dimension-value` (`{value}`), the page's separator.

- [ ] **Step 1: Precondition.** Task 26 is committed. `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice && flutter analyze`; `cd packages/jet_cad_2d_kit_architecture && flutter test && flutter analyze`: green. `grep -n "text:architecture.room-occupied\|text:architecture.dimension-value" packages/jet_cad_2d_kit_architecture/lib/src/words/*.dart` prints the English, German and Turkish templates; `grep -n "Duvar\|Kalınlık\|Bemaßung" packages/jet_cad_2d_kit_architecture/lib/src/words/*.dart` prints the words above. A word that differs is a finding for Task 9 (today's strings are the oracle).

- [ ] **Step 2: The support.**
  1. `I/test/support/recording_plan_strings.dart`: copy `packages/jet_cad_2d_plan/test/support/recording_plan_strings.dart` whole; its imports `package:jet_cad_2d_plan/src/l10n/strings.dart`, `src/units/unit_label.dart` (`UnitLabelProblem`) and `src/units/unit_problems.dart` (`UnitLabelWarning`) → `package:jet_cad_2d_plan/jet_cad_2d_plan.dart` show `PlanStrings, UnitLabelProblem, UnitLabelWarning` (each is exported by the barrel). Header gains `// Copied for jet_cad_2d_integration (3a Task 27); regenerate with the plan's copy.`
  2. `I/test/support/units.dart` (Task 26's) gains, after `tableSymbol`:

```dart
/// DT1's and LK2's library table (ruling IP-R4): today's
/// `dining.table.square.two`'s name, a served two-seat unit of the fixture
/// kit, its shapes the fixture table's.
final CatalogSymbol diningTableTwo = CatalogSymbol(
  key: 'fx.dining.table.two',
  name: 'Square dining table, 2 seats',
  category: 'Dining Room',
  tags: const ['table', 'dining'],
  unit: tableUnit(2),
  base: tableSymbol().base,
  shapes: tableSymbol().shapes,
);
```

  3. `I/test/support/q0_plan.dart`, the decimal-separator fixture (`decimal_separator_test.dart:37-80`) as a plan file:

```dart
// The decimal separator's fixture (jet_cad_floor_plan/test/
// decimal_separator_test.dart:37-80) as a plan file (3a Task 27): a box of
// four 200 mm walls at the corpus far origin turned 23 degrees, a cm page at
// 1:20, its origin off zero, grid snap off, the separator point; a room
// `Kitchen` (12.37 m²) and an aligned dimension in a turned group (345.7).
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';

import 'plans.dart';
```

     then copy `:37-54` (`q0Walls`, `q0Page`) unchanged, and write:

```dart
/// The fixture's plan file, its room and its dimension.
({String json, Handle room, Handle dim}) q0PlanJson() {
  late Handle room, dim;
  final json = planWith((d) {
    final plan = buildPlan(d, q0Walls, place: corpus);
    attachPage(d, q0Page);
    room = addRoom(d, plan.at(1500.25, 1700.75), 'Kitchen');
    dim = addDimension(
        d, const FixedEnd(-120.5, 40.25), const FixedEnd(3336.8, 40.25),
        offset: 300.25,
        at: corpus.m
            .multiply(Transform2.translation(600.5, 4400.25))
            .multiply(Transform2.rotation(0.4)));
  });
  return (json: json, room: room, dim: dim);
}

/// [doc]'s page with separator [s], one command (today's `separatorTo`).
DraftCommand separatorTo(DraftDocument doc, DecimalSeparator s) =>
    SetComponentCommand<PageComponent>(
        doc.rootHandle, pageOf(doc).copyWith(decimalSeparator: s));
```

  4. `I/test/support/rooms_plan.dart`, the colour picker's plan (`color_picker_test.dart:76-113`, `Rooms`, `roomsPlan`) as a plan file:

```dart
// The colour picker's plan (jet_cad_floor_plan/test/colors/
// color_picker_test.dart:76-113) as a plan file (3a Task 27): the two-room
// rectangle at the corpus far origin turned 23 degrees, every wall and the
// separator in its own rotated group, a separator at x = 6,250.5, room A
// `Kitchen` in a group turned 0.61 rad and room B `Room 2` at the identity,
// the page's grid hidden.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:flutter_test/flutter_test.dart';

import 'plans.dart';

/// The plan, opened: its controller (disposed at tear-down) and handles.
typedef Rooms = ({
  PlanController c,
  Plan plan,
  DraftDocument doc,
  Handle a,
  Handle b,
  Handle sep,
  Handle w
});

Rooms roomsPlan() {
  late Plan plan;
  late Handle a, b;
  final json = planWith((d) {
    plan = buildPlan(d, twoRoomWalls,
        seps: const [(6250.5, 100, 6250.5, 3900)], place: corpusGroups);
    attachPage(d, PageComponent(gridVisible: false));
    final g = Transform2.translation(
            plan.at(1400, 1900).x, plan.at(1400, 1900).y)
        .multiply(Transform2.rotation(0.61));
    a = addRoom(d, plan.at(1500.25, 2000.5), 'Kitchen', at: g);
    b = addRoom(d, plan.at(4700.75, 1900.25), 'Room 2');
  });
  final c = architectureController(json: json);
  addTearDown(c.dispose);
  return (
    c: c,
    plan: plan,
    doc: c.document,
    a: a,
    b: b,
    sep: plan.seps.single,
    w: plan.walls[4]
  );
}
```

     (`attachPage`'s page: today's replaced the document's whole page with `PageComponent(gridVisible: false)`; the plan file's page is replaced the same way.)

- [ ] **Step 3: The Wall section (WS).** Create `I/test/panels/wall_section_test.dart` from `selection_panel_test.dart` (it has no header comment before its imports, `:1-19`): the file's own `// Spec 07 D11's Wall section` paragraph (`:45-47`) as the header, plus `// Ported from jet_cad_floor_plan/test/selection_panel_test.dart (WS1-WS11; WS7 (Box) is 2a's) for jet_cad_2d_integration (3a Task 27); assertions unchanged but rulings IP-R1, IP-R2, IP-R8.` Every WS case (`:327-783`: WS1-WS6, WS7 (Wall), WS8, WS9 and WS10's loop; WS11, `:847-873`; WS7 (Box), `:624-652`, and the SE cases stay out) with:
  - imports: the plan barrel, the kit barrel, the integration library, `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart` (show `InteractionLayer`, `SelectionKey`, `ViewportTransform`), `'../support/plans.dart'`, `'../support/canvas_rig.dart'`; `dart:convert` for WS9.
  - finders (`:26-43`): `width` → `field('width')`; `height` → `field('height')`; `thickness` → `field('thickness')`; `wallSection` → `section(ArchitectureTypes.wall, ArchitectureTools.wall)`; `shownJustification(tester)` → `{menuOf(tester, 'justification').value! as Justification}`; `tapKey(tester, 'wall-<v>')` → `choose(tester, 'justification', '<v>')`; `textOf` unchanged.
  - `wa`, `wb`, `wc`, `bx`, `lStart`, `lCorner`, `lEnd` (`:49-55`) unchanged.
  - `panelDoc(m)` (`:57-89`) → `String panelPlanJson()`, its body inside `planWith((doc) { ... })`: the page command (`:62-68`), the three `addWall` commands and the box compound (`:72-85`) unchanged; the `DraftDocument.empty`/`PageComponent.register` lines (`:60-61`), the comment and `installParametric` (`:69-71`) and `system.dispose`/`clearHistory` (`:86-87`) dropped (the scratch controller's system regenerates).
  - `pumpPanel(tester, doc)` (`:91-109`) → over `architectureController(json: json)`, disposed at tear-down, in `pumpPlanEditor(tester, c)` (1440 x 900), then the same rotated camera (`:99-106`) on `c.camera`; returns the controller.
  - `select` (`:111-115`) over `c.activeSelection`; `clickWorld` (`:117-124`) over `c.camera`; `enterAndSubmit` (`:134-139`) unchanged; `pumpBoxes` (`:126-132`, the SE cases') not copied; `press(tester, k)` → `pressKey(tester, k)`; `status(tester)` → canvas_rig's.
  - `view.document` → `c.document`; `view.tools.active as WallTool` lines → ruling IP-R2 (left out, with a comment `// Not ported (ruling IP-R2): <the line>`); WS6's `PlacementTool tool() => …` → `Tool tool() => activeTool(tester);` and `tool().isPending` → `tool().isMidShape`; `walls(doc)`, `expectMitre`, `worldOutline`, `sharedNear`, `nearestIn`, `driftOf`, `kids`, `kindOf`, `payloadOf`, `enc`, `nextUp`, `plan`, `polar`, `addWall` from `plans.dart`.
  - WS9: `panelDoc` twice → `final j = jsonDecode(panelPlanJson()) as Map<String, Object?>;` for the edit, and a controller over the unedited text for the handles (`src` → `architectureController(json: panelPlanJson()).document`, disposed); the decoded document → `architectureController(json: jsonEncode(j))` (ruling IP-R8).
  - WS11: `kWallMaxThickness` → `const double kWallMaxThickness = 1e7; // jet_cad_floor_plan/lib/src/parametric/wall.dart:35 (kit-internal)`.
  - Run `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice test/panels/wall_section_test.dart`: `All tests passed!`.

- [ ] **Step 4: SE11, SE12, SE13, SE15, SE16 with their Wall lines.** Create `I/test/panels/selection_page_test.dart`: copy `packages/jet_cad_2d_plan/test/panels/selection_page_test.dart` whole, with:
  - header lines 1-6 → `// Ported from jet_cad_floor_plan/test/selection_panel_test.dart: SE11, SE12, SE13, SE15, SE16, through 2a's ports (jet_cad_2d_plan/test/panels/selection_panel_test.dart, selection_page_test.dart) with the architecture kit's box and the source's Wall lines restored (3a Task 27, Appendix A D-20); assertions unchanged.`
  - imports: `../support/panel_kits.dart`, `canvas_fixture.dart`, `design_harness.dart` → `package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart` (show `BoxParams`), `package:jet_cad_2d_integration/jet_cad_2d_integration.dart`, `'../support/canvas_rig.dart'`.
  - `select` → over `c.activeSelection`; `boxes(c)` unchanged (the kit's `BoxParams`).
  - `pumpBoxPanel` → `final c = architectureController(json: boxPlanJson()); addTearDown(c.dispose);` with `boxPlanJson()` the 2a fixture's document (`panel_kits.dart:507-528`: a 1:20 page at (7000, 3000)) saved with `ensureManifest`; the page's `snapToGrid: true` command and `clearHistory` as now; `pumpDesign(..., right: Column([PlanPropertyPanel, PlanPagePanel]))` → `pumpPlanEditor(tester, c, size: const Size(1440, 1080), layerPanel: false)` (the editor's right column is the property panel above the page panel, the layer panel off, as the 2a composition; 1080 high so the scale field is on screen), then the drawing camera of `canvas_fixture.dart:427-446` (`pumpDraw`: rotation 0.35, scale 2, centred on (7150, 3110)) set on `c.camera`.
  - `globalOf(tester, c, x, y)` and `press` unchanged (Task 9's rig, re-exported by canvas_rig); `canvasFocus`, `status` from canvas_rig.
  - In SE13, SE15 and SE16, after the existing `await press(tester, LogicalKeyboardKey.keyB); expect(status(tester), 'Box');`, add the source's lines (`selection_panel_test.dart:960-961`, `:1005-1006`, `:1032-1033`):

```dart
    await pressKey(tester, LogicalKeyboardKey.keyW);
    expect(status(tester), 'Wall');
```

    (the source pressed W only; 2a's B line, its stand-in, stays: both letters must reach the canvas, which holds the focus.)
  - SE11 and SE12 (coordinator's decision): copy 2a's `jet_cad_2d_plan/test/panels/selection_panel_test.dart:384-398` (SE11) and `:400-413` (SE12) into this file's `main`, after SE13, with its `panelTitle` getter (`:84-86`, the `property-panel` title `Box`) at the top level; they use this file's `pumpBoxes`, `typeWidthThenHeight`, `sizeOf` and `canvasFocus` (the same helpers 2a's two files share), with the same mapping as SE13 (the controller from `pumpBoxes` above, `press` and `status` from `canvas_rig.dart`), assertions unchanged. After each case's existing `await press(tester, LogicalKeyboardKey.keyB); expect(status(tester), 'Box');` add the source's two lines (`jet_cad_floor_plan/test/selection_panel_test.dart:923-924` in SE11, `:938-939` in SE12), the block above. 2a's own SE11 and SE12 stay where they are, unchanged.

- [ ] **Step 5: The colour row over rooms (CP).** Create `I/test/panels/colour_row_test.dart` from `colors/color_picker_test.dart`: the fixture case (`:314-321`), CP1 (`:323-391`), CP2 (`:393-462`), CP3 (`:464-527`, ruling IP-R7), CP4 (`:529-588`), CP5 (`:590-603`), CP6b (`:605-628`); CP6 and CP7-CP12 stay 2a's and 2b's.
  - header `:1-14` kept with `// Ported for jet_cad_2d_integration (3a Task 27, Appendix A D-21, D-39): the rooms, the wall and the separator are the architecture kit's; assertions unchanged but ruling IP-R7.`
  - imports: the plan barrel, the kit barrel (`RoomParams`, `WallParams`, `SeparatorParams`, `ArchitectureTools`), `package:jet_cad_2d_kit/jet_cad_2d_kit.dart` show `PlanSwatch`, `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart` show `InteractionLayer`, `SelectionKey`, `ViewportTransform`, `darkCanvasTone`, `kDarkCanvasPaper`, `'../support/plans.dart'`, `'../support/rooms_plan.dart'`, `'../support/canvas_rig.dart'`.
  - `swatch`, `picker`, `semanticsOf`, `tooltipOf`, `marked` (`:45-72`) copied with `FloorPlanColor.values` → `PlanSwatch.values` (2a's port, `colour_row_test.dart:37-71`); `k`, `over`, `expectRgb`, `tintRecords`, `snapOf`, `childSnaps`, `roomOf`, `paint`, `bareAt`, `insideA`, `insideB`, `kColourAlpha` (`:74`, `:178-239`) copied unchanged (not `:241-311`: the table editor's `Caps`, `mountEditor` and helpers, which the ported cases do not use).
  - `roomsPlan()` → `rooms_plan.dart`'s; `Rig.pump(tester, r, {capabilities, locale, theme})` (`:115-177`, with `select` and `rgb`) → over `r.c` in a `RepaintBoundary(key: capture, child: MaterialApp(locale:, theme:, supportedLocales: planSupportedLocales, localizationsDelegates: planLocalizationsDelegates, home: Scaffold(body: PlanEditor(controller: r.c))))` at 1440 x 900; `capabilities: Caps.full.copyWith(recolor: false)` (CP4) → `r.c.permissions = PlanPermissions.full.copyWith(recolor: false)` before the pump; the camera lines (`:145-151`) on `r.c.camera`; `rig.view` → `rig.c`; `view.selection` → `c.activeSelection`.
  - CP1: `LogicalKeyboardKey.keyW` and `escape` unchanged; `find.byKey(const Key('wall-section'))` (the Wall tool's settings) → `byKey('settings-${ArchitectureTools.wall}')`.
  - CP2: `kRoomTintTransparency` → `const int kRoomTintTransparency = 229; // jet_cad_floor_plan/lib/src/parametric/room.dart:125 (kit-internal)`; `canon`, `driftOf` from `plans.dart`; the rest unchanged.
  - CP4: `const FloorPlanStringsEn()` → `const PlanStringsEn()` (2a's port's strings), `strings.readOnlyDocument` unchanged.
  - CP3: lines `:497-507` (`recolorCommand`) left out with `// Not ported (ruling IP-R7): …`.

- [ ] **Step 6: The decimal separator.**
  1. Kit: `K/test/room/decimal_separator_test.dart`, Q0-S1 and Q0-S2 (`decimal_separator_test.dart:195-246`) with the fixture `:37-80` (`q0Walls`, `q0Page`, `q0Plan`, `separatorTo`) copied, assertions unchanged. Imports: `package:jet_cad_2d_kit_architecture/src/dimension/dimension.dart` (`FixedEnd`), `package:flutter_test/flutter_test.dart`, `package:jet_cad_2d/jet_cad_2d.dart`, `../support/dimension_fixture.dart` (Task 20's port: `buildPlan`, `attachPage`, `addRoom`, `addDimension`, `labelStrings`, `dimText`, `pageOf`, `driftOf`, `enc`, `kids`, `corpus`, `W`).
  2. Integration: `I/test/panels/decimal_separator_test.dart`, Q0-E1 (`:248-276`), Q0-E2 (`:278-285`), Q0-E3 (`:287-303`), Q0-E3b (`:305-312`), with the helpers `status`, `textAt`, `select`, `run`, `pumpShell`, `shellPlan`, `noticeCases` (`:82-193`):
     - `shellPlan()` → `final f = q0PlanJson(); final c = architectureController(json: f.json); addTearDown(c.dispose);` returning `(c: c, doc: c.document, room: f.room, dim: f.dim)`;
     - `pumpShell(tester, doc, {german})` → `pumpPlanEditor(tester, c, locale: german ? const Locale('de') : null)`; its premise `FloorPlanStrings.of(tester.element(find.byType(PlannerShell))).decimalSeparator` → `PlanStrings.of(tester.element(find.byType(PlanEditor))).decimalSeparator`;
     - `select(tester, view, h)` → over `c.activeSelection`; `textAt(tester, 'room-area')` → `textAt(tester, 'property-area')`, `'dimension-value'` → `'property-value'` (IP-R1);
     - `noticeCases`: `view.camera` → `c.camera`; `final tool = view.tools.active as DimensionTool;` and the two premises (`:184`, `:186`) → ruling IP-R3; `expect(tool.notice.value, want, …)` → `expect(c.textOf(c.toolNotice.value!), want, reason: '$separator')`;
     - `labelsOf`, `textOf`, `dimText`, `pageOf` from `plans.dart`; `separatorTo` from `q0_plan.dart`.

- [ ] **Step 7: The words (l10n).** Each file's header: `// Ported from jet_cad_floor_plan/test/l10n/<file> (3a Task 27, Appendix A D-24); assertions unchanged but the rulings named.`
  1. `I/test/l10n/determinism_test.dart` (DT1, `determinism_test.dart:1-225`, ruling IP-R4):
     - `samplePlan()` (`:31-49`) → `(String, Handle) samplePlan()`: `planWith((d) { …the layer Bar's AddLayerCommand, as today… }, kits: [architectureKit, fxKit(library: [diningTableTwo])], first: buildSampleFlat)`, `bar` returned.
     - `editedIn`: `FloorPlanController(json:)` → `PlanController(kits: [architectureKit, fxKit(library: [diningTableTwo])], json: json)`; `FloorPlanView(controller: c)` → `PlanEditor(controller: c)` with `planSupportedLocales`, `planLocalizationsDelegates`; the wait `c.symbols.state.toString().contains('Ready')` → `c.symbolsState.value != SymbolsState.ready` in the loop's condition; `symbol-cell-dining.table.square.two@2` → `symbol-cell-fx.dining.table.two@1`; `table-number` → `unit-label`; `room-name` → `property-name`; `c.cameraController` → `c.camera`; `c.activeDocument` → `c.document`; the premise `tester.widget<PlannerView>(...).tools.active, isA<SelectTool>()` → `activeTool(tester), isA<SelectTool>()` (plan.select is the Flutter layer's `SelectTool`, unguarded); `c.designJson()` → `c.save()`; `dimText`, `dimLines`, `labelsOf`, `textOf` from `plans.dart`.
     - DT1's assertions unchanged.
  2. `I/test/l10n/leak_test.dart` (LK2, `leak_test.dart:185-258`, rulings IP-R4, IP-R5): copy `_Recording`, `_numeric`, `_allowed`, `_letter`, `_planText`, `visibleTexts`, `recordingApp` (`:25-60`, `:96-105`) with `FloorPlanStrings` → `PlanStrings`, `RecordingFloorPlanStrings` → `RecordingPlanStrings`, `floorPlan*` → `plan*`, `FloorPlanLocalizations` → `PlanLocalizations`. `leaksOf` (`:63-94`): `furnitureSymbolNames…` (`:65-68`) → the kit's Turkish words and the fixture kit's symbol name; and `allowed` gains the filled templates:

```dart
/// The architecture kit's Turkish words, and its `text:` templates as
/// patterns (each `{name}` any non-empty run): what the kit hands the plan
/// (ruling IP-R5).
final List<String> kitWords = [
  ...architectureKit.names.words['tr']!.values,
  diningTableTwo.name,
];
final List<RegExp> kitTemplates = [
  for (final w in architectureKit.names.words['tr']!.values)
    if (w.contains('{'))
      RegExp('^${RegExp.escape(w).replaceAll(RegExp(r'\\\{[a-z]+\\\}'), '(.+)')}\$'),
];
```

     and in `allowed`: `if (kitWords.contains(text) || kitTemplates.any((t) => t.hasMatch(text))) return true;` in place of the `symbolWords` line. Check the escaping of the template pattern once on `Eksenler {degrees}° döndürülmüş` in the report (`RegExp.escape` escapes `{` and `}` as `\{`, `\}`).
     - LK2's body: `startupPlan(measurer, strings: recording)` → `final c = PlanController(kits: [architectureKit, fxKit(library: [diningTableTwo])]); addTearDown(c.dispose); c.reportLocale(const Locale('tr'), strings: recording); c.newPlan(build: buildSampleFlat);` (C1.9: the sample built in the reported language; the rooms' names are the kit's Turkish words); `FloorPlanView` → `PlanEditor`; the wait and the cell key as DT1's; `c.activeDocument` → `c.document`; the section keys (`:236-243`) → `section-architecture.wall`, `section-architecture.opening`, `section-architecture.room`, `section-architecture.dimension`, `symbol-section`, `unit-section`; `expect(kinds, hasLength(6))` unchanged.
  3. `I/test/l10n/overflow_test.dart` (OV-H, `overflow_test.dart:82-111`, the three languages): `furnishedPlan()` (`:70-80`) → `planWith((d) { final h = placeAt(d, tableSymbol(seats: 4), Vector2(1234.5, 2345.25), quarterTurns: 1); labelUnit(d, h, '1'); }, kits: [architectureKit, fxKit()], first: buildSampleFlat)` (today's placer numbered it `1`); `FloorPlanController` → `PlanController(kits: [architectureKit, fxKit()], json: …)`; `FloorPlanView` → `PlanEditor`; `TableSurvey.of(doc).tables` isNotEmpty → `c.units` isNotEmpty; `c.activeDocument` → `c.document`.
  4. `I/test/l10n/panel_words_test.dart` (PW1, PW2 whole, ruling IP-R6): `wallPlan()` (`:18-35`) → `planWith((doc) { final h = doc.handleSeed.next(); doc.commands.execute(addWall(doc, h, Vector2(-1830.5, 640.25), Vector2(2470.75, 1210.5), 112.5, Justification.centre)); …the page scale command… })` returning `(json, h)`; `app` → `PlanEditor` with the plan's delegates; `fieldText(tester, 'wall-thickness')` → `tester.widget<TextField>(field('thickness')).controller!.text`; `typeInto(tester, 'wall-thickness', …)` → over `field('thickness')`; `page-scale` unchanged. In PW1, the loop over the ten words splits: before it, `await tester.tap(field('justification')); await tester.pumpAndSettle();` (the menu shows `Sol`, `Orta`, `Sağ`), the loop unchanged, then `await tester.tap(find.text('Orta').last); await tester.pumpAndSettle();`.
  5. `I/test/l10n/numbered_names_test.dart` (NN3, `numbered_names_test.dart:60-78`): `roomsOf(strings)` → `roomsOf(Locale locale)`: `final c = PlanController(kits: [architectureKit]); c.reportLocale(locale); c.newPlan(build: buildSampleFlat); final names = [for (final h in c.document.components.withComponent<RoomParams>()) c.document.components.get<RoomParams>(h)!.name]; c.dispose(); return names;`; `FloorPlanStringsEn()`, `Tr()`, `De()` → `Locale('en')`, `Locale('tr')`, `Locale('de')`; a `testWidgets` (the controller's measurer); assertions unchanged.
  6. `I/test/l10n/locale_separator_test.dart` (NS3): 2a's port (`packages/jet_cad_2d_plan/test/controller/locale_separator_test.dart:96-115`) over the q0 plan, the source's room line restored (`host/new_plan_separator_test.dart:299-300`):

```dart
  testWidgets(
      'NS3 a loaded plan is never settled (N2): by the constructor or by '
      'load(), a point plan shown in Turkish stays point, its texts with .',
      (tester) async {
    final f = q0PlanJson();
    final json = f.json;
    final premise = architectureController(json: json);
    addTearDown(premise.dispose);
    expect(separatorOf(premise.document), DecimalSeparator.point,
        reason: 'premise');
    final byJson = architectureController(json: json);
    addTearDown(byJson.dispose);
    byJson.reportLocale(const Locale('tr'));
    final doc = byJson.document;
    expect(separatorOf(doc), DecimalSeparator.point);
    final room = doc.components.withComponent<RoomParams>().single;
    expect(textOf(doc, labelsOf(doc, room)[1]), '12.37 m²');
    expect(byJson.save(), json, reason: "the bytes are the file's");

    final byLoad = architectureController();
    addTearDown(byLoad.dispose);
    byLoad.load(json);
    byLoad.reportLocale(const Locale('tr'));
    expect(separatorOf(byLoad.document), DecimalSeparator.point);
    expect(byLoad.dirty.value, isFalse);
    expect(byLoad.save(), json);
    await tester.pump();
  });
```

     with `separatorOf` copied from 2a's port (`locale_separator_test.dart` top), and the premise controller disposed (`addTearDown`). The case's title is the source's (`new_plan_separator_test.dart:286-287`).
  7. Kit: `K/test/words/value_words_test.dart`, VW3's Room-notice line (`value_words_test.dart:88-89`), its helper `expectWorded` (`:28-39`) over the kit's words:

```dart
// Ported from jet_cad_floor_plan/test/l10n/value_words_test.dart: VW3's
// Room-notice line (3a Task 27, Appendix A D-24; VW3's other lines are
// 2a's and 2b's), assertions unchanged. The notice is the kit's text
// `text:architecture.room-occupied` with `{name}` (spec C1.2, C1.6),
// worded in each language by `KitWords.text`.
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';

final List<KitWords> languages = [
  for (final code in ['en', 'de', 'tr'])
    KitNamesWords(architectureKit.names, () => Locale(code)),
];

/// [word] in each language: never empty, holding every [parts], and
/// different in each language (value_words_test.dart:28-39).
void expectWorded(String Function(KitWords s) word,
    {List<String> parts = const [], String? english}) {
  final words = [for (final s in languages) word(s)];
  for (final (i, w) in words.indexed) {
    expect(w, isNotEmpty);
    for (final p in parts) {
      expect(w, contains(p), reason: '${languages[i].locale}: $w');
    }
  }
  expect(words.toSet(), hasLength(3), reason: '$words');
  if (english != null) expect(words.first, english);
}

void main() {
  test('VW3 the Room notice in each language', () {
    expectWorded(
        (s) => s.text('text:architecture.room-occupied', {'name': 'Mutfak'}),
        parts: ['Mutfak'],
        english: 'Already a room: Mutfak');
  });
}
```

- [ ] **Step 8: The new tests: titles and the door's actions (D-46).** Create `I/test/panels/titles_test.dart`:

```dart
// 3a Task 27 (Appendix A D-46; spec C1.1, C1.7, C3.3): the property
// panel over the real kit. An opening's section is titled by its kind
// (`PlanType.title`), and a door's flips are `ActionProperty`s shown for a
// door only (`visible`): a tap is one step that flips the one field. Over
// the sample flat (its doors and windows), at 1440 x 900.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';

import '../support/canvas_rig.dart';

/// The sample's first opening of [kind], by handle.
Handle firstOf(DraftDocument d, OpeningKind kind) =>
    (d.components.withComponent<OpeningParams>().toList()
          ..sort((a, b) => a.value.compareTo(b.value)))
        .firstWhere((o) => d.components.get<OpeningParams>(o)!.kind == kind);

void main() {
  testWidgets(
      'IP-title an opening\'s section is titled by its kind: Door for a '
      'door, Window for a window (D-46, the title hook)', (tester) async {
    final c = sampleFlatController();
    addTearDown(c.dispose);
    await pumpPlanEditor(tester, c);
    final title = byKey('section-${ArchitectureTypes.opening}');
    for (final (kind, word) in const [
      (OpeningKind.door, 'Door'),
      (OpeningKind.window, 'Window'),
    ]) {
      c.activeSelection.replace([SelectionKey.root(firstOf(c.document, kind))]);
      await tester.pump();
      expect(tester.widget<Text>(title).data, word, reason: kind.name);
    }
  });

  testWidgets(
      'IP-door-actions a door shows Flip hinge and Flip swing; a tap flips '
      'that field alone in one step; a window shows neither (D-46: '
      'ActionProperty and visible)', (tester) async {
    final c = sampleFlatController();
    addTearDown(c.dispose);
    await pumpPlanEditor(tester, c);
    final d = c.document;
    final door = firstOf(d, OpeningKind.door);
    c.activeSelection.replace([SelectionKey.root(door)]);
    await tester.pump();
    final p0 = d.components.get<OpeningParams>(door)!;
    final depth = d.commands.undoDepth;
    await tester.tap(field('flip-swing'));
    await tester.pump();
    final p1 = d.components.get<OpeningParams>(door)!;
    expect(p1.swing, isNot(p0.swing), reason: 'the swing flipped');
    expect(p1.hinge, p0.hinge, reason: 'the hinge kept');
    expect(d.commands.undoDepth, depth + 1, reason: 'one step');
    await tester.tap(field('flip-hinge'));
    await tester.pump();
    final p2 = d.components.get<OpeningParams>(door)!;
    expect(p2.hinge, isNot(p1.hinge), reason: 'the hinge flipped');
    expect(p2.swing, p1.swing, reason: 'the swing kept');
    final window = firstOf(d, OpeningKind.window);
    c.activeSelection.replace([SelectionKey.root(window)]);
    await tester.pump();
    expect(byKey('section-${ArchitectureTypes.opening}'), findsOneWidget,
        reason: 'premise: the window\'s section');
    expect(field('flip-hinge'), findsNothing);
    expect(field('flip-swing'), findsNothing);
  });
}
```

- [ ] **Step 9: Run.** `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice test/panels test/l10n`; `cd packages/jet_cad_2d_kit_architecture && flutter test test/room/decimal_separator_test.dart test/words/value_words_test.dart`. Expected: `All tests passed!` each. A ported case that fails is a finding for the task owning the code (stop; quote the red line and its source line). IP-title and IP-door-actions pass at once (Task 14 made the title and the flips); Step 12 shows them red.

- [ ] **Step 10: Format and the gates.**
  - `cd packages/jet_cad_2d_integration && dart format . && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_kit_architecture && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - From the root: `dart run tool/ci/check_kit_deps.dart`.
  - `grep -rn "package:jet_cad_2d_plan/src\|package:jet_cad_2d_kit_architecture/src" packages/jet_cad_2d_integration`: prints nothing (R-P1).
  - Non-ASCII, byte for byte with the sources: `grep -n "Kalınlık\|Sağ\|Ölçek\|Izgara\|Bemaßung\|Küche\|Yatak odası\|Yemek odası\|m²\|—" packages/jet_cad_2d_integration/test/l10n/*.dart packages/jet_cad_2d_integration/test/panels/*.dart packages/jet_cad_2d_kit_architecture/test/words/value_words_test.dart` and the same grep over the source files; every literal matches.
  - `git status --short`: this task's files only.

- [ ] **Step 11: Commit.**

```bash
git add packages/jet_cad_2d_integration/test/support/q0_plan.dart packages/jet_cad_2d_integration/test/support/recording_plan_strings.dart packages/jet_cad_2d_integration/test/support/rooms_plan.dart packages/jet_cad_2d_integration/test/support/units.dart packages/jet_cad_2d_integration/test/panels/wall_section_test.dart packages/jet_cad_2d_integration/test/panels/selection_page_test.dart packages/jet_cad_2d_integration/test/panels/colour_row_test.dart packages/jet_cad_2d_integration/test/panels/decimal_separator_test.dart packages/jet_cad_2d_integration/test/panels/titles_test.dart packages/jet_cad_2d_integration/test/l10n/determinism_test.dart packages/jet_cad_2d_integration/test/l10n/leak_test.dart packages/jet_cad_2d_integration/test/l10n/overflow_test.dart packages/jet_cad_2d_integration/test/l10n/panel_words_test.dart packages/jet_cad_2d_integration/test/l10n/numbered_names_test.dart packages/jet_cad_2d_integration/test/l10n/locale_separator_test.dart packages/jet_cad_2d_kit_architecture/test/room/decimal_separator_test.dart packages/jet_cad_2d_kit_architecture/test/words/value_words_test.dart
git commit -m "$(cat <<'EOF'
test(integration): the panels and the words over the kit (3a Task 27)

The Wall section's cases and the Page panel's Wall lines, the colour row
over real rooms with the tint's pixels, the area and value rows and the
Dimension tool's notice under the page's separator, the opening's title
and the door's flips, and the words: the same UI edits encode the same
bytes in English and Turkish, nothing bypasses the strings, nothing
overflows, the Wall section in Turkish and German, the sample's rooms in
each language and a loaded plan's room label kept. The separator switch
and the Room notice's words run in the kit.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 12: Mutation check** (committed files only; after each: run the named test, see it red, quote the red line, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0; integration tests with `flutter test --enable-vmservice <file>` from `packages/jet_cad_2d_integration`).
  - M-IP-1 `packages/jet_cad_2d_kit_architecture/lib/src/opening/opening_plan.dart`: the `title:` hook deleted (the section falls back to `type:architecture.opening`) → IP-title red.
  - M-IP-2 `opening_plan.dart`: the Flip swing action's `apply` returns the params with the hinge flipped instead of the swing → IP-door-actions red.
  - M-IP-3 `opening_plan.dart`: the flips' `visible:` deleted → IP-door-actions red (the window shows them).
  - M-IP-4 `packages/jet_cad_2d_kit_architecture/lib/src/wall/wall_plan.dart`: the thickness `write`'s strict check (`isWallThickness`) deleted → WS3 red (a thickness of 0 commits).
  - M-IP-5 `packages/jet_cad_2d_kit_architecture/lib/src/room/room_plan.dart`: the `colour:` target deleted → CP1 red (no colour row for a room).
  - M-IP-6 `packages/jet_cad_2d_kit_architecture/lib/src/dimension/dimension_tool.dart`: the notice's value formatted with `'.'` instead of the page's separator → Q0-E2 red (`345.7` where `345,7` is wanted).
  - M-IP-7 `packages/jet_cad_2d_kit_architecture/lib/src/words/tr.dart`: `text:architecture.room-occupied`'s Turkish template loses `{name}` → VW3 red (`contains('Mutfak')`).
  Quote each red line.

#### Interface problem

None open. The reads of a kit tool's private state are ruled (IP-R2, IP-R3) under R-P1; no line needs R-P9's `@internal` ignore here.

#### New shared name

Integration test support (Tasks 28's R-16 ports may import them): `I/test/support/q0_plan.dart` (`q0Walls`, `q0Page`, `({String json, Handle room, Handle dim}) q0PlanJson()`, `DraftCommand separatorTo(DraftDocument, DecimalSeparator)`), `I/test/support/rooms_plan.dart` (`typedef Rooms`, `Rooms roomsPlan()`), `I/test/support/recording_plan_strings.dart` (`RecordingPlanStrings`), and `units.dart`'s `CatalogSymbol diningTableTwo`.

---

