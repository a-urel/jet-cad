### Task 28: The wall attachment end to end, R-16's room lines, the paint-allocation invariant (spec C5, C6, C7; Appendix A D-01's remainder, D-02, D-03, D-04, D-05, D-12, D-13, D-14, D-35, D-36, D-37, D-38; rulings R-P1, R-P3, R-P9)

**Files** (`I = packages/jet_cad_2d_integration`, `K = packages/jet_cad_2d_kit_architecture`):
- Create (kit tests, R-P1: they read kit internals; R-P3's `place_entry.dart` stands for the plan's placer):
  - `K/test/attach/wall_attach_test.dart` (D-01: WA1-WA18, WK0-WK4)
  - `K/test/attach/wall_attach_property_test.dart` (D-01: WP1, WP2)
  - `K/test/furniture/symbol_box_asset_test.dart` (D-13: the 3 asset cases)
  - `K/test/furniture/symbol_end_to_end_test.dart` (D-14: 2), with its test support `K/test/support/select_rig.dart` (today's, copied; Step 3)
- Create (integration test support): `I/test/support/attach_plans.dart` (today's attachment scenes as plan files, the face lines by hand, the provider's answer through the contract), `I/test/support/shot.dart` (a window capture: 2a's `canvas_fixture.dart` pixel helpers, copied), `I/test/support/fill_plan.dart` (the fill fixture with its teal room and R), `I/test/support/zone_plan.dart` (the zone fixture with its room named `7`)
- Modify (integration test support, Task 26's): `I/test/support/units.dart` (`entryOf` keeps `attachTo` and `family`, Step 5), `I/test/support/editor_fixture.dart` (`mountEditor` gains `bool snapping = true`, Step 7)
- Create (integration tests):
  - `I/test/attach/symbol_move_test.dart` (D-01: MV1-MV6, through `plan.select`)
  - `I/test/attach/wall_attach_tool_test.dart` (D-02: the group "the wall attachment (spec 09c D6)", 12 of its 13 cases, through `plan.symbol`; the 13th's premise is impossible, Step 6)
  - `I/test/attach/against_wall_rotate_test.dart` (D-03: 3)
  - `I/test/attach/wall_attach_end_to_end_test.dart` (D-04: WE1)
  - `I/test/attach/symbol_shell_test.dart` (D-04: SS16, SS17)
  - `I/test/attach/editor_tools_review_test.dart` (D-05: the north-wall mirror case, O13a, O13b)
  - `I/test/symbols/symbol_search_test.dart` (D-12: 12, through the gallery)
  - `I/test/service/room_fill_test.dart` (D-35, D-36: TF1's, TF3's and TF7's room lines)
  - `I/test/export/room_export_test.dart` (D-37: EX2's, EX3's, EX5's room lines and the premises' `R`)
  - `I/test/controller/zone_room_test.dart` (D-38: CZ1 over the zone fixture with its room named `7`)
  - `I/test/invariants/paint_allocation_test.dart` (IA-alloc: the plan's paint invariant over the sample flat with the kit loaded)

**Interfaces:**
- Consumes:
  - Shared interfaces: `architectureKit` (its `attachments`, `symbols`, `names`), `ArchitectureTypes`, `ArchitectureTools`, `WallParams`, `Justification`, `RoomParams`, `OpeningParams`, `OpeningKind`, `DimensionParams`, `AttachedEnd`, `FixedEnd`, `buildSampleFlat`; `architectureController`, `sampleFlatController`, `planEditorApp`; `SymbolBox`, `boxOfEntry`, `boxOfDefinition`, `footprintOf`, `placementTransform`, `isOrthonormal` (contract, Task 1); `FakePlanServices` (Task 6); `AttachmentQuery`, `Attachment`, `AttachmentProvider`, `SymbolLibrary`, `SymbolEntry`, `PlanSwatch`, `kUnitLabelTag` (contract).
  - Plan library, public: `PlanController` (`armSymbol`, `symbols`, `symbolsState`, `selectTool`, `activeTool`, `activeSelection`, `permissions`, `export`, `fitToUnits`, `setUnitColour`, `save`, `load`, `undo`, `redo`, `camera`, `document`), `PlanEditor`, `PlanCanvas`, `PlanSymbolGallery`, `PlanPermissions`, `PlanExportChoice`; `@internal` under R-P9: `framingFor`, `pageFlows`.
  - Task 26's integration support (`plans.dart`, `units.dart`, `editor_fixture.dart`, `canvas_rig.dart` with `gripsOf`, `activeTool`, `frameOn`, `globalAt`, `mouseClick`); Task 27's `rooms_plan.dart` is not used.
  - Kit internals (kit tests only): Task 24's `faceRunsOf(doc, wall, LiveTypeOf live, {accept})`, `WallFaces(WallBands bands, LiveTypeOf live, {accept})`, `attachToWall`, `FaceRun`, `FaceSide`, `FaceNeighbour`, `WallAttachment`, `wallFaceProvider`; Task 11's `WallBands`; R-P3's `test/support/place_entry.dart` (`placeEntry`, `copyOfEntry`) and `test/support/wall_attach_fixture.dart` (`farAt`, `attachAngles`, `attachGroup`, `attachScene`, `freeWallScene`, `lScene`, `teeScene`, `crossScene`, and its re-exports of `wall_fixture.dart`'s `liveOf`/`testCatalog()`, R-P13, R-P17).
- Produces: test support only (see "New shared name").

**Appendix A rows closed:**
- D-01's remainder: `wall_attach_test` (23) and `wall_attach_property_test` (2) in the kit (R-P1, R-P3; with Task 24's `wall_faces_test` the row's kit part is whole); `symbol_move_test` (6) in the integration package through `plan.select` (rulings IA-R2, IA-R3).
- D-02: `symbol_place_tool_test.dart:1368-1740`'s group, 12 of its 13 cases ported, "a tool given no wall faces never attaches" not (premise impossible, Step 6) (Appendix A counts 15; the group holds 13 `test(` cases, `:1372-1716`; its neighbours `:1742-1804` are 2a's ported "paper set"), through `plan.symbol` (IA-R4).
- D-03: `host/against_wall_rotate_test` (3).
- D-04: `apps/floor_planner/test/symbols/wall_attach_end_to_end_test.dart` WE1; `symbol_shell_test.dart` SS16, SS17. WE2 not ported (C7: premise impossible under umbrella decision 9).
- D-05: `host/editor_tools_review_test.dart`'s "a symbol against the north wall: M under full, then mirror false" (`:199-231`), O13a (`:413-446`), O13b (`:448-475`).
- D-12: `symbols/symbol_search_test.dart:82-164, 191-267` (12).
- D-13: `symbols/symbol_box_test.dart:321-339, 391-410` (3), kit.
- D-14: `symbols/symbol_end_to_end_test.dart` (2), kit (R-P1: placer, painter, pick, snap, extents, codec and the Flutter layer's `SelectTool`; no plan-library name once the placement is `placeEntry`).
- D-35, D-36, D-37, D-38 (R-16): the room's and its tint's lines of TF1, TF3 (`hasLength(6)` back), TF7, EX2, EX3, EX5 and the premises' `R`, and CZ1 with the zone fixture's room `7` (IA-R6 for how).
- Spec C6's paint-allocation invariant over the sample flat (IA-alloc).

**C7 placement and rulings** (sources under `packages/jet_cad_floor_plan/test/` unless named):

| Source | Cases | Destination | Why |
|---|---|---|---|
| `symbols/wall_attach_test.dart` | 23 | kit | `attachToWall`, `FaceRun`, `WallBands`, `WallFaces`, `boxOfEntry` (R-P1); `placeSymbol` → `placeEntry` (R-P3) |
| `symbols/wall_attach_property_test.dart` | 2 | kit | likewise |
| `symbols/symbol_box_test.dart:321-339, 391-410` | 3 | kit | `boxOfEntry`, `boxOfDefinition` (contract), the kit's asset, `placeEntry` |
| `symbols/symbol_end_to_end_test.dart` | 2 | kit | engine, Flutter layer, the kit's asset, `placeEntry` |
| `symbols/symbol_move_test.dart` | 6 | integration | the plan's move resolver, reached through `plan.select` |
| `symbols/symbol_place_tool_test.dart:1368-1740` | 12 (of 13) | integration | the plan's `plan.symbol`, reached through the canvas |
| `host/against_wall_rotate_test.dart` | 3 | integration | the view |
| apps' `wall_attach_end_to_end_test.dart` WE1, `symbol_shell_test.dart` SS16, SS17 | 3 | integration | the app's widgets → `PlanEditor` |
| `host/editor_tools_review_test.dart` (3 named) | 3 | integration | the view |
| `symbols/symbol_search_test.dart` (12) | 12 | integration | the plan's gallery |
| `service/table_fill_test.dart`, `colors/table_color_export_test.dart`, `host/controller_test.dart` CZ1 (R-16) | room lines | integration | the plan's canvas, exports and camera with the kit's room |

Plan rulings (the controller confirms; each a ledger `Ruling:` line; those marked **human** drop an assertion line and need the human's word, A14):
- **IA-R1 (the provider's answer as the oracle).** Where today's integration-level test computed its expected transform with `attachToWall(runs, box, p, capture, …)` over `faceRunsOf` (kit internals), the port asks the kit's provider through the contract, the road `plan.symbol` and `plan.select` take: `architectureKit.attachments.single(FakePlanServices(document: c.document, catalog: kitCatalog(), scale: s)).attach(AttachmentQuery(...))` with the query 2a pins (AT-8, `jet_cad_2d_plan/test/tools/plan_symbol_tool_test.dart:1385-1423`: the footprint `footprintOf(boxOfEntry(entry))`, the free placement as `current`, the raw pointer, `capture: kAttachPixels / s`, `edgeCapture: kSnapAperturePixels / s`, the mirror, `mayRotate`). `WallAttachment.q` (the face point) is `Attachment.marker`; `want.run` (`same(outside)`) is replaced by the marker lying on that face's line (`plans.dart`'s `faceOf` over the wall's world ends, distance below 1e-6). The values compared do not change. `attachments` is `List<AttachmentProvider Function(PlanServices)>`, public on `PlanKit`.
- **IA-R2 (MV1-MV3, MV5, MV6 through `plan.select`).** Today these called `SymbolMoveResolver.resolveMove(ctx, instance, delta)` and asserted its answer; the plan's `PlanMoveResolver` is internal. Each becomes the same move dragged on the canvas (body press, eight moves, release; F3 as the case needs), its assertion read on the committed instance: MV4 (ported as is) pins that the drop commits the resolver's answer verbatim, so the committed transform is the answer (and a plain move `delta · T` where the answer was null). The values asserted do not change.
- **IA-R3 (human: three MV lines).** Not portable through public behaviour: MV1's marker line (`(back - r.marker).length < 1e-6`, `symbol_move_test.dart:165`: the marker is a painted overlay, no public read; 2a's MR tests pin the marker's computation over the test provider); MV3's "before the library is ready" (`:194-197`: the plan's resolver reads the placed definition's own `SymbolComponent`, never a library, `jet_cad_2d_plan/lib/src/tools/move_resolver.dart:55-60`, so the premise cannot be built: C7's "premise impossible"); MV6's `await Future.delayed(Duration.zero)` premise comment stays, its assertion ported.
- **IA-R4 (D-02 through `plan.symbol`).** Today's group drove `SymbolPlaceTool` with `ToolPointerEvent`s and read its private ghost (`ghostAttachment`, `ghostPlacement`, `ghostAt`, `quarterTurns`, `notifications`, `faces`, `paintOverlay`); the plan's `plan.symbol` is internal. Each case is driven on the canvas (`armSymbol`, mouse hover and click, the keys R, M, Shift+R, F3), with: a ghost's transform read as the placement the next click commits at the same pointer (2a's AT-9 pins that the release uses the ghost's attachment, `plan_symbol_tool_test.dart:1424-1451`); the oracle per IA-R1. **Human:** the lines with no committed counterpart are not ported, each named in Step 9 (the repaint count `rig.notifications`, the marker glyph's paint calls in "the marker is the nearest glyph", `rig.tool.faces` being null): 2a's AT-8 to AT-13 pin them over the test provider, Task 24's provider tests over the real faces.
- **IA-R5 (D-03, D-04, D-05: the view's internals).** `view.grips!` (O13a, O13b premises) → `gripsOf(tester)` (Task 26's IT-R12, public); the SS/WE apps' `viewOf(tester).tools`, `armBySymbolsTab` → the editor's Symbols tab and `activeTool(tester)`; WE1's save round trip → `c.save()` and a second controller's `load`; WE1's hover ghost (`bedAt.hovered`) → **human**, as IA-R4's ghost lines.
- **IA-R6 (R-16 without the plan's internals; human for the table halves).** The 2b ports TF1, TF3, TF7, EX2, EX3, EX5 and the zone fixture drive the plan's internals (`UnitStatusPainter` built by hand with its notifiers, `ServicePaintLayers`, `UnitColour`, `frameUnits`: `jet_cad_2d_plan/test/service/paint/unit_fill_test.dart:339-375`, `test/support/service_paint.dart`), which the integration package cannot import (R-P1), and the plan library's tests may not name a room. Full copies cannot run anywhere; their table halves stay 2b's, unchanged. Task 28 restores the **room's lines** as whole tests in the integration package through public roads: the fixture is the 2b fill fixture plus today's teal room and R (`table_fill_test.dart:185-186, 208-252`), its tables placed and labelled by hand (`units.dart`) and their colours written as the plan file stores them (`"jetcad.unit_colour": {"<handle>": {"color": "<name>"}}`, `unit_components.dart:178-200`); the design canvas's colour layer is read as the `CustomPainter` of the `CustomPaint` keyed `unit-colour-layer` (`plan_canvas.dart:395-399`) and recorded by the source's `FillSpy`; pixels through `PlanEditor`/`PlanCanvas` and `export`. CZ1's framing is read through `framingFor` (`@internal`, R-P9) and compared with a copy of the zone spec's `frameUnits` formula (the oracle, `jet_cad_2d_plan/lib/src/controller/camera_bounds.dart`; copy the function with its doc citing the line). The restored lines are the source's, verbatim; TF3's count is `hasLength(6), reason: 'A, B, C, U, K and R'` (`table_fill_test.dart:587`).

#### Assumed from earlier tasks

Each name is used as written; a different one is used as the earlier task made it, the difference reported.
- Task 23: `test/support/place_entry.dart` with `CompoundCommand placeEntry(DraftDocument doc, SymbolEntry entry, {required Vector2 at, int quarterTurns = 0, bool mirrored = false, Transform2? transform})` and `Handle? copyOfEntry(DraftDocument, SymbolEntry)`; the asset `assets/library/furniture.jetlib` with today's keys under `architecture.` (`architecture.bath.toilet`, `architecture.kitchen.base.600`, `architecture.kitchen.island`, `architecture.bed.double`, `architecture.sofa.three`, …), `armchair` → `architecture.armchair.single`, every version `@1`.
- Task 24 (R-P3): `test/support/wall_attach_fixture.dart` (today's scenes), `liveOf(doc)`, and the readers' signatures above; `WallFaces.attach(doc, box, p, captureWorld, {mirrored, edgeCaptureWorld, ...})` keeps today's name and parameters; the provider's kind `wall-face`.
- Task 11: `WallBands` takes the kit's `LiveTypeOf` (`WallBands(liveOf(doc))`); if it takes none, today's `WallBands()`.
- Task 26: `canvas_rig.dart`'s `gripsOf`; `editor_fixture.dart`'s `mountEditor`, `editorColumnCorner`; `plans.dart`'s `kitCatalog`, `faceOf`, `worldEndsOf`.

- [ ] **Step 1: Precondition.** Tasks 1-27 are committed; the integration and kit gates green (Task 27's Step 10 commands). `grep -n "placeEntry\|copyOfEntry" packages/jet_cad_2d_kit_architecture/test/support/place_entry.dart` and `grep -n "^AttachScene\|^Vector2 farAt\|liveOf" packages/jet_cad_2d_kit_architecture/test/support/wall_attach_fixture.dart` print the names above; `grep -n "attachments:" packages/jet_cad_2d_kit_architecture/lib/src/kit.dart` prints the provider's factory; `grep -n "unit-colour-layer" packages/jet_cad_2d_plan/lib/src/canvas/plan_canvas.dart` prints the colour layer's key. Anything else: stop and report.

- [ ] **Step 2: The kit's wall attachment (D-01).** Each file: the source's header, plus `// Ported to jet_cad_2d_kit_architecture (3a Task 28, rulings R-P1, R-P3): placements through test/support/place_entry.dart; assertions unchanged.`
  1. `K/test/attach/wall_attach_test.dart` from `symbols/wall_attach_test.dart`, all 23 cases:
     - imports: `parametric/wall.dart`, `wall_bands.dart`, `symbol_box.dart`, `symbol_component.dart`, `symbol_library.dart`, `symbol_placer.dart`, `wall_attach.dart` → `package:jet_cad_2d_kit/jet_cad_2d_kit.dart` (`SymbolBox`, `boxOfEntry`, `placementTransform`, `isOrthonormal`, `SymbolComponent`, `SymbolLibrary`, `SymbolEntry`), the kit's `src/wall/wall.dart`, `src/wall/wall_bands.dart`, `src/attach/wall_attach.dart`, `src/attach/wall_faces.dart`; `../support/wall_attach_fixture.dart`, `../support/wall_fixture.dart`, `../support/place_entry.dart`.
     - `library` (`:32-33`): `File('assets/library/furniture.jetlib')` unchanged (the kit's asset, the test runs from the kit's root); `entryOf(key)` unchanged, every key literal gaining `architecture.` (`entryOf('bath.toilet')` → `entryOf('architecture.bath.toilet')`; C7 class 1).
     - `withSymbols` (`:102-105`): `SymbolComponent.register` → `registerKitComponents(doc.components)` (the contract's registration of `SymbolComponent`).
     - `placeToilet` (`:117-121`): `placeSymbol(doc, toilet, at: farAt(0, 0), transform: g)` → `placeEntry(doc, toilet, at: farAt(0, 0), transform: g)`; the instance is `cmd.children.last` as today.
     - every `faceRunsOf(<doc>, <wall>` → `faceRunsOf(<doc>, <wall>, liveOf(<doc>)`; `WallBands()` → `WallBands(liveOf(doc))`; `WallFaces(bands)` → `WallFaces(bands, liveOf(doc))`, `WallFaces(bands, accept: f)` → `WallFaces(bands, liveOf(doc), accept: f)` (R-P3).
     - nothing else changes.
  2. `K/test/attach/wall_attach_property_test.dart` from `symbols/wall_attach_property_test.dart`, WP1 and WP2, with the same adaptations (`placeSymbol` at `:243` → `placeEntry`).
  - Run `cd packages/jet_cad_2d_kit_architecture && flutter test test/attach`: `All tests passed!`.

- [ ] **Step 3: The asset's boxes and the end to end symbol (D-13, D-14), kit.**
  1. `K/test/furniture/symbol_box_asset_test.dart`: `symbols/symbol_box_test.dart:319-339` (the group "library entries"'s first two cases) and `:391-410` ("reads the live leaves"), assertions unchanged:
     - `assetLibrary()` → `SymbolLibrary.decode(File('assets/library/furniture.jetlib').readAsBytesSync())`; `entryIn(lib, key)` → the entry of key `architecture.<key>`; `catalogBoxes` (`symbol_box_test.dart`, the literal map, find it by name) copied with every key gaining `architecture.` and `armchair` → `architecture.armchair.single` (C7 class 1; Task 23's keys); `boxOf(...)` copied.
     - `target()` (the test's document) → `DraftDocument.empty()` with `registerKitComponents(doc.components)`; `placeSymbol(doc, entry, at:, quarterTurns: 3, mirrored: true)` → `placeEntry(...)` with the same arguments; `definitionOf(doc, 'bath.toilet')` copied with the key prefixed.
  2. `K/test/furniture/symbol_end_to_end_test.dart` from `symbols/symbol_end_to_end_test.dart`, both cases:
     - imports: `new_document.dart`, `parametric/catalog.dart`, `symbol_library.dart`, `symbol_placer.dart` → the contract's barrel and `../support/place_entry.dart`; `../support/select_rig.dart` (`jet_cad_floor_plan/test/support/select_rig.dart`, 91 lines, engine and Flutter layer only) copied to `K/test/support/select_rig.dart` unchanged but its imports.
     - `prepareDocument(...)` (the document) → `DraftDocument.empty(measurer: …)` with `PageComponent.register`, `registerKitComponents`, millimetres (today's `prepareDocument` less the DASHED record and the old catalog, which the case does not read); the asset read as in item 1; `bed.double` → `architecture.bed.double`; `placeSymbol` → `placeEntry`.
  - Run `flutter test test/furniture/symbol_box_asset_test.dart test/furniture/symbol_end_to_end_test.dart`: `All tests passed!`.

- [ ] **Step 4: The integration support for the attachment.** Create `I/test/support/attach_plans.dart`:

```dart
// Today's wall-attachment scenes (jet_cad_floor_plan/test/support/
// wall_attach_fixture.dart, plan P-2) as plan files for the integration
// tests (3a Task 28), and the oracle of ruling IA-R1: the kit's own
// wall-face provider asked through the contract, as plan.symbol and
// plan.select ask it.
import 'dart:io';

import 'package:jet_cad_2d/jet_cad_2d.dart'; // kSnapAperturePixels is the engine's (drag_snap.dart:14)
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart'
    show PlanController, PlanSymbol;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'plans.dart';

/// The attach capture in pixels (plan.symbol's `kAttachPixels`,
/// jet_cad_2d_plan/lib/src/tools/plan_symbol_tool.dart, not exported).
const double kAttachPixels = 16;

/// The kit's furniture library, read from its committed asset.
final SymbolLibrary furniture = SymbolLibrary.decode(File(
        '../jet_cad_2d_kit_architecture/assets/library/furniture.jetlib')
    .readAsBytesSync());

/// The library's entry of today's [key] (`bath.toilet`), under the kit.
SymbolEntry furnitureEntry(String key) =>
    furniture.entries.singleWhere((e) => e.key == 'architecture.$key');

/// [c]'s loaded symbol of today's [key].
PlanSymbol armable(PlanController c, String key) =>
    c.symbols.singleWhere((s) => s.component.key == 'architecture.$key');

/// The kit's wall-face provider over [doc] at [scale] px/mm (IA-R1).
AttachmentProvider wallFaces(DraftDocument doc, double scale) {
  final services =
      FakePlanServices(document: doc, catalog: kitCatalog(), scale: scale);
  addTearDown(services.dispose);
  return architectureKit.attachments.single(services);
}

/// The provider's answer for [entry] at the raw [pointer], its free
/// placement [current], at [scale] (the query AT-8 pins).
Attachment? attachOf(DraftDocument doc, SymbolEntry entry, Vector2 pointer,
    Transform2 current, double scale,
    {bool mirrored = false, bool mayRotate = true, Attachment? keep}) {
  final box = boxOfEntry(entry)!;
  return wallFaces(doc, scale).attach(AttachmentQuery(
      footprint: footprintOf(box),
      current: current,
      pointer: pointer,
      capture: kAttachPixels / scale,
      edgeCapture: kSnapAperturePixels / scale,
      mirrored: mirrored,
      mayRotate: mayRotate,
      keep: keep));
}

/// The distance from [p] to the face line of wall [h] on its [left] side
/// (or right), from its stored parameters (IA-R1's face test).
double faceDistance(DraftDocument doc, Handle h, Vector2 p, {required bool left}) {
  final w = doc.components.get<WallParams>(h)!;
  final (l, r) = facesOf(w);
  final ends = worldEndsOf(doc, h);
  final (a, b) = faceOf(ends.s, ends.e, left ? l : r);
  final d = b - a;
  return ((p - a).x * d.y - (p - a).y * d.x).abs() / d.length;
}
```

  then copy `jet_cad_floor_plan/test/support/wall_attach_fixture.dart`'s `attachX`, `attachY`, `farAt`, `attachAngles`, `attachGroup`, `SceneWall` (`:16-44`) unchanged, and write the scenes as plan files:

```dart
/// Today's `attachScene` (wall_attach_fixture.dart:46-63) as a plan file:
/// [walls] each one command in its own [attachGroup], handles ascending.
({String json, List<Handle> walls}) attachPlan(List<SceneWall> walls,
    {bool mirrored = false,
    double scale = 1,
    List<double?> rotations = const [],
    void Function(DraftDocument d)? extra}) {
  late List<Handle> hs;
  final json = planWith((doc) {
    hs = [for (final _ in walls) doc.handleSeed.next()];
    for (final (i, (s, e, t, j)) in walls.indexed) {
      doc.commands.execute(addWall(doc, hs[i], s, e, t, j,
          at: attachGroup(hs[i].value,
              mirrored: mirrored,
              scale: scale,
              rotation: i < rotations.length ? rotations[i] : null)));
    }
    extra?.call(doc);
  });
  return (json: json, walls: hs);
}

/// Today's `freeWallScene` (:65-71): 3600 long, 150 thick, from
/// `farAt(1234.5, 678.25)` along [deg].
({String json, List<Handle> walls}) freeWallPlan(double deg, Justification j,
    {bool mirrored = false, double scale = 1}) {
  final s = farAt(1234.5, 678.25);
  return attachPlan([(s, polar(s, deg, 3600), 150, j)],
      mirrored: mirrored, scale: scale);
}
```

  (`addWall`, `polar`, `facesOf`, `faceOf`, `worldEndsOf`, `kitCatalog` are `plans.dart`'s. The group transforms follow the plan's handles, which start elsewhere than today's `wallDoc` handles: every wall stays in a turned, translated group, P-2's point; the cases' expectations are along the faces, in world.)

- [ ] **Step 5: `symbol_move_test` through `plan.select` (D-01, IA-R2, IA-R3).** Create `I/test/attach/symbol_move_test.dart` from `symbols/symbol_move_test.dart`, MV1-MV6:
  - the symbols (`:33-54`): `rect(key, w, d, tags)` → `CatalogSymbol(key:, name:, category: 'Tests', tags:, attachTo: [...], base: (w / 2, d / 2), shapes: [CatalogPolyline([(0, 0), (w, 0), (w, d), (0, d)], closed: true)])` (authoring), with the keys `fx.test.bed` (attachTo `['wall-face']`), `fx.test.island` (none), `fx.test.unit` (attachTo `['wall-face']`) (C7 classes 1 and 2: the tag `against-wall` is `attachTo`), the library `fxKit(library: [...])`; `entry(key)` → the controller's `PlanSymbol`'s `entry`.
  - `Scene` (`:55-141`, with `scene`) becomes a pumped editor: the plan file `freeWallPlan(30, Justification.centre)` with the symbol placed by `placeUnit`-style hand placement (`units.dart`'s `placeUnit` copies the definition with its `SymbolComponent` — give `entryOf` the `attachTo` and `family` of the `CatalogSymbol`: Step 4 of Task 26 copied 2b's `entryOf`, which drops them; add `attachTo: s.attachTo, family: s.family` to its `SymbolComponent(...)` here and say so in the report), then the transform `Transform2.translation(off) · attachedAt` set by `TransformNodeCommand` as today (`:82-84`); `attachedAt` = `attachOf(doc, entry, mid, placementTransform(at: mid, basePoint: base, mirrored: mirrored), 0.1, mirrored: mirrored)!.transform` (IA-R1; today's `faces.attach(doc, box, mid, 160, mirrored:, edgeCaptureWorld: 60)`: the capture `16 / 0.1` = 160 mm, the edge `10 / 0.1` = 100 mm, not 60: **the edge capture differs**, so `attachedAt` is the provider's at the plan's own edge capture; the attachment of a box centred mid-run is not edge-snapped at either, MV's premise `:73-75`). The controller `PlanController(kits: [architectureKit, fxKit(library: [...])], json: json)` in `pumpPlanEditor`, the camera `Transform2(0.1, 0, 0, -0.1, -9600, -6600)` (`:86-87`) on `c.camera`; F3 off where `objectSnap: false` (`pressKey(tester, LogicalKeyboardKey.f3)` after a canvas focus).
  - `resolveMove(ctx, instance, delta)` → a drag of the instance's body from `press` (`s.transform.transformPoint(Vector2(0, 1000))`, MV4's point) to `delta.transformPoint(press)` (Task 26's `drag` helper over `globalAt`), then the instance's transform read (`s.transform`); each case asserts on it what it asserted on `r.transform`; `isNull` → the transform is `delta · T` (the plain move, `partsOf` equal within 1e-9).
  - MV1's marker line, MV3's "no library" clause: IA-R3 (left out, each with a comment naming the ruling).
  - MV4 ported as is, its `SelectTool(moveResolver:)` → the canvas's select tool (`plan.select`), its four events → the same drag on the canvas.
  - MV3's scaled instance: the scale applied by `TransformNodeCommand` on `c.document` as today, then the drag.

- [ ] **Step 6: D-02 through `plan.symbol` (IA-R4).** Create `I/test/attach/wall_attach_tool_test.dart` from `symbols/symbol_place_tool_test.dart:1368-1740` and the rig parts it uses:
  - the symbols: `toilet` → `armable(c, 'bath.toilet')`, `base600` → `kitchen.base.600`, `island` → `kitchen.island`; `toilet.tags, contains(againstWallTag)` → `toilet.component.attachTo, contains('wall-face')` (C7 class 2), `isNot(contains(...))` likewise.
  - `Rig(walls: [attachWall(deg, j)])` → a controller over `attachPlan([attachWall(deg, j)], extra: (d) => …)` where `extra` adds today's rig page (`symbol_place_tool_test.dart`'s `Rig`: `PageComponent(originX: gridOriginX, originY: gridOriginY, gridStepMm: gridStep)`) and its line `e0` (copy `gridStep`, `gridOriginX`, `gridOriginY`, `gridOf`, `e0`, `onRun`, `attachWall`, `attachCases`, `kR`, `kM`, `partsOf`, `expectAt` from the source file, `:1-130` region, unchanged); `pumpPlanEditor`, then `frameOn(tester, c, <the wall's middle>, scale: 0.05)`; `rig.armed.value = e` → `c.armSymbol(e)`; `rig.key(kR)` → `pressKey(tester, LogicalKeyboardKey.keyR)`, `kM` likewise, Shift+R with `sendKeyDownEvent(shiftLeft)` around it; `rig.hover(p)` → a mouse moved to `globalAt(tester, c, p)`; `rig.down(p)`/`rig.up(p)` → `mouseClick`; `rig.instances` → the document's `InstanceNode`s; `rig.runOn(side)` → the wall's face on that side by hand (`worldEndsOf` + `faceOf` with `facesOf`'s offsets; a `FaceRun`'s `a`, `t`, `m` become the face's start, its unit direction and its inward normal, written in the test); `rig.attachOf(e, p, mirrored:)` → `attachOf(c.document, e.entry, worldAt(p), current, 0.05, mirrored:)` with `worldAt` the canvas's read of the pointer (the global point taken back through the camera, as `dimension_shell_test.dart:118-122` does) and `current` per AT-8; `rig.freeOf(e)` → `placementTransform(at: gridOf(worldAt(p)), basePoint: e.entry.definition.basePoint, quarterTurns:, mirrored:)`.
  - a ghost read (`rig.tool.ghostPlacement!`, `ghostAttachment`, `ghostAt`) at a pointer → the instance one click commits there (IA-R4), the case's `undoDepth` expectations shifted by the clicks it adds (each is one step, the source's own count for a click); `want.q` → `want.marker`; `want.run, same(run)` → `faceDistance(...) < 1e-6` (IA-R1).
  - **human (IA-R4):** not ported: `rig.notifications` (`:1518-1520`, `:1628-1636`, "one repaint"), the marker case's `paintOverlay` and `canvas.named(...)` lines (`:1572-1616`, the case keeps its first two assertions on `ghostAttachment!.q` read as the committed marker), `rig.tool.faces` isNull (`:1499`: the plan's tool always has the registry). Each left out with `// Not ported (ruling IA-R4): <line>`.
  - "a tool given no wall faces never attaches" (`:1496-1506`): its premise (a tool built without faces) cannot be built (`plan.symbol` always has the registry): not ported (C7, premise impossible).

- [ ] **Step 7: D-03, D-04, D-05 (IA-R5).**
  1. `I/test/attach/against_wall_rotate_test.dart` from `host/against_wall_rotate_test.dart`, the three cases: `t.mountEditor(tester, caps: Caps.full.copyWith(rotate: rotate))` → `mountEditor(tester, permissions: PlanPermissions.full.copyWith(rotate: rotate))` (Task 26's editor fixture: the sample flat with 2b's units); `h.caps.value = X` → `c.permissions = X; await tester.pump();`; `gridSnapOff(d)` copied (`editor_tools_review_test.dart:78-83`); `t.openSymbols` → tap `tab-symbols` and wait for `c.symbolsState` ready; `tester.enterText(t.byKey('symbol-search'), 'base unit 600')` unchanged; `t.arm(tester, 'kitchen.base.600')` → the cell `symbol-cell-architecture.kitchen.base.600@1` tapped; `place`, `hover`, `drag`, `activeTool` copied from `editor_tools_review_test.dart:35-76` with `t.screenOf` → `screenOf`, `t.instancesOf` → the document's instances; `FloorPlanTool.symbol` → `'plan.symbol'`.
  2. `I/test/attach/wall_attach_end_to_end_test.dart` from the app's WE1 (`apps/floor_planner/test/symbols/wall_attach_end_to_end_test.dart:219-381`): `pumpSymbolsApp` → `PlanEditor` over `architectureController(json: attachPlan([...]).json)` (the L of 100 and 240 mm walls, `:225-245`, written through `attachPlan` with today's rotations), the camera of `:247-253` on `c.camera`; `armBySymbolsTab(tester, 'bed.double')` → the gallery's search and cell for `architecture.bed.double`; `runsIn(doc)` and `attachToWall(...)` → IA-R1's `attachOf`; `bedAt.hovered` lines → IA-R5 (human); `host.saveAsStep()`, `files.saved` → `c.save()`; the reopened plan → a second controller `architectureController(json: saved)`; `bytesOf(doc)` → `c.save()` before and after. `drawnVertices`, `expectFlush` copied (`:110-175`).
  3. `I/test/attach/symbol_shell_test.dart`: SS16 and SS17 (`symbol_shell_test.dart:620-730`), over the same editor and `addAttachWall` written as an `attachPlan` of one 30° wall; SS16's `attachToWall([run], …)` → `attachOf`; SS17's layers by `AddLayerCommand` and `SetComponentCommand<ObjectLayer>` as today, on `c.document`.
  4. `I/test/attach/editor_tools_review_test.dart`: the north-wall case (`editor_tools_review_test.dart:199-231`), O13a (`:413-446`), O13b (`:448-475`): over `mountEditor`; `h.caps.value = Caps.full.copyWith(mirror: false)` → `c.permissions = PlanPermissions.full.copyWith(mirror: false)`; `Caps.full.copyWith(snapping: snapping)` → `PlanEditor(snapping: snapping)` (2a: snapping is the editor's option; Task 26's `mountEditor` gains a `bool snapping = true` passed to `PlanEditor`); `groupWith<T>` copied (`:91-97`); `view.selection` → `c.activeSelection`; `view.grips!.grips` → `gripsOf(tester).grips`; `bath.toilet` → `architecture.bath.toilet`.

- [ ] **Step 8: D-12 through the gallery.** Create `I/test/symbols/symbol_search_test.dart` from `symbols/symbol_search_test.dart:76-164` (the group "a single field", 6) and `:189-267` (the groups "several terms" and the case-folding cases, 6):
  - the library: an editor over `architectureController()` (its Symbols tab), at 1440 x 6000 so every hit's cell is built; `searchSymbols(lib.entries, q)` → the query typed into `symbol-search`, two pumps, and the result read from the gallery: `ids(found)` → the cells' keys in tree order (`symbol-cell-<id>`, the id after the prefix), `categoriesOf(found)` → the group headers in tree order (`symbol-group-<name>`, the Flutter layer's gallery keys, `jet_cad_2d_flutter/lib/src/symbol_gallery.dart:56`); `hitsOnly(lib.entries, term, field)` (the premise that a term hits one field only) copied over `c.symbols`' components (`key`, `name`, `tags`, `category`), unchanged.
  - the ids (C7 class 1): every `<key>@<v>` → `architecture.<key>@1` (`dining.table.*@2` → `@1`, `armchair@1` → `architecture.armchair.single@1`); the categories are the English words the gallery shows (`Living Room`, …), today's.
  - the plan's gallery searches the shown names, the categories and the tags (2a's `gallery_model_test` GM tests); a term the source expected to hit through the key alone is a finding to report, not an assertion to change.

- [ ] **Step 9: R-16's room lines (IA-R6).**
  1. `I/test/support/shot.dart`: copy `jet_cad_2d_plan/test/support/canvas_fixture.dart:31-60` (the themes and swatches), `:150-210` (`windowAt`, `pumpThemed`, `rgbOf`, `hex`, `channelDistance`, `Shot`, `shoot`), `:212-226` (`pixelOf`), its imports through the public barrels (each name is the Flutter layer's or `dart:ui`'s).
  2. `I/test/support/fill_plan.dart`: the 2b fill fixture (`jet_cad_2d_plan/test/service/paint/unit_fill_test.dart:66-226`: `roundTable`, the colours, `Spec`, `specs`, `spec`, `placementOf`, `insideTop`, `composite`) copied, with today's R (`table_fill_test.dart:183-193`: `key: 'R', label: 'R'`, its place and its `purple`) restored in `specs` after `M`, today's `tintAlpha = 51` (`:86`) and `tintSample` (`:208-209`), and `fillDoc` (`:200-226`) → `String fillJson()`: `planWith((doc) { …the page command, the two layers (units.dart's addLayer), each spec placed by placeUnit and labelled by labelUnit… ; today's teal room: the four 200 mm walls and the room (table_fill_test.dart:211-252, its walls through plans.dart's addWall, the room `RoomParams(41500, -32000, 'Dining', color: 'teal')`) }, kits: [architectureKit, fxKit()])`, then the colours written into the saved text: `components['jetcad.unit_colour']['<instance handle>'] = {'color': name}` for each spec with a colour (the plan file's own encoding of `UnitColour`, `unit_components.dart:178-200`).
  3. `I/test/service/room_fill_test.dart`, three cases, each the source's room lines verbatim with the premises they need:
     - `TF1-room` (D-35): over `PlanEditor` on `architectureController`-with-`fxKit()` over `fillJson()`, light theme, white paper, the painter camera's view (`painterCamera`, `unit_fill_test.dart:233`, on `c.camera`): `expectAt(tester, shot, tintSample, composite(teal, tintAlpha, whitePaper), 'the room\'s tint alone')` and `expectAt(tester, shot, insideTop(spec('R')), composite(teal, tintAlpha, purpleFill), 'R under the room\'s tint')` (`table_fill_test.dart:542-545`), `purpleFill = composite(purple, alphaDefault, whitePaper)`.
     - `TF3-count` (D-36): the colour layer's painter (`tester.widget<CustomPaint>(byKey('unit-colour-layer')).painter!`) recorded by the source's `FillSpy` (`unit_fill_test.dart:254-323`, copied) at the painter camera: `expect(spy.fills, hasLength(6), reason: 'A, B, C, U, K and R')` (`table_fill_test.dart:587`), with the source's three `isNull` premises (H, M, N) before it.
     - `TF7-tint` (D-35): `table_fill_test.dart:675-725`'s tint lines (`:690-711`, `:718-719`) over the editor under the dark and then the light theme (`pumpThemed`), the fill pixel at `insideTop(spec('C'))` and the tint at `tintSample`.
  4. `I/test/export/room_export_test.dart` (D-37): EX2's tint and R lines (`table_color_export_test.dart:237-241`), EX3's tint line (`:277-278`), EX5's R row (the loop over `filled` with R in it, `:478-501`), and the fixture premises' key list with R (`:140-143`), over `fillJson()`'s controller and `c.export('plan.png', <png at 96 dpi>)` (EX2's `pageFlows.exportOnce` → `c.pageFlows.exportOnce` under R-P9's ignore, or `c.export`, which EX3 already uses; `decode`, `pixelAt`, `expectRgb` copied from `jet_cad_2d_plan/test/export/unit_colour_export_test.dart`, their imports public).
  5. `I/test/support/zone_plan.dart` and `I/test/controller/zone_room_test.dart` (D-38): 2b's zone fixture (`jet_cad_2d_plan/test/support/unit_zone_fixture.dart`) copied with today's room `7` restored (`jet_cad_floor_plan/test/host/zone_fixture.dart:81-90`: `twoRoomWalls` at `Placement('room 7', 66000, -21000, 23)`, `addRoom(doc, room.at(1512.5, 1987.25), '7')`), built through `planWith` and `units.dart`; CZ1 (`host/controller_test.dart:559-586`) ported whole: `c.fitToTables({'3'})` → `c.fitToUnits({'3'})`, `c.framingFor(zoneSize)` (R-P9 ignore), `frameTables(bound, size)` → the copied `frameUnits` (IA-R6), `TableSurvey.of(d).withNumber('7').single.label!` → the UNIT label of `unitsLabelled(d, '7').single`, `expect(looks, hasLength(2), reason: 'premise: the TEXT and the room name')` unchanged.
  - Each file that reads `pageFlows` or `framingFor` starts with `// ignore_for_file: invalid_use_of_internal_member` (R-P9).

- [ ] **Step 10: The paint-allocation invariant over the sample flat (new: IA-alloc).** Create `I/test/invariants/paint_allocation_test.dart`:

```dart
// The plan library's paint-allocation invariant (CLAUDE.md: the frame path
// allocates nothing per entity in steady state, and O(1) per flush) with
// the architecture kit loaded, over the sample flat (spec C6, Tests "The
// non-negotiables"). The harness is jet_cad_2d_plan/test/invariants/
// canvas_paint_allocation_test.dart's CV-alloc (3a Task 28): ten rebuilt
// frames of PlanCanvas, the camera moving one pixel, 50 root entities
// selected so the overlay draws outlines and grips; the same canvas state,
// painter, sink and Paint, and a capacity that holds still.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

void main() {
  testWidgets(
      'IA-alloc a rebuilt steady-state PlanCanvas frame over the sample flat '
      'allocates O(1) per flush, the kit loaded (M-IA-alloc)', (tester) async {
    final c = sampleFlatController();
    addTearDown(c.dispose);
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PlanCanvas(controller: c))));
    await tester.pump();

    final doc = c.document;
    final roots = [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == doc.rootHandle)
          doc.entities.handleAt(slot),
    ].take(50).toList();
    expect(roots, hasLength(50), reason: 'premise: root entities to select');
    c.activeSelection.replace([for (final h in roots) SelectionKey.root(h)]);

    final size = tester.getSize(find.byType(InteractionLayer));
    final a = ViewportTransform.fit(doc.extents, size);
    final b = ViewportTransform(
        worldToScreenMatrix:
            Transform2.translation(1, -1).multiply(a.worldToScreenMatrix));
    Future<void> frames(int n) async {
      for (var i = 0; i < n; i++) {
        c.camera.value = i.isEven ? a : b;
        tester.element(find.byType(PlanCanvas)).markNeedsBuild();
        await tester.pump();
      }
    }

    await frames(6);
    final state = tester.state<DraftCanvasState>(find.byType(DraftCanvas));
    final painter = state.painter;
    final sink = state.vertices!;
    final capacity = sink.debugCapacityVertices;
    final paint = sink.debugPaint;
    sink.resetCounters();

    await frames(10);

    expect(
        identical(
            tester.state<DraftCanvasState>(find.byType(DraftCanvas)), state),
        isTrue,
        reason: 'a rebuild remounted DraftCanvas');
    expect(identical(state.painter, painter), isTrue,
        reason: 'a rebuild handed DraftCanvas a new resolver');
    expect(identical(state.vertices, sink), isTrue);
    expect(sink.totalFlushCount, greaterThan(0),
        reason: 'nothing was flushed, so nothing was measured');
    expect(sink.frameTriangleCount, greaterThan(1000),
        reason: 'a degenerate plan would make the bound meaningless');
    expect(sink.debugCapacityVertices, capacity,
        reason: 'the buffer grew in a steady-state frame: O(entities)');
    expect(identical(sink.debugPaint, paint), isTrue,
        reason: 'flush() must reuse the one Paint of the sink\'s life');
  });
}
```

  (The source's comment and assertions, `canvas_paint_allocation_test.dart:41-128`, with the corpus replaced by the sample flat and `c.selection` by `c.activeSelection`. If the sample's frame draws 1,000 triangles or fewer, the premise fails: report the count; the bound is the plan's and is not lowered.)

- [ ] **Step 11: Run.** `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice test/attach test/symbols test/service/room_fill_test.dart test/export/room_export_test.dart test/controller/zone_room_test.dart test/invariants/paint_allocation_test.dart`; `cd packages/jet_cad_2d_kit_architecture && flutter test test/attach test/furniture`. Expected: `All tests passed!`. A ported case that fails is a finding for the task that owns the code (stop; quote it with its source line); never change an assertion.

- [ ] **Step 12: Format and the gates.**
  - `cd packages/jet_cad_2d_integration && dart format . && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_kit_architecture && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - From the root: `dart run tool/ci/check_kit_deps.dart` (the kit's new tests name no plan library).
  - `grep -rn "package:jet_cad_2d_plan/src\|package:jet_cad_2d_kit_architecture/src" packages/jet_cad_2d_integration`: nothing (R-P1). `grep -rln "invalid_use_of_internal_member" packages/jet_cad_2d_integration/test`: Task 26's `room_paint_test.dart` and this task's `zone_room_test.dart` (and `room_export_test.dart` if it kept `pageFlows`), nothing else.
  - Non-ASCII: `grep -n "−\|°\|²" packages/jet_cad_2d_integration/test/attach/*.dart` against the sources.
  - `git status --short`: this task's files only.

- [ ] **Step 13: Commit.**

```bash
git add packages/jet_cad_2d_kit_architecture/test/attach/wall_attach_test.dart packages/jet_cad_2d_kit_architecture/test/attach/wall_attach_property_test.dart packages/jet_cad_2d_kit_architecture/test/furniture/symbol_box_asset_test.dart packages/jet_cad_2d_kit_architecture/test/furniture/symbol_end_to_end_test.dart packages/jet_cad_2d_kit_architecture/test/support/select_rig.dart packages/jet_cad_2d_integration/test/support/attach_plans.dart packages/jet_cad_2d_integration/test/support/shot.dart packages/jet_cad_2d_integration/test/support/fill_plan.dart packages/jet_cad_2d_integration/test/support/zone_plan.dart packages/jet_cad_2d_integration/test/support/units.dart packages/jet_cad_2d_integration/test/support/editor_fixture.dart packages/jet_cad_2d_integration/test/attach/symbol_move_test.dart packages/jet_cad_2d_integration/test/attach/wall_attach_tool_test.dart packages/jet_cad_2d_integration/test/attach/against_wall_rotate_test.dart packages/jet_cad_2d_integration/test/attach/wall_attach_end_to_end_test.dart packages/jet_cad_2d_integration/test/attach/symbol_shell_test.dart packages/jet_cad_2d_integration/test/attach/editor_tools_review_test.dart packages/jet_cad_2d_integration/test/symbols/symbol_search_test.dart packages/jet_cad_2d_integration/test/service/room_fill_test.dart packages/jet_cad_2d_integration/test/export/room_export_test.dart packages/jet_cad_2d_integration/test/controller/zone_room_test.dart packages/jet_cad_2d_integration/test/invariants/paint_allocation_test.dart
git commit -m "$(cat <<'EOF'
test(integration): the wall attachment end to end, R-16, the paint invariant (3a Task 28)

The wall-face provider through plan.symbol and plan.select on the canvas:
placement, the move along a face, the turn under rotate: false, the
mirror, the grips' snapping, the L end to end with its save round trip,
the shell's base units and the hidden and locked walls; the furniture
library through the gallery's search; R-16's room and tint lines back
(TF3 counts six fills again), the zone fixture's room named 7; the paint
invariant over the sample flat with the kit loaded. attachToWall, the
asset's boxes and the end-to-end symbol run in the kit over place_entry.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

  (`units.dart` and `editor_fixture.dart` are in the list for Step 5's `entryOf` change and Step 7's `snapping` option.)

- [ ] **Step 14: Mutation check** (committed files only; after each: run the named test, see it red, quote the red line, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0).
  - M-IA-alloc `packages/jet_cad_2d_plan/lib/src/canvas/plan_canvas.dart`: the resolver handed to the canvas made per build (the `resolver:` argument wrapped in a fresh closure each build, as 2a's M-CV-alloc-1) → IA-alloc red ("a new resolver").
  - M-IA-1 `packages/jet_cad_2d_kit_architecture/lib/src/attach/wall_face_provider.dart`: `kind` → `'wall-face-x'` → `wall_attach_tool_test`'s "a tagged symbol attaches on hover and on release" red (the instance is free) and WE1 red.
  - M-IA-2 `wall_face_provider.dart`: the `mayRotate: false` rule removed (a face that would turn the symbol is offered) → `against_wall_rotate_test`'s `rotate: false` case red.
  - M-IA-3 `packages/jet_cad_2d_kit_architecture/lib/src/attach/wall_faces.dart`: the `stateId` comparison removed (D-06) → SS16 red (the second unit placed before the change stream delivers misses the first unit's side). If it stays green, report it (do not change SS16).
  - M-IA-4 `wall_faces.dart`: the host predicate `isUsableHost` → `(_, __) => true` → SS17 red (a wall on a hidden layer hosts).
  - M-IA-5 `packages/jet_cad_2d_kit_architecture/lib/src/room/room.dart`: the tint's transparency for a coloured room changed (`kRoomColorTransparency` 204 → 230) → `TF1-room` red.
  Quote each red line.

#### Interface problem

1. **(Resolved by ruling R-P18: the table halves stay 2b's; the room lines run here over public routes.)** **R-16's full copies cannot run anywhere (spec C6's "TF1, TF3 and TF7 with the room … EX2, EX3 and EX5 … CZ1").** The 2b ports build `UnitStatusPainter` and its notifiers by hand, use `ServicePaintLayers`, `UnitColour` and `frameUnits` (`jet_cad_2d_plan/test/service/paint/unit_fill_test.dart:46, :339-375`; `test/support/service_paint.dart`), all plan-internal; the integration package may not import them (R-P1) and the plan's tests may not name a room. Proposed (IA-R6, taken here): the room's lines run as whole tests in the integration package over public roads; the table halves stay 2b's. The spec's wording ("full copies") is amended by the controller, or the human allows `src/` imports in the integration package's tests.
2. **Lines with no public counterpart (IA-R3, IA-R4, IA-R5, marked human).** A ghost's repaint count, the marker glyph's paint calls, a tool built without faces, the resolver's marker, the library-not-ready premise and WE1's hover ghost read the plan's private tool state. They are listed for the human's word (A14); the alternative, a test-only public read on `PlanController` (a 2a amendment), is the human's call.
3. **`entryOf` drops `attachTo` and `family`.** 2b's `entryOf` (copied by Task 26 into `units.dart`) builds `SymbolComponent(key, version, name, category, tags)` (`jet_cad_2d_plan/test/support/unit_fixtures.dart:151-156`); Step 5 adds `attachTo` and `family` to the copy. No other task's test reads the dropped fields; Task 26's reviewer sees the change.

#### New shared name

Integration test support created here: `I/test/support/attach_plans.dart` (`kAttachPixels`, `furniture`, `furnitureEntry`, `armable`, `wallFaces`, `attachOf`, `faceDistance`, `attachX`, `attachY`, `farAt`, `attachAngles`, `attachGroup`, `SceneWall`, `attachPlan`, `freeWallPlan`), `I/test/support/shot.dart` (2a's pixel helpers), `I/test/support/fill_plan.dart` (`fillJson`, `specs`, `spec`, `insideTop`, `composite`, `tintSample`, `tintAlpha`, …), `I/test/support/zone_plan.dart` (`zonePlanJson`, `sevenTexts`, …). Task 26's `mountEditor` gains `bool snapping = true`.

---

