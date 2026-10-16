### Task 18: The room type, grips, properties and colour (spec C3.5, C1.1, C1.7, C6, C7)

**Files:**
- Create (`packages/jet_cad_2d_kit_architecture/`):
  - `lib/src/room/room.dart` (ported: `RoomParams`, the tint and label constants, `debugRoomGenerates`, `debugTintFailedSteps`, `RoomType`)
  - `lib/src/room/room_grips.dart` (ported: `RoomGrips`)
  - `lib/src/room/room_plan.dart` (new: `roomPlanType`, `roomAreaText`, `debugRoomAreaReads`; Task 19 adds `roomPlanTool`)
  - `test/room/room_plan_test.dart` (new: RM-fields, RM-name, RM-area, RM-colour, RM-grips)
  - Ported: `test/room/room_object_test.dart`, `room_grips_test.dart` (kit cases), `room_color_test.dart` (kit cases), `room_tint_test.dart`, `room_diagnostics_test.dart`, `room_dissolve_test.dart`, `room_follow_test.dart`, `room_cost_test.dart` (RK1, RK2)
- Modify (`packages/jet_cad_2d_kit_architecture/`): `lib/jet_cad_2d_kit_architecture.dart` (export `RoomParams`), `lib/src/kit.dart` (`roomPlanType` in `types`), `lib/src/type_naming.dart` (Task 14's, ruling R-P19: the room's registration after the separator's), `test/support/catalog.dart` (the room's line in `_testCatalog`'s cascade, R-P13), `test/support/room_fixture.dart` (`addRoom`, `addSampleRooms`, `renameRoom`), `test/room/room_tie_test.dart` (DE2, DE3), `test/separator/separator_tool_test.dart` (Task 17's: ST4, carried from Task 17)
- Create (`packages/jet_cad_2d_integration/`):
  - `test/support/room_plans.dart` (new: room plans built by a `PlanBuild`, the editor driven over `PlanController`)
  - `test/room/room_grips_test.dart` (ported shell cases: GR1 (shell), GR2, GR3, GR4, GR5 (shell))
  - `test/room/room_panel_test.dart` (ported: the fixture case, RN1, RN2, RN3, RN4, RN5, RN5 (refused edit), RN6)
  - `test/room/room_color_test.dart` (ported: RC8)

**Interfaces:**
- Consumes:
  - Task 16: `room_inputs.dart` (`placeSourceInView`, `RoomInputs`, `roomInputsOf`), `room_trace.dart`, `room_label.dart`, `SeparatorParams`; the kit's test support `room_fixture.dart` (with `liveOf`, re-exporting `testCatalog` and `installParametric`, R-P6).
  - Task 17: `separatorPlanType` (`lib/src/separator/separator_plan.dart`), its grips over `roomInputsOf(services)` and `services.objectSnap` (GR5's kit case).
  - Task 12: `wallPlanType` (`lib/src/wall/wall_plan.dart`) and its grips (`room_follow_test`'s `dragEnd`).
  - Task 9: `ArchitectureTypes`, `architectureKit` (`lib/src/kit.dart`, its `types` list), the words `type:architecture.room` ('Room', 'Raum', 'Oda'), `property:architecture.room.name` ('Name', 'Name', 'Ad'), `property:architecture.room.area` ('Area', 'Fläche', 'Alan'); the integration library's `architectureController({String? json, PlanPermissions permissions})` and `planEditorApp(PlanController controller, {Locale locale})`.
  - Task 2, with ruling R-P4: `PlanObject` (`document`, `handle`, `world`, `words`), `TextDisplay<T>({required String id, required String? Function(T value, PlanObject object) read, ...})`, `PropertyField.visible`, `PlanType.fieldsOf(DraftDocument document, Handle group, PlanWords words)`, `PlanType.commitField(DraftDocument document, Handle group, PropertyField field, Object? input, PlanWords words)` (R-P7: a `KitWords` is passed); the plan panel's `TextDisplay` row keyed `property-<id>` (as `ValueDisplay`'s, `plan_property_panel.dart:745-750`).
  - Task 5: `PlanController(kits:, build: PlanBuild)` (C1.9): the integration fixture builds its plans with it.
  - Task 6: `FakePlanServices` (`scale`, `objectSnap`, `catalog`; `camera.value.scale` is `scale`).
  - Contract today: `PlanType`, `TextProperty`, `ColourTarget` (`kit/colour.dart:12-17`), `PlanGate.reshape`, `PlanSwatch`, `planSwatchNamed` (`kit/swatch.dart:16-41`).
  - Engine: `kSnapAperturePixels` (`jet_cad_2d/lib/src/index/drag_snap.dart:14`), `DraftCommandDispatcher.stateId` (`document/undo.dart:185`).
  - Plan library (integration): `PlanController` (`document`, `activeSelection`, `camera`, `worldToGlobal`, `execute`, `export`, `save`, `dispose`), `PlanCanvas`, `PlanExportChoice`, `PlanExportDpi`; `@internal` `grips` and `fill` (see "Interface problem" 2).
- Produces:

```dart
// lib/src/room/room.dart — today's names (spec 3a "Shared interfaces"):
final class RoomParams implements Component {          // exported by the barrel
  static const String componentTypeId = ArchitectureTypes.room;  // was 'floor_planner.room'
  PlanSwatch? get colorValue;                          // was FloorPlanColor? (the contract's palette)
  /* the rest unchanged */
}
const DraftColor kRoomTintColor; const int kRoomTintTransparency, kRoomColorTransparency;
const double kRoomNamePaperMm, kRoomAreaPaperMm, kRoomLineOffset, kRoomReadMargin;
final int kRoomLabelAttrs; int debugRoomGenerates; Set<int>? debugTintFailedSteps;
final class RoomType extends ParametricType<RoomParams> { /* unchanged */ }
// lib/src/room/room_grips.dart
final class RoomGrips implements ObjectGripProvider {
  RoomGrips({required double Function() aperture});   // unchanged
}
// lib/src/room/room_plan.dart (Shared interfaces: "roomPlanType (Task 18)")
final PlanType<RoomParams> roomPlanType;
String roomAreaText(PlanObject object);                // the Area line's read
@visibleForTesting int debugRoomAreaReads;
```

  Integration test support (`packages/jet_cad_2d_integration/test/support/room_plans.dart`), consumed by Task 19: `W`, `S`, `O`, `R`, `Placement`, `origin`, `corpus`, `corpusGroups`, `twoRoomWalls`, `boxWalls`, `sampleWalls`, `sampleColumn`, `sampleSeparator`, `sampleOpenings`, `RoomPlan` (`c`, `place`, `walls`, `seps`, `openings`, `rooms`, `doc`, `at`), `roomPlan(...)`, `pumpAt`, `clickAt`, `dragWorld`, `undoKey`, `toggleF3`, `osnap`, `select`, `recordOf`, `labelsOf`, `textOf`, `labelStrings`, `pageOf`, `anchorOf`, `worldTintOf`, `deleteObject`, `rooms`, `nameOf`; re-exported: the rig's `pumpEditor`, `globalAt`, `press`, `status`, `kitCatalog` (R-P14) and Task 12's `kids`, `kindOf`, `payloadOf`, `enc`, `driftOf`.

**Appendix A rows closed:**
- D-19, the room's files: `room_object_test` (10 of 10), `room_grips_test` (9 of 9: GR1, GR5, GR6 kit; GR1 (shell), GR2, GR3, GR4, GR5 (shell) integration), `room_color_test` (9 of 9: the fixture case and RC1-RC7 kit; RC8 integration), `room_tint_test` (1 of 1), `room_diagnostics_test` (4 of 4), `room_dissolve_test` (9 of 9), `room_follow_test` (9 of 9), `room_panel_test` (8 of 8, integration), `room_tie_test` DE2, DE3 (with Task 16's DE1: 3 of 3), `room_cost_test` RK1, RK2 (LZ3: Task 16's "Interface problem" 3). **Not closed here:** `room_paint_test` (6), see "Interface problem" 1 (Task 26's, ruling R-P10).
- D-19, `separator_tool_test` ST4 (carried from Task 17: it adds a room), in the kit (Step 3b); with Task 17's five, the file is closed.
- D-31: the room's colour target (`roomPlanType.colour`, RM-colour); `room_color_test` (kit, and RC8 in C6) and `room_tint_test` (kit). CP2 is D-21's (Task 27).
- D-46, in part: the room's Area as a `TextDisplay` exercised through the real kit (RM-area; RN1, RN6 in the panel). Titles by `title` and `ActionProperty` are the opening's (Tasks 14, 27).

**Placement (spec C7), per file and case.**

| Source (`jet_cad_floor_plan/test/`) | Kit (`test/room/`) | Integration (`test/room/`) | Why |
|---|---|---|---|
| `room_object_test.dart` | RP1, RG1, RG4, RG5, RG6, RG7, RL3, RL4, RA2, RX1 | — | engine and kit names only |
| `room_grips_test.dart` | GR1, GR5, GR6 | GR1 (shell), GR2, GR3, GR4, GR5 (shell) | the shell cases pump `PlannerShell` and read `PlannerView.grips` |
| `room_color_test.dart` | the fixture case, RC1-RC7 | RC8 | RC8 exports through today's `exportBytes`, now `PlanController.export` |
| `room_tint_test.dart` | TN1 | — | |
| `room_diagnostics_test.dart` | DG1-DG4 | — | |
| `room_dissolve_test.dart` | RG2, RD1-RD8 | — | |
| `room_follow_test.dart` | RG3, RS1-RS6, DF1, FZ1 | — | `WallGrips` is the kit's (through `wallPlanType`) |
| `room_tie_test.dart` | DE2, DE3 (DE1: Task 16) | — | |
| `room_cost_test.dart` | RK1, RK2 | — | LZ3: Task 26's (ruling R-P10, in the kit over `buildSampleFlat`) |
| `room_panel_test.dart` | — | all 8 cases | `PlannerShell`, the Selection panel |
| `room_paint_test.dart` | — | — | not ported here: "Interface problem" 1 |

  **Ruling R-P1 holds for every integration case here:** each needs the plan's public widgets or controller (`PlanEditor`, `PlanCanvas`, `PlanPropertyPanel`, `PlanController.export`) and imports only public libraries (the kit's barrel exports `RoomParams`, `WallParams`, `SeparatorParams`, `OpeningParams` and the enums the fixture builds with); the one kit internal a shell case read (GR4's tracer) is reached through public behaviour ("Interface problem" 3). The `@internal` plan members of "Interface problem" 2 are members of public classes, not imports.
  No case has a twin in `packages/jet_cad_2d_plan/test/` or `packages/jet_cad_2d_kit/test/` (`grep -rln "RoomParams\|room-name\|'RN[0-9]\|'GR[0-9]" packages/jet_cad_2d_plan/test packages/jet_cad_2d_kit/test` finds nothing; the plan's `panels/property_panel_test.dart` pins the generic text-field cycle over the box kit, not the room's name and area).

**Plan decisions:**
- **The Area line is a `TextDisplay`** (spec C1.1): `roomAreaText` is today's `_areaOf` (`jet_cad_floor_plan/lib/src/selection_panel.dart:826-844`): the second TEXT child in handle order, '—' with fewer (today's panel wrote '—' for null, `:1384`). It is memoised per document by `(handle, document.commands.stateId)`: today's memo was dropped on every `commands.changes` event (`:279-281`), and `stateId` moves on exactly the commands those events report (`undo.dart:166-183`).
- **The Name field** is a `TextProperty` whose `write` trims and throws `ArgumentError` on an empty name (today's `_parse`, `selection_panel.dart:392-402`: "trimmed, unless that leaves it empty"), gated by `PlanGate.reshape` (today's `_capable`: an object's own field needs `reshape`, `:384-391`). The plan's panel already trims before it commits (`plan_property_panel.dart:416`); the kit's trim makes the type's own rule hold for any host.
- **The grips** are today's `RoomGrips` over the aperture today's shell gave it: `kSnapAperturePixels / camera.scale`, whatever F3 says (`planner_shell.dart:653`, Ruling 10-17).
- **The colour target** is the room's palette name (`ColourTarget<RoomParams>`); the colour row lists kit targets before units (2b), today's "rooms first, then tables".
- **Kit-case adaptations of today's grip dispatcher.** Today's tests build `ObjectGrips(edgeAperture: () => null, labelAperture: () => ap)` (`room_grips_test.dart:222-223, 630-631`), which hands a room to `RoomGrips(aperture: labelAperture)` (`parametric/object_grips.dart:57`). The port asks the kit type's own provider over a `FakePlanServices` whose camera gives the same aperture: `scale = kSnapAperturePixels / ap` (fixture change; assertions unchanged). GR5's `ObjectGrips(roomInputs: inputs, objectSnap: () => snap)` becomes `separatorPlanType`'s provider over one `FakePlanServices` per F3 state.
- **Integration fixtures.** A shell case's plan is built by a `PlanBuild` (spec C1.9): the plan library makes the document, prepares it, installs its own system with every kit's types, runs the build and clears the history, which is what today's shell fixtures did by hand (`plan.system.dispose(); plan.doc.commands.clearHistory();`, e.g. `room_panel_test.dart:122-123`). Each object is one command, in the kit fixture's order, so the handles are today's. `driftOf` in the integration package is a `ParametricSystem` over a catalog of `architectureKit.types` (`PlanType.registerInto`, public), not installed (today's `driftOf` likewise constructs an uninstalled system, `wall_fixture.dart:277-278`).
- **Integration finders** (C7 class 3, widgets that changed form): `Key('room-section')` → `Key('section-architecture.room')`, `Key('room-name')` → `Key('property-name')`, `Key('room-area')` → `Key('property-area')`, `Key('wall-section')` → `Key('section-architecture.wall')` (`plan_property_panel.dart:700-703, 826-828`); `PlannerView.selection` → `PlanController.activeSelection`, `.camera` → `PlanController.camera`, `.document` → `PlanController.document`, `InteractionLayer` → `PlanCanvas`.

- [ ] **Step 1: Precondition.** Tasks 16 and 17 (and 2-6, 9, 12) are committed. Run, one by one: `cd packages/jet_cad_2d_kit_architecture && flutter analyze` (expected `No issues found!`), `cd packages/jet_cad_2d_integration && flutter analyze` (expected the same), and `grep -n "separatorPlanType\|wallPlanType" packages/jet_cad_2d_kit_architecture/lib/src/kit.dart` (expected both listed in `types`).

- [ ] **Step 2: The kit's test support.**
  1. `test/support/catalog.dart` (R-P13): in `_testCatalog`'s cascade, after the separator's registration, add `import 'package:jet_cad_2d_kit_architecture/src/room/room.dart';` and

```dart
  ..register<RoomParams>(
      RoomParams.componentTypeId, RoomParams.fromJson, const RoomType())
```

  2. `test/support/room_fixture.dart`: add `import 'package:jet_cad_2d_kit_architecture/src/room/room.dart';` and copy back today's three room helpers, unchanged: `addRoom` (`jet_cad_floor_plan/test/support/room_fixture.dart:561-579`) after `attachPage`, `addSampleRooms` (`:669-677`) after `deleteObject`, `renameRoom` (`:694-697`) after `staleFile`. Remove the header sentence Task 16 added about them ("The room helpers that need RoomParams (addRoom, addSampleRooms, renameRoom) arrive with the room (Task 18).").

- [ ] **Step 3: The failing kit tests (ported).** Copy each source from `packages/jet_cad_floor_plan/test/`; **assertions unchanged** in every case. The import rule is Task 16's (`package:jet_cad_floor_plan/src/parametric/<f>.dart` → `package:jet_cad_2d_kit_architecture/src/<dir>/<f>.dart`; `support/` → `../support/`); each file gains `// Ported from jet_cad_floor_plan/test/<file>; assertions unchanged.` after its header (naming the C7 class where one applies). `RoomInputs(x)` → `RoomInputs(x, liveOf(x))` wherever it appears.

  | Source → destination | Cases | Further adaptations (source lines) |
  |---|---|---|
  | `room_object_test.dart` → `test/room/room_object_test.dart` | RP1, RG1, RG4, RG5, RG6, RG7, RL3, RL4, RA2, RX1 | :104, :105 `'floor_planner.room'` → `'architecture.room'` (C7 class 1). `RoomInputs(doc)` at :89, :270, :281. |
  | `room_tint_test.dart` → `test/room/room_tint_test.dart` | TN1 | `RoomInputs(...)` at :319, :365, :640. |
  | `room_diagnostics_test.dart` → `test/room/room_diagnostics_test.dart` | DG1, DG2, DG3, DG4 | `RoomInputs(doc)` at :424. |
  | `room_dissolve_test.dart` → `test/room/room_dissolve_test.dart` | RG2, RD1-RD8 | `RoomInputs(doc)` at :750. |
  | `room_follow_test.dart` → `test/room/room_follow_test.dart` | RG3, RS1-RS6, DF1, FZ1 | Line 19 (`catalog.dart`) dropped (the fixture re-exports `installParametric`, R-P6); line 27 (`wall_grips.dart`) → `import 'package:jet_cad_2d_kit/testing.dart';` and `import 'package:jet_cad_2d_kit_architecture/src/wall/wall_plan.dart';`; `dragEnd` (:139-143) becomes the code below; :712 `installParametric(fresh)` unchanged (R-P6); :713 `ensureDashedLinetype` from `package:jet_cad_2d_kit_architecture/src/separator_linetype.dart` (add the import); `RoomInputs(...)` at :201, :741, :919. |
  | `room_tie_test.dart` (Task 16's file) | DE2, DE3 | Insert line 15 (`room_label.dart`, kit path) and source lines 436-616 before `main`'s closing `}`. |
  | `room_cost_test.dart` → `test/room/room_cost_test.dart` | RK1, RK2 | Copy lines 1-6 (header), 18-73 (`median`, `cell`, `gridWalls`, `stripWalls`, `roomCells`, `addRooms`), then `void main() {`, lines 176-313 (RK1, RK2) and `}`. Imports: `flutter_test`, `jet_cad_2d`, `package:jet_cad_2d_kit_architecture/src/room/room.dart`, `../support/room_fixture.dart` (lines 7, 9-12 and 15, used by LZ3 alone, are not copied). Add to the header: `// LZ3 (the sample flat's rebuild bound) lands with the sample flat (Task 25).` |
  | `room_color_test.dart` → `test/room/room_color_test.dart` | the fixture case, RC1, RC2, RC3, RC4, RC5, RC6, RC7 | Copy lines 1-402 and a closing `}` (RC8, :403-491, is integration). Imports: line 15 (`dart:typed_data`), 16 (`dart:ui`), 19-22 (export) dropped; line 18 (`colors/plan_color.dart`) → `import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanSwatch, planSwatchNamed;`; line 26-27 `show ExportDpi, FlutterTextMeasurer` → `show FlutterTextMeasurer`. RC5 (:281-303): `FloorPlanColor` → `PlanSwatch`, `floorPlanColorNamed` → `planSwatchNamed` (the contract's names for today's palette, `kit/swatch.dart:16-41`). RC6 :314 `['floor_planner.room']` → `['architecture.room']` (C7 class 1). |
  | `room_grips_test.dart` → `test/room/room_grips_test.dart` | GR1, GR5, GR6 | Copy lines 1-17 (header), 36-138 (`k`, `kitchenLabel`, `sep`, `Fx`, `gripPlan`, `roomOf`, `sepOf`, `anchorFromArea`, `poleLocal`, `labelFor`, `lineOf`, `distToLine`), 211 (`at`), and the cases :214-330 (GR1), :481-579 (the `for` loop and GR5's `test`, without the `testWidgets` at :581-614) and :615 (the `for` loop's closing `  }`), :617-689 (GR6 and `main`'s closing `}`). Imports: `dart:math`, `flutter_test`, `jet_cad_2d` (`kSnapAperturePixels` too), `jet_cad_2d_flutter` (`ObjectGripProvider`, `Grip`, `GripRole`, `SelectionKey`), `vector_math`, `package:jet_cad_2d_kit/testing.dart`, the kit's `room/room.dart`, `room/room_inputs.dart` (`roomInputsOf`), `room/room_plan.dart`, `separator/separator.dart`, `separator/separator_plan.dart`, `wall/wall.dart` (GR5's added wall), `../support/room_fixture.dart`; not `room_trace.dart` (GR4's, integration) nor `flutter/gestures`, `flutter/material`, `flutter/services` (the shell helpers'): `unused_import` is an error in this workspace, so the analyzer is the check. `gripPlan`'s `shell` parameter and its `if (shell) plan.system.dispose();` (:65, :78) are dropped (the shell cases build their own plans). The grip providers: the code below. |

  `room_follow_test.dart`'s `dragEnd` (today's `:139-143`):

```dart
/// Wall [h]'s end [end] (0 start, 1 end) dragged to world [to] by the
/// select tool's end grip (the wall type's grips: joined ends follow).
DraftCommand? dragEnd(DraftDocument doc, Handle h, int end, Vector2 to) {
  final services =
      FakePlanServices(document: doc, catalog: testCatalog());
  try {
    final grips = wallPlanType.gripsFor(services)!;
    return grips.drag(doc, h, grips.gripsOf(doc, h)[end], to);
  } finally {
    services.dispose();
  }
}
```

  `room_grips_test.dart` (kit), added after `distToLine`:

```dart
/// The room type's own grips over [doc] at the label aperture [ap] (world
/// mm): its provider over a camera of `kSnapAperturePixels / ap` px per mm,
/// the aperture today's ObjectGrips(labelAperture: () => ap) handed to
/// RoomGrips.
ObjectGripProvider roomGripsAt(DraftDocument doc, double ap) {
  final services = FakePlanServices(
      document: doc,
      catalog: testCatalog(),
      scale: kSnapAperturePixels / ap);
  addTearDown(services.dispose);
  return roomPlanType.gripsFor(services)!;
}

/// The separator type's own grips over [doc] and the services they read,
/// with object snap (F3) [snap]: one services per F3 state, so each reads
/// its own flag and its own RoomInputs (today's ObjectGrips(roomInputs:,
/// objectSnap:), which shared one).
(ObjectGripProvider, FakePlanServices) separatorGripsWith(
    DraftDocument doc, bool snap) {
  final services = FakePlanServices(
      document: doc, catalog: testCatalog(), objectSnap: snap);
  addTearDown(services.dispose);
  return (separatorPlanType.gripsFor(services)!, services);
}
```

  In the cases: GR1 :222-223 and GR6 :630-631 `final objects = ObjectGrips(edgeAperture: () => null, labelAperture: () => ap);` → `final objects = roomGripsAt(doc, ap);`. GR5 :486-490 (`final inputs = RoomInputs(doc); addTearDown(inputs.dispose); var snap = true; final objects = ObjectGrips(...);`) →

```dart
      var snap = true;
      final byF3 = {
        for (final v in [true, false]) v: separatorGripsWith(doc, v),
      };
      ObjectGripProvider objectsNow() => byF3[snap]!.$1;
```

  every later `objects.` in GR5 → `objectsNow().`, and :530 `inputs.invalidate();` (today's one shared `RoomInputs`, invalidated after the undo so the next drag in the same task never reads the undone separator) → both services' inputs:

```dart
          for (final (_, s) in byF3.values) {
            roomInputsOf(s).invalidate();
          }
```

- [ ] **Step 3b: `separator_tool_test` ST4 (carried from Task 17).** Append to `packages/jet_cad_2d_kit_architecture/test/separator/separator_tool_test.dart` (Task 17's), inside `main` after ST3, today's ST4 (`packages/jet_cad_floor_plan/test/separator_tool_test.dart:351-380`), **assertions unchanged**, and before `main` today's `rooms` helper (`:87-88`) as `List<Handle> rooms(DraftDocument doc) => testCatalog().objectsOf<RoomParams>(doc);` (the engine's live rule over the kit tests' catalog, as Task 17 wrote `separators`). `buildPlan`, `boxWalls`, `attachPage`, `addRoom` (this task's Step 2), `labelStrings`, `faceAt` and `driftOf` are `room_fixture.dart`'s; `separatorRig` and `draw` are the file's own (Task 17). The file's `room_trace.dart` import's `show` gains `Traced`; `RoomParams` comes from the kit barrel it already imports. Non-ASCII: the two `×` and the `m²` literals, checked with `grep -n "[^ -~]"` against the source lines.

- [ ] **Step 4: The failing kit tests (new).** Create `test/room/room_plan_test.dart`:

```dart
// Spec 3a C3.5, C1.1, C1.7: the room as a kit type. Its fields are its
// name (a TextProperty, trimmed, an empty name refused, gated by reshape)
// and its area as drawn (a TextDisplay over the object: the area label's
// string, '—' without one, read once per document state); its colour is its
// palette name; its grips are today's label grip at the snap aperture of
// the camera's scale, and a room is not moved or turned.
//
// The plan: the two-room box with a separator face to face at x 6,250.5,
// at the corpus far origin turned 23°, every wall and the separator in its
// own rotated, translated group; room A ('Kitchen') in a group of its own
// turned 0.61 rad, room B ('Room 2') at the identity. Area strings are
// today's hand arithmetic (room_panel_test.dart RN1, RN6).
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_architecture/src/room/room_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/room_fixture.dart';

typedef Rooms = ({Plan plan, Handle a, Handle b});

/// A: x 100..2,950, 2,850 × 3,800 = 10,830,000 mm² ("10.83 m²"); B: x
/// 3,050..6,250.5, 3,200.5 × 3,800 = 12,161,900 mm² ("12.16 m²").
Rooms rooms() {
  final plan = buildPlan(twoRoomWalls,
      seps: const [(6250.5, 100, 6250.5, 3900)], place: corpusGroups);
  attachPage(plan.doc, PageComponent());
  final at = plan.at(1400, 1900);
  final g =
      Transform2.translation(at.x, at.y).multiply(Transform2.rotation(0.61));
  final a = addRoom(plan.doc, plan.at(1500.25, 2000.5), 'Kitchen', at: g);
  final b = addRoom(plan.doc, plan.at(4700.75, 1900.25), 'Room 2');
  plan.doc.commands.clearHistory();
  return (plan: plan, a: a, b: b);
}

/// The kit's own words in English (R-P4: fields are bound with words; the
/// room's read none).
final KitWords words =
    KitNamesWords(architectureKit.names, () => const Locale('en'));

PropertyField fieldOf(DraftDocument doc, Handle room, String id) => roomPlanType
    .fieldsOf(doc, room, words)
    .firstWhere((f) => f.spec.id == id);

void main() {
  test(
      'RM-fields a room\'s fields are its name and its area as drawn, under '
      'its property words; its section is titled by its type word', () {
    final f = rooms();
    final doc = f.plan.doc;
    expect(roomPlanType.id, ArchitectureTypes.room);
    expect(architectureKit.types, contains(roomPlanType));
    final fields = roomPlanType.fieldsOf(doc, f.a, words);
    expect([for (final x in fields) x.wordId], [
      'property:architecture.room.name',
      'property:architecture.room.area',
    ]);
    expect([for (final x in fields) x.value], ['Kitchen', '10.83 m²']);
    expect(fields[0].spec.gate, PlanGate.reshape);
    expect(fields[0].commit, isNotNull);
    expect(fields[1].commit, isNull, reason: 'a display');
    expect(fields[1].visible, isTrue);
    expect(roomPlanType.fieldsOf(doc, f.b, words)[1].value, '12.16 m²');
    expect(roomPlanType.titleWordOf(doc, f.a), 'type:architecture.room');
    expect(roomPlanType.exported, isTrue);
  });

  test(
      'RM-name the name is trimmed, inner spaces kept; an empty name is '
      'refused (M-RM-1, M-RM-2)', () {
    final f = rooms();
    final doc = f.plan.doc;
    doc.commands.execute(roomPlanType.commitField(
        doc, f.a, fieldOf(doc, f.a, 'name'), '  Snug  room \t', words));
    expect(doc.components.get<RoomParams>(f.a)!.name, 'Snug  room');
    expect(labelStrings(doc, f.a), ['Snug  room', '10.83 m²']);
    for (final empty in ['', '   ', '\t ']) {
      expect(
          () => roomPlanType.commitField(
              doc, f.a, fieldOf(doc, f.a, 'name'), empty, words),
          throwsArgumentError,
          reason: '"$empty"');
    }
    expect(doc.commands.undoDepth, 1);
  });

  test(
      'RM-area the Area line is the area label as drawn, read once per '
      'document state, "—" for a room with no labels (M-RM-3, M-RM-4, '
      'M-RM-5, M-RM-6)', () {
    final f = rooms();
    final doc = f.plan.doc;
    final reads = debugRoomAreaReads;
    expect(fieldOf(doc, f.b, 'area').value, '12.16 m²');
    expect(fieldOf(doc, f.b, 'area').value, '12.16 m²');
    expect(debugRoomAreaReads - reads, 1, reason: 'one read at one state');

    // The page turns to ft-in at 1:100, one command: the line follows.
    // 12,161,900 / 92,903.04 ≈ 130.9096; 10,830,000 / 92,903.04 ≈ 116.5731.
    doc.commands.execute(SetComponentCommand<PageComponent>(
        doc.rootHandle,
        pageOf(doc).copyWith(
            displayUnit: DisplayUnit.feetInches, scaleDenominator: 100)));
    expect(fieldOf(doc, f.b, 'area').value, '130.91 ft²');
    expect(fieldOf(doc, f.b, 'area').value, textOf(doc, labelsOf(doc, f.b)[1]));
    expect(fieldOf(doc, f.a, 'area').value, '116.57 ft²');
    doc.commands.undo();
    expect(fieldOf(doc, f.a, 'area').value, '10.83 m²');

    // A file's room that never regenerated has no label: the line reads
    // '—' and is shown.
    late Handle store;
    final loaded = reloadWithPage(staleFile(doc, (bare) {
      store = addRoom(bare, f.plan.at(7000.25, 2000.5), 'Store');
    }));
    expect(kids(loaded, store), isEmpty, reason: 'premise: no children');
    final line = roomPlanType.fieldsOf(loaded, store, words)[1];
    expect(line.value, '—');
    expect(line.visible, isTrue);
  });

  test(
      'RM-colour the colour target is the room\'s palette name; recolouring '
      'is one SetComponentCommand that keeps the rest (M-RM-7)', () {
    final f = rooms();
    final doc = f.plan.doc;
    expect(roomPlanType.hasColour, isTrue);
    expect(roomPlanType.colourOf(doc, f.a), isNull);
    doc.commands.execute(roomPlanType.recolour(doc, f.a, 'teal')!);
    expect(doc.components.get<RoomParams>(f.a)!.color, 'teal');
    expect(roomPlanType.colourOf(doc, f.a), 'teal');
    expect(roomPlanType.recolour(doc, f.a, 'teal'), isNull,
        reason: 'already teal');
    doc.commands.execute(roomPlanType.recolour(doc, f.a, null)!);
    final p = doc.components.get<RoomParams>(f.a)!;
    expect((p.color, p.name), (null, 'Kitchen'));
    expect(doc.commands.undoDepth, 2);
  });

  test(
      'RM-grips the label grip returns to auto within the snap aperture at '
      'the camera\'s scale; a room is not movable (M-RM-8, M-RM-9)', () {
    final f = rooms();
    final doc = f.plan.doc;
    // 0.25 px per mm: the aperture is kSnapAperturePixels / 0.25 = 40 mm.
    final services = FakePlanServices(
        document: doc, catalog: testCatalog(), scale: 0.25);
    addTearDown(services.dispose);
    final grips = roomPlanType.gripsFor(services)!;
    expect(grips.movable(doc, f.b), isFalse);
    // B's label is auto: its grip is its pole.
    final g = grips.gripsOf(doc, f.b).single;
    final pole = Vector2(g.x, g.y);
    expect(grips.drag(doc, f.b, g, pole + Vector2(0.6 * 36, -0.8 * 36)),
        isNull,
        reason: '36 mm from the pole: auto stays auto');
    expect(grips.drag(doc, f.b, g, pole + Vector2(0.6 * 44, -0.8 * 44)),
        isA<SetComponentCommand<RoomParams>>(),
        reason: '44 mm from the pole: an offset');
  });
}
```

- [ ] **Step 5: Run the kit's tests, expecting failure.** `cd packages/jet_cad_2d_kit_architecture && flutter test test/room`. Expected: compile errors, `Target of URI doesn't exist` for `src/room/room.dart`, `src/room/room_plan.dart` (and `Undefined name 'roomPlanType'`). Quote them.

- [ ] **Step 6: The room.** Create `lib/src/room/room.dart`: **copy `packages/jet_cad_floor_plan/lib/src/parametric/room.dart` lines 1-470 unchanged**, with:
  - Lines 15-16 (`import '../colors/plan_color.dart';`, `import 'room_inputs.dart' show placeSourceInView;`) become:

```dart
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show PlanSwatch, planSwatchNamed;

import '../ids.dart';
import 'room_inputs.dart' show placeSourceInView;
```

    (the `package:` import goes with the other `package:` imports, before `package:meta`.)
  - Line 39: `static const String componentTypeId = 'floor_planner.room';` → `static const String componentTypeId = ArchitectureTypes.room;`.
  - Lines 49-51: `FloorPlanColor? get colorValue => floorPlanColorNamed(color);` → `PlanSwatch? get colorValue => planSwatchNamed(color);` (its doc unchanged; `hue.rgb` at :326 reads `PlanSwatch.rgb`, today's values, `swatch.dart:16-28`).
  - After line 7 of the header: `// Ported from jet_cad_floor_plan's parametric/room.dart (spec 3a C3.5): its id architecture.room, its palette the contract's PlanSwatch.`

  Create `lib/src/room/room_grips.dart`: **copy `.../parametric/room_grips.dart` lines 1-176 unchanged** (`import 'room.dart';` resolves in the same directory), with a first line `// Ported from jet_cad_floor_plan's parametric/room_grips.dart unchanged (spec 3a C3.5).`

- [ ] **Step 7: The room type.** Create `lib/src/room/room_plan.dart`:

```dart
// The room as the kit's type (spec 3a C3.5): today's RoomType, its label
// grip, and the Selection panel's Room section (jet_cad_floor_plan's
// selection_panel.dart:1373-1386) as property specs: the name, trimmed and
// never empty, and the area as drawn, a TextDisplay over the object (spec
// 3a C1.1). The colour row's room half (colors/color_picker.dart:17-57) is
// the type's colour target. Task 19 adds the Room tool.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:meta/meta.dart' show visibleForTesting;

import '../ids.dart';
import 'room.dart';
import 'room_grips.dart';

/// The room type (spec 3a C3.5).
///
/// - **Name**: a [TextProperty] committed trimmed; a name empty once
///   trimmed is refused (today's R-24: a nameless room could not be told
///   apart), gated by `reshape` (an object's own field, today's S-10).
/// - **Area**: [roomAreaText], read-only.
/// - **Colour**: the room's palette name (plan colours spec PC-3).
/// - **Grips**: the label grip; a drop within the snap aperture of the
///   pole, at the camera's scale whatever F3 says, returns the label to
///   automatic (Ruling 10-17). A room is not moved or turned (R-22).
final PlanType<RoomParams> roomPlanType = PlanType<RoomParams>(
  id: ArchitectureTypes.room,
  fromJson: RoomParams.fromJson,
  parametric: const RoomType(),
  grips: (s) =>
      RoomGrips(aperture: () => kSnapAperturePixels / s.camera.value.scale),
  properties: [
    TextProperty<RoomParams>(
      id: 'name',
      read: (p) => p.name,
      write: (p, v) {
        final name = v.trim();
        if (name.isEmpty) {
          throw ArgumentError.value(v, 'name', 'is empty once trimmed');
        }
        return p.copyWith(name: name);
      },
      gate: PlanGate.reshape,
    ),
    TextDisplay<RoomParams>(id: 'area', read: (p, o) => roomAreaText(o)),
  ],
  colour: ColourTarget<RoomParams>(
    read: (p) => p.color,
    write: (p, swatch) => p.copyWith(color: swatch),
  ),
);

/// How many times [roomAreaText] read the document (not its memo). Never
/// reset by the library.
@visibleForTesting
int debugRoomAreaReads = 0;

/// The last Area line read per document: the room, the document's state
/// and the string.
final Expando<({Handle room, int state, String text})> _areaMemo =
    Expando('roomAreaText');

/// The Area line of [object], a room (spec 10 D21, R-25; today's `_areaOf`,
/// selection_panel.dart:826-844): its area label's stored string, exactly
/// as drawn, or '—' when it has none (a file's room with no children,
/// today's panel line). The labels are the room's TEXT children, the name
/// then the area in handle order (D9, D18), so the area is the second, in
/// handle order, never in slot order.
///
/// Reads the document once per room shown and per document state
/// (`commands.stateId`): today's panel dropped its memo on every command
/// change, and the state moves on exactly those.
String roomAreaText(PlanObject object) {
  final doc = object.document;
  final room = object.handle;
  final state = doc.commands.stateId;
  final memo = _areaMemo[doc];
  if (memo != null && memo.room == room && memo.state == state) {
    return memo.text;
  }
  debugRoomAreaReads++;
  final entities = doc.entities;
  final labels = <(Handle, int)>[
    for (final slot in entities.liveSlots)
      if (entities.ownerAt(slot) == room &&
          entities.kindAt(slot) == EntityKind.text)
        (entities.handleAt(slot), slot),
  ]..sort((a, b) => a.$1.value.compareTo(b.$1.value));
  final text = labels.length < 2 ? '—' : entities.textAt(labels[1].$2);
  _areaMemo[doc] = (room: room, state: state, text: text);
  return text;
}
```

  Then:
  - `lib/src/kit.dart`: `roomPlanType` joins `types` after `separatorPlanType` (today's order, `parametric/catalog.dart:28-39`: box, wall, opening, separator, room, dimension), with `import 'room/room_plan.dart';`.
  - The barrel: `export 'src/room/room.dart' show RoomParams;`.
  - `lib/src/type_naming.dart` (Task 14, ruling R-P19): append the room's registration to `_naming`'s cascade after the separator's (today's order, `catalog.dart:36-37`), with `import 'room/room.dart';`:

```dart
  ..register<RoomParams>(
      RoomParams.componentTypeId, RoomParams.fromJson, const RoomType())
```
  - Check the non-ASCII literal: `grep -n "'—'" packages/jet_cad_2d_kit_architecture/lib/src/room/room_plan.dart` shows the em dash U+2014 (as `selection_panel.dart:1384`).

- [ ] **Step 8: Run the kit's tests.** `cd packages/jet_cad_2d_kit_architecture && dart format . && flutter test`. Expected: `All tests passed!` (RK2 prints its sweep: quote its lines, they are not asserted). Check the ported files' `m²`/`ft²` counts against their sources with `grep -c`, as in Task 16.

- [ ] **Step 9: The integration test support.** Create `packages/jet_cad_2d_integration/test/support/room_plans.dart`. The plan model is **copied from `packages/jet_cad_floor_plan/test/support/room_fixture.dart`**: lines 26-96 (`W`, `S`, `O`, `Placement`, `origin`, `corpus`, `corpusGroups`, `km1000`, `km1000Axis`, `km1000Groups`, `placements`, `_groupFor`) unchanged; lines 356-413 (`sampleWalls`, `sampleOpenings`, `sampleSeparator`, `sampleColumn`, `sampleSeeds`) unchanged; lines 457-474 (`twoRoomWalls`, `boxWalls`) unchanged; lines 196-210 (`recordOf`, `worldPoints`), 581-630 (`labelsOf`, `textOf`, `worldTintOf`, `pageOf`, `anchorOf`), 660-667 (`deleteObject`), 699-705 (`labelStrings`, `kindsOf`) unchanged. `kids`, `kindOf`, `payloadOf`, `enc` and `driftOf` are Task 12's integration `wall_fixture.dart` (imported and re-exported below), and `pumpEditor`, `globalAt`, `press`, `status`, `kitCatalog` the rig's (R-P14): none is copied. The rest is new:

```dart
// Room plans for the integration tests (spec 3a C6): the kit's room
// fixture's plans (jet_cad_floor_plan/test/support/room_fixture.dart, whose
// plan model and helpers are copied here), built in code by a PlanBuild
// over the architecture kit (spec 3a C1.9). The plan library makes the
// document, prepares it, installs its own system, runs the build and clears
// the history: the controller opens clean, as today's shell fixtures made
// it by hand. Each wall, separator, opening and room is one command, in the
// fixture's order, so the handles are the fixture's.
//
// The editor is driven through the public API only: PlanEditor in
// planEditorApp, the controller's camera, selection and worldToGlobal.
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'editor_rig.dart';
import 'wall_fixture.dart';

export 'editor_rig.dart' show globalAt, kitCatalog, press, pumpEditor, status;
export 'wall_fixture.dart' show driftOf, enc, kids, kindOf, payloadOf;

// ... the copied plan model and helpers (above) ...

/// A room the build adds at plan point ([x], [y]), named [name], with label
/// offset [label] (null: auto) and, with [at], in a group of that world
/// transform (only a file makes one), its seed taken back through it
/// (today's `addRoom`, room_fixture.dart:561-579).
typedef R = ({
  double x,
  double y,
  String name,
  (double, double)? label,
  Transform2? at,
});

/// A plan built by [roomPlan] and its controller.
final class RoomPlan {
  RoomPlan._(this.c, this.place, this.walls, this.seps, this.openings,
      this.rooms);

  final PlanController c;
  final Placement place;

  /// The handles the build allocated, in the order given.
  final List<Handle> walls, seps, openings, rooms;

  DraftDocument get doc => c.document;
  Vector2 at(double x, double y) => place.at(x, y);
}

/// A controller over the architecture kit whose plan is [walls], [seps],
/// [openings] (hosted by the walls they index) and [rooms], at [place],
/// each one command, built in that order (today's `buildPlan`, then
/// `attachPage` and `addRoom`), with [page] on the root when given.
/// Disposed at tear-down.
RoomPlan roomPlan(List<W> walls,
    {List<S> seps = const [],
    List<O> openings = const [],
    List<R> rooms = const [],
    Placement place = origin,
    PageComponent? page}) {
  final wh = <Handle>[], sh = <Handle>[], oh = <Handle>[], rh = <Handle>[];
  void group(DraftDocument doc, Handle h, Transform2 g, DraftCommand set,
          String label) =>
      doc.commands.execute(CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: h,
            parent: doc.rootHandle,
            transform: g,
            children: const [])),
        set,
      ], label: label));
  final c = PlanController(
    kits: [architectureKit],
    build: (doc, _) {
      var k = 0;
      for (final w in walls) {
        final h = doc.handleSeed.next();
        final g = place.groups ? _groupFor(place, k++) : Transform2.identity();
        final inv = g.invert();
        final s = inv.transformPoint(place.at(w.sx, w.sy));
        final e = inv.transformPoint(place.at(w.ex, w.ey));
        group(doc, h, g,
            SetComponentCommand<WallParams>(
                h, WallParams(s.x, s.y, e.x, e.y, w.t, w.j)),
            'Add wall');
        wh.add(h);
      }
      for (final (sx, sy, ex, ey) in seps) {
        final h = doc.handleSeed.next();
        final g = place.groups ? _groupFor(place, k++) : Transform2.identity();
        final inv = g.invert();
        final s = inv.transformPoint(place.at(sx, sy));
        final e = inv.transformPoint(place.at(ex, ey));
        group(doc, h, g,
            SetComponentCommand<SeparatorParams>(
                h, SeparatorParams(s.x, s.y, e.x, e.y)),
            'Add separator');
        sh.add(h);
      }
      for (final (i, position, width, kind, swing) in openings) {
        final h = doc.handleSeed.next();
        group(
            doc,
            h,
            Transform2.identity(),
            SetComponentCommand<OpeningParams>(
                h, OpeningParams(wh[i], position, width, kind, swing: swing)),
            'Add opening');
        oh.add(h);
      }
      if (page != null) {
        doc.commands
            .execute(SetComponentCommand<PageComponent>(doc.rootHandle, page));
      }
      for (final r in rooms) {
        final h = doc.handleSeed.next();
        final g = r.at ?? Transform2.identity();
        final seed = place.at(r.x, r.y);
        final s = r.at == null ? seed : g.invert().transformPoint(seed);
        group(doc, h, g,
            SetComponentCommand<RoomParams>(
                h, RoomParams(s.x, s.y, r.name, label: r.label)),
            'Add room');
        rh.add(h);
      }
    },
  );
  addTearDown(c.dispose);
  return RoomPlan._(c, place, wh, sh, oh, rh);
}

/// Every live room of [doc], ascending.
List<Handle> rooms(DraftDocument doc) =>
    doc.components.withComponent<RoomParams>().toList();

String nameOf(DraftDocument doc, Handle room) =>
    doc.components.get<RoomParams>(room)!.name;

/// The rig's [pumpEditor] with a rotated, non-reflecting camera of [scale]
/// px per mm, turned [turn] rad, centred on [centre] (today's shell tests'
/// `pumpShell`, room_grips_test.dart:145-162).
Future<void> pumpAt(WidgetTester tester, PlanController c, Vector2 centre,
        {double scale = 0.15, double turn = 0.35}) =>
    pumpEditor(tester, c, centre: centre, scale: scale, turn: turn);

Future<void> clickAt(WidgetTester tester, PlanController c, Vector2 p) async {
  await tester.tapAt(globalAt(tester, c, p));
  await tester.pump();
}

/// A mouse drag from world [from] to world [to], past the slop at once
/// (today's `dragWorld`, room_grips_test.dart:176-188).
Future<void> dragWorld(
    WidgetTester tester, PlanController c, Vector2 from, Vector2 to) async {
  final a = globalAt(tester, c, from), b = globalAt(tester, c, to);
  final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
  await gesture.down(a);
  await gesture.moveTo(a + const Offset(12, 0));
  await gesture.moveTo(b);
  await gesture.up();
  await gesture.removePointer();
  await tester.pump();
  await tester.pump();
}

Future<void> undoKey(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();
  await tester.pump();
}

Future<void> toggleF3(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.f3);
  await tester.pump();
}

String osnap(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('osnap-text'))).data!;

/// The design's selection replaced by [hs], as roots.
Future<void> select(
    WidgetTester tester, PlanController c, List<Handle> hs) async {
  c.activeSelection.replace([for (final h in hs) SelectionKey.root(h)]);
  await tester.pump();
}
```

  (`math` is used by the copied `Placement.m` and `_groupFor`; `enc` is the copied `DraftDocumentCodec.encodeToString`.)

- [ ] **Step 10: The failing integration tests (ported).** Each destination is under `packages/jet_cad_2d_integration/test/room/`; each gains `// Ported from jet_cad_floor_plan/test/<file> (spec 3a C6, C7); assertions unchanged.`, imports `package:jet_cad_2d_integration/jet_cad_2d_integration.dart`, `package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart`, `package:jet_cad_2d_plan/jet_cad_2d_plan.dart`, the engine, the Flutter layer's names it uses, and `../support/room_plans.dart`. The common mapping, applied everywhere (C7 class 3 and fixture changes):
  - `PlannerView view` / `view.document` → `c` / `c.document`; `view.selection` → `c.activeSelection`; `view.camera` → `c.camera`; `select(tester, view, hs)` → `select(tester, c, hs)`; `screenOf`/`globalOf(tester, view, p)` → `globalAt(tester, c, p)` (the rig's); `tapWorld(tester, view, p)` → `clickAt(tester, c, p)`; `dragWorld(tester, view, a, b)` → `dragWorld(tester, c, a, b)`.
  - The finders of "Integration finders" above.
  - `pumpShell(tester, doc)` → `pumpEditor(tester, p.c)`; `pumpShell(tester, f, centre)` → `pumpAt(tester, f.p.c, centre)`.

  **`room_grips_test.dart`** (integration; GR1 (shell), GR2, GR3, GR4, GR5 (shell)). The file starts with `// ignore_for_file: invalid_use_of_internal_member` (see "Interface problem" 2): its cases read the canvas's grip cache. Its fixture is today's `gripPlan` (`:59-93`) over `roomPlan`:

```dart
/// Today's gripPlan (room_grips_test.dart:59-93) with `shell: true`:
/// [twoRoomWalls] and [sep] at [place], a 1:50 page in metres with no grid
/// snap, the Kitchen (its label offset [kitchenLabel]) and B ('Room 2',
/// auto), built and clean.
({RoomPlan p, Handle kitchen, Handle b, Handle sep, Handle part}) gripPlan(
    Placement place) {
  final p = roomPlan(twoRoomWalls,
      seps: const [sep],
      place: place,
      page: PageComponent(snapToGrid: false),
      rooms: const [
        (x: 1500.25, y: 2000.5, name: 'Kitchen', label: kitchenLabel, at: null),
        (x: 4700.75, y: 1900.25, name: 'Room 2', label: null, at: null),
      ]);
  expect(labelStrings(p.doc, p.rooms[0]), ['Kitchen', '10.83 m²'],
      reason: 'premise, $place');
  expect(labelStrings(p.doc, p.rooms[1]), ['Room 2', '12.16 m²'],
      reason: 'premise, $place');
  return (
    p: p,
    kitchen: p.rooms[0],
    b: p.rooms[1],
    sep: p.seps.single,
    part: p.walls[4],
  );
}

/// The shown object grips of [h] (the canvas's grip cache).
List<Grip> objectGripsOf(PlanController c, Handle h) => [
      for (final r in c.grips.grips)
        if (r.object && r.key == SelectionKey.root(h)) r.grip,
    ];
```

  Copied with it: `kitchenLabel`, `sep`, `roomOf`, `sepOf`, `poleLocal`, `labelFor`, `distToLine`, `at` (`:39-44, :95-100, :111-131, :211`). Case adaptations beyond the mapping: `f.plan` → `f.p`; `view.grips!` → `c.grips` (GR3's `hitTest`, GR4's `box`, `rotatable`, GR5 (shell)'s `rotatable`); GR4's last trace (`:470-471`, `faceAt(doc, ...) as Traced` and `kitchen.area`) reads the kit's tracer, which is under `lib/src` and not importable here: the area is read from the room's own drawn tint instead (see "Interface problem" 3):

```dart
      // The Kitchen's face, from its tint (D9 step 1: the face's ring; no
      // hole here): its shoelace area.
      final tint = worldTintOf(doc, f.kitchen);
      var twice = 0.0;
      for (var i = 0; i < tint.length; i++) {
        final a = tint[i] - tint[0], b = tint[(i + 1) % tint.length] - tint[0];
        twice += a.x * b.y - a.y * b.x;
      }
      expect(twice.abs() / 2, closeTo((2850 + delta) * 3800, 1e-2));
```

  **`room_panel_test.dart`** (integration; the fixture case, RN1-RN6). Starts with `// ignore_for_file: invalid_use_of_internal_member` (RN3 reads the Fill toggle). Today's `roomsPlan` (`:105-124`) becomes:

```dart
/// Today's roomsPlan (room_panel_test.dart:105-124): [twoRoomWalls] and a
/// separator face to face at x 6,250.5, at [corpusGroups], the app's
/// opening page, A ('Kitchen') in a rotated group of its own, B ('Room 2')
/// at the identity; built and clean.
({RoomPlan p, DraftDocument doc, Handle a, Handle b, Handle sep, Handle w})
    roomsPlan() {
  const place = corpusGroups;
  final at = place.at(1400, 1900);
  final g =
      Transform2.translation(at.x, at.y).multiply(Transform2.rotation(0.61));
  final p = roomPlan(twoRoomWalls,
      seps: const [(6250.5, 100, 6250.5, 3900)],
      place: place,
      page: PageComponent(),
      rooms: [
        (x: 1500.25, y: 2000.5, name: 'Kitchen', label: null, at: g),
        (x: 4700.75, y: 1900.25, name: 'Room 2', label: null, at: null),
      ]);
  return (
    p: p,
    doc: p.doc,
    a: p.rooms[0],
    b: p.rooms[1],
    sep: p.seps.single,
    w: p.walls[4],
  );
}
```

  Case adaptations beyond the mapping:
  - RN3 (`:234-280`): today's letters come from `kShellLetterKeys` and `ToolPalette.entries` (`:244-248`). Neither is public in the plan library (its guard is built from the letters in use, `plan_shortcut_guard.dart:1-4`), so the set is rebuilt from what the plan binds: the generic tools' letters (V L P R C A T, `tool_letters.dart:1-3`), the kit's tools' letters and F, plus today's 16-letter list copied as a test-local constant (a fixture; `jet_cad_floor_plan/lib/src/shortcut_guard.dart:8-25`):

```dart
    // Today's kShellLetterKeys (jet_cad_floor_plan/lib/src/shortcut_guard.dart:
    // 8-25), copied: the 16 letters the shell bound. M and I are not bound
    // until Tasks 19 and 22; they must type into the field all the same.
    const kShellLetterKeys = [
      LogicalKeyboardKey.keyV, LogicalKeyboardKey.keyL, LogicalKeyboardKey.keyP,
      LogicalKeyboardKey.keyR, LogicalKeyboardKey.keyB, LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyD, LogicalKeyboardKey.keyN, LogicalKeyboardKey.keyG,
      LogicalKeyboardKey.keyM, LogicalKeyboardKey.keyS, LogicalKeyboardKey.keyI,
      LogicalKeyboardKey.keyC, LogicalKeyboardKey.keyA, LogicalKeyboardKey.keyT,
      LogicalKeyboardKey.keyF,
    ];
    LogicalKeyboardKey keyOf(String l) => LogicalKeyboardKey.findKeyByKeyId(
        LogicalKeyboardKey.keyA.keyId + l.codeUnitAt(0) - 0x41)!;
    final letters = <LogicalKeyboardKey>{
      ...kShellLetterKeys,
      for (final l in 'VLPRCAT'.split('')) keyOf(l),
      for (final t in architectureKit.tools)
        if (t.letter case final l?) keyOf(l),
      LogicalKeyboardKey.keyF,
    };
```

    so `:249-252`'s assertions stand unchanged (`containsAll([keyM, keyS])`; `hasLength(kShellLetterKeys.length)`, now the copied constant's 16: a letter the plan binds that today's shell did not would make it 17, as a letter missing from today's guard did). The earlier draft (no copied list, `hasLength(16)`) could not pass here: before Tasks 19 and 22 the kit binds no M and no I, so its set has 14 letters and no M. `palette.fill.value` (`:273`) → `r.p.c.fill.value`.
  - RN5 (refused edit, `:316-401`): the edited document comes back through the plan's load: `final j = jsonDecode(src.p.c.save()) as Map<String, Object?>;` replaces `DraftDocumentCodec.encode(src.doc)` (`:320`; the plan's text is the engine's JSON with the manifest on its root, `plan_file.dart:1-4`), the entity edit (`:325-330`) is unchanged, and `:331-336`'s decode becomes `final c = architectureController(json: jsonEncode(j)); addTearDown(c.dispose); final doc = c.document;`, then `pumpEditor(tester, c)`.
  - Every `doc.commands.permissions = ...` stays on the engine's document (`c.document`).

  **`room_color_test.dart`** (integration; RC8). Its fixture is today's `fixture()` (`room_color_test.dart:75-88`) over `roomPlan` (A 'Kitchen' at `g`, B 'Room 2'; `page: PageComponent()`), and `recolor` (`:52-54`) is copied. RC8's export (`:418-438`) becomes the plan's PNG exporter:

```dart
    const png96 = PlanExportChoice(dpi: PlanExportDpi.d96);
    Future<({int w, int h, Uint8List rgba})> export() async =>
        (await tester.runAsync(() async {
          final out = await f.p.c.export('plan.png', png96);
          final codec = await ui.instantiateImageCodec(out!.bytes);
          final image = (await codec.getNextFrame()).image;
          codec.dispose();
          try {
            final data =
                (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
            return (
              w: image.width,
              h: image.height,
              rgba: data.buffer.asUint8List(),
            );
          } finally {
            image.dispose();
          }
        }))!;
```

    and `attachPage(doc, page)` (`:414`) → `doc.commands.execute(SetComponentCommand<PageComponent>(doc.rootHandle, page));`. The pixel arithmetic (`:440-456`) and every assertion (`:458-490`) are unchanged.

- [ ] **Step 11: Run the integration tests, expecting failure first, then pass.** Before Step 6 lands they fail to compile (`RoomParams` is not exported); after it: `cd packages/jet_cad_2d_integration && dart format . && flutter test --enable-vmservice test/room`. Expected: `All tests passed!`. Check `m²`/`ft²`/`—` counts against the sources with `grep -c`.

- [ ] **Step 12: The gates.** From the repository root:
  - `cd packages/jet_cad_2d_kit_architecture && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0.
  - `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .` — the same.
  - `dart run tool/ci/check_kit_deps.dart` — exit 0.
  - `git status --short` — only this task's files.

- [ ] **Step 13: Commit.**

```bash
git add packages/jet_cad_2d_kit_architecture/lib/jet_cad_2d_kit_architecture.dart packages/jet_cad_2d_kit_architecture/lib/src/kit.dart packages/jet_cad_2d_kit_architecture/lib/src/type_naming.dart packages/jet_cad_2d_kit_architecture/lib/src/room/room.dart packages/jet_cad_2d_kit_architecture/lib/src/room/room_grips.dart packages/jet_cad_2d_kit_architecture/lib/src/room/room_plan.dart packages/jet_cad_2d_kit_architecture/test/support/catalog.dart packages/jet_cad_2d_kit_architecture/test/support/room_fixture.dart packages/jet_cad_2d_kit_architecture/test/room/room_plan_test.dart packages/jet_cad_2d_kit_architecture/test/room/room_object_test.dart packages/jet_cad_2d_kit_architecture/test/room/room_grips_test.dart packages/jet_cad_2d_kit_architecture/test/room/room_color_test.dart packages/jet_cad_2d_kit_architecture/test/room/room_tint_test.dart packages/jet_cad_2d_kit_architecture/test/room/room_diagnostics_test.dart packages/jet_cad_2d_kit_architecture/test/room/room_dissolve_test.dart packages/jet_cad_2d_kit_architecture/test/room/room_follow_test.dart packages/jet_cad_2d_kit_architecture/test/room/room_tie_test.dart packages/jet_cad_2d_kit_architecture/test/room/room_cost_test.dart packages/jet_cad_2d_integration/test/support/room_plans.dart packages/jet_cad_2d_integration/test/room/room_grips_test.dart packages/jet_cad_2d_integration/test/room/room_panel_test.dart packages/jet_cad_2d_integration/test/room/room_color_test.dart packages/jet_cad_2d_kit_architecture/test/separator/separator_tool_test.dart
git commit -m "$(cat <<'EOF'
feat(kit-architecture): the room type, its grips, fields and colour

Ports RoomType and its label grip from jet_cad_floor_plan (spec 3a
C3.5) and declares the room as the kit's PlanType: its name trimmed and
never empty, its area as drawn through a TextDisplay over the object,
read once per document state, its palette colour and its grips at the
camera's snap aperture. The room's kit tests come with it, assertions
unchanged; its grip, panel and export cases run in the integration
package over the plan library's editor.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 14: Mutation check** (committed files only; after each: run the named test, see it red, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0). Kit tests: `cd packages/jet_cad_2d_kit_architecture && flutter test <file>`; integration: `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice <file>`. Quote each red line.
  - M-RM-1 `lib/src/room/room_plan.dart`: `final name = v.trim();` → `final name = v;` → RM-name red (`'  Snug  room \t'` stored).
  - M-RM-2 `room_plan.dart`: delete the `if (name.isEmpty) { throw ... }` block → RM-name red (no `ArgumentError` for `''`, `'   '`, `'\t '`).
  - M-RM-3 `room_plan.dart`: `labels.length < 2 ? '—' :` → `labels.length < 2 ? '' :` → RM-area red (`'—'`).
  - M-RM-4 `room_plan.dart`: `memo.room == room && memo.state == state` → `memo.room == room` → RM-area red (`'12.16 m²'` after the page change).
  - M-RM-5 `room_plan.dart`: delete `_areaMemo[doc] = (room: room, state: state, text: text);` → RM-area red (two reads at one state).
  - M-RM-6 `room_plan.dart`: `labels[1].$2` → `labels[0].$2` → RM-area red (the name, `'Room 2'`), and integration RN6 red.
  - M-RM-7 `room_plan.dart`: `write: (p, swatch) => p.copyWith(color: swatch)` → `write: (p, swatch) => p` → RM-colour red (`recolour` null).
  - M-RM-8 `room_plan.dart`: `kSnapAperturePixels / s.camera.value.scale` → `kSnapAperturePixels` → RM-grips red (36 mm stores an offset), and kit GR2-in-GR6 red.
  - M-RM-9 `lib/src/room/room_grips.dart`: `d.components.get<RoomParams>(group) == null` → `true` → RM-grips red, and integration GR4 red (a body drag moves the room).
  - M-RM-10 (the port) `lib/src/room/room.dart`: `PlanSwatch? get colorValue => planSwatchNamed(color);` → `=> null;` → RC2, RC5 red.
  - M-RM-11 (the port) `room.dart`: `componentTypeId = ArchitectureTypes.room` → `'architecture.rooms'` → RP1 red.
  - M-RM-12 (the wiring) `lib/src/kit.dart`: remove `roomPlanType` from `types` → RM-fields red, and every integration room case red (no room type in the plan: `PlanController` refuses or loads the rooms as foreign).

#### Assumed from earlier tasks

- Task 2: the plan panel's `TextDisplay` row is a `Text` keyed `property-<id>` holding the field's value (as `ValueDisplay`'s row, `plan_property_panel.dart:745-750`), and a `TextDisplay` whose read returns a string is visible.
- Task 5: `PlanController(kits:, build:)` runs `build` after the kits' `prepare` and the system's install, then clears the history (spec C1.9).
- Task 9 (ruling R-P6): the integration package's pubspec lists `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_kit` and `vector_math` besides the plan library and the kit (its tests name `DraftDocument`, `SelectionKey`, `ViewportTransform`, `Vector2`; `depend_on_referenced_packages`); `planEditorApp` builds a `MaterialApp` whose `home` is a `PlanEditor` over the controller, in the given locale, with the property panel shown.
- Task 12: `wallPlanType.gripsFor(services)` is today's `WallGrips` (joined ends follow).
- Task 17: `separatorPlanType.gripsFor(services)` is today's `SeparatorGrips` over `roomInputsOf(services)` and `services.objectSnap`, read at each event.

#### Interface problem

1. **(Resolved by ruling R-P10: Task 26 ports it, its Step 9 item 12.)** **`room_paint_test.dart` (6 cases) runs on today's sample flat.** Every case pumps `PlannerShell` over `startupPlan(FlutterTextMeasurer())` (`room_paint_test.dart:59`: RR1-RR4, SR3, OL4); the integration package gets `sampleFlatController()` in Task 25. Building the sample flat here from the room fixture would change the premises (its bare-floor samples stay 60 mm from every floor-finish line "found from the document itself", `:13-14`, i.e. the sample's furniture fills). **Proposed fix (settled by ruling R-P10: Task 26, whose Step 9 carries the port):** Task 26 ports `room_paint_test` into `packages/jet_cad_2d_integration/test/room/room_paint_test.dart` over `sampleFlatController()`, assertions unchanged; SR3 is Review Focus 1's shell case and pairs with Task 17's SP-dashed-open. OL4 reads `PlannerView.outlines.debugWorldSegmentsOf` (`:557`), which the plan library keeps internal: that line needs the same ruling as item 2.
2. **(Resolved by ruling R-P9: the files start with `// ignore_for_file: invalid_use_of_internal_member`; no assertion is lost.)** **The shell cases read state the plan library keeps `@internal`.** GR1 (shell), GR2, GR3, GR4 and GR5 (shell) read the canvas's grips (`view.grips!.grips`, `hitTest`, `box`, `rotatable`: `room_grips_test.dart:207-209, 412-415, 438-439, 449, 594`), `PlanController.grips` is `@internal` (`jet_cad_2d_plan/lib/src/controller/plan_controller.dart:2114-2115`); RN3 reads the Fill toggle (`:273`), `PlanController.fill` is `@internal` (`:2071-2072`). **This plan writes those files with `// ignore_for_file: invalid_use_of_internal_member`**, the precedent of `apps/restaurant_demo/test/demo_test.dart:7` (a host's tests reaching a controller's `@internal` state), so every assertion is kept. Spec C6 forbids `src/` imports, which this does not do. **Needs the controller's confirmation**; the fallback (no `@internal` read) loses assertions: GR1's grip-at-anchor line becomes a drag from `anchorOf(...)` that moves the label, GR3's two `hitTest` lines become that drag storing nothing, GR4's and GR5's `box`/`rotatable` lines are dropped, RN3's `fill` line is dropped: each a finding for the human (A14).
3. **GR4's trace line uses the kit's tracer** (resolved by ruling R-P1; recorded here as the task's ruling). `faceAt(doc, ...) as Traced` and `.area` (`room_grips_test.dart:470-471`) need `traceRoomAmong`/`RoomInputs`, under the kit's `lib/src`, which the integration package may not import (R-P1). GR4 needs the editor (a drag on `PlanCanvas`), so it stays in the integration package and reaches the face through public behaviour: the area of the room's drawn tint, which D9 step 1 makes the face's ring (Step 10). The asserted value (`closeTo((2850 + Δ) × 3800, 1e-2)`) is unchanged; its instrument is the drawn tint instead of a second trace.

---

