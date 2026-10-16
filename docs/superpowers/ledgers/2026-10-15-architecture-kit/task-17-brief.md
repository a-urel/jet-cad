### Task 17: The separator's grips, tool and plan type (spec C3.4; C1.3's DASHED lines, C1.8, C7)

**Files:**
- Create (`packages/jet_cad_2d_kit_architecture/`): `lib/src/separator/separator_grips.dart` (ported), `lib/src/separator/separator_tool.dart` (ported), `lib/src/separator/separator_plan.dart` (new), `test/separator/separator_tool_test.dart` (ported), `test/separator/separator_plan_test.dart` (new, and ND2's DASHED line)
- Modify (`packages/jet_cad_2d_kit_architecture/`): `lib/src/kit.dart` (the type and the tool), `CHANGELOG.md`, `test/wall/wall_grips_test.dart` (Task 12's: EG8-k, carried from Task 12, R-P8)
- Modify (`packages/jet_cad_2d_integration/`): `test/wall/wall_grips_test.dart` (Task 12's: EG7, EG8, carried from Task 12, R-P8)
- Create (`packages/jet_cad_2d_integration/`): `test/separator/separator_plans.dart` (test support), `test/separator/separator_shell_test.dart` (ST1's shell half), `test/separator/separator_dashed_test.dart` (ND1, ND3, ND4's live case; SP-dashed-open), `test/separator/separator_export_test.dart` (D-30)

**Interfaces:**
- Consumes:
  - Task 16: `SeparatorParams` (with `start`, `end`, `copyWith`), `SeparatorType` (`lib/src/separator/separator.dart`); `RoomInputs` (`invalidate()`, `inputOf`, a `Disposable` the services dispose), `trimSeparator(Vector2 a, Vector2 b, RoomInputs inputs, {required bool objectSnap})`, `RoomInputs roomInputsOf(PlanServices s)` (`lib/src/room/room_inputs.dart`); `distToSegment`, `pointInRing` (`lib/src/room/room_trace.dart`); the kit's test support `test/support/room_fixture.dart` (`W`, `Placement`, `origin`, `corpusGroups`, `placements`, `Plan`, `buildPlan(walls, {seps, place, ...})`, `boxWalls`, `kindsOf`, and `wall_fixture.dart`'s re-exported `driftOf`), and the separator's raw registration in the test catalog.
  - Task 10: `test/support/catalog.dart`'s `testCatalog` (see "Assumed").
  - Tasks 11-15: `WallParams`, `Justification` exported by the barrel; `wallPlanType`, `openingPlanType`, `doorPlanTool`, `windowPlanTool`, `gapPlanTool` in `architectureKit`.
  - Task 9: `ArchitectureTypes.separator`, `ArchitectureTools.separator`, `architectureKit`, `kDashedLinetypeRecord`, `ensureDashedLinetype`; the integration package's `architectureController`, rig (`pumpEditor`, `globalOf`, `status`, `press`, `activeTool`, `liveOf`).
  - Task 5 (C1.3, C1.9): `PlanController({..., PlanBuild? build})`, `typedef PlanBuild = void Function(DraftDocument document, KitWords words)`; `prepare` on made plans only.
  - Task 6: `FakePlanServices({required DraftDocument document, ParametricCatalog? catalog, bool objectSnap = true, ...})`, `dispose()`.
  - The contract today: `PlanType` (`grips`, `gripsFor`, `exported`, `properties`, `hasColour`, `hasSection`), `PlanTool`; the plan library today: `PlanController.export(String id, PlanExportChoice choice)` (`PlanExportChoice(dpi: PlanExportDpi.d96)`, `.initial`), `save`, `load`, `dirty`, `canUndo`, `typeOf`; the Flutter layer: `ObjectGripProvider`, `Grip`, `GripRole`, `PlacementTool`, `exportPagePng`, `exportPagePdf`, `ExportDpi` and `package:jet_cad_2d_flutter/export_testing.dart`'s `PdfContent`, `PdfXY`.
- Produces (Shared interfaces, exact):

```dart
// lib/src/separator/separator_plan.dart
final PlanType<SeparatorParams> separatorPlanType;  // id ArchitectureTypes.separator, exported: false, grips
final PlanTool separatorPlanTool;                   // id ArchitectureTools.separator, letter 'S'
// architectureKit: types gain separatorPlanType after openingPlanType (today's order);
// tools gain separatorPlanTool after gapPlanTool (Task 19 inserts roomPlanTool before it).
```

  Kept under `lib/src/separator/` with today's names: `SeparatorGrips({required RoomInputs inputs, required bool Function() objectSnap})`, `SeparatorTool(RoomInputs inputs)` (its `inputs`, `debugBand`, `isPending`).

**Appendix A rows closed:**
- D-19, the separator's tool file: `separator_tool_test.dart` 5 of 6 — ST1 (its tool half in the kit, its shell half in the integration package: one case split by C7's rule), ST2, ST3, ST5, ST6 (kit). **ST4** ("a new separator splits its room") adds a room and reads its label (`addRoom`, `labelStrings`, `faceAt`, `:351-380`): the room type is Task 18's, so ST4 is carried there (see "Interface problem" 1). `separator_test.dart` is Task 16's; the separator grips' own case, `room_grips_test.dart` GR5 (`:484-574`), builds two rooms and is Task 18's with its file.
- D-28, the DASHED part: `new_document_test.dart` ND1's DASHED lines (`:35-38`, integration), ND2's (`:60-61`, kit: the kit's `prepare` alone), ND3's (`:77-79`, integration), and ND4's "with registerAppComponents: a live page and live walls" (`:82-103`, integration; see "Interface problem" 2). ND1-ND4's page, unit, page-only and catalog-only lines are Task 5's. Review Focus 1's kit half: SP-dashed-open.
- D-30: the separator's type is `exported: false`, and `plan.png` and `plan.pdf` leave every separator out through the real kit (SP-export-png, SP-export-pdf).
- D-19, `wall_grips_test.dart` EG7, EG8 (carried from Task 12, R-P8: `shadowDoc` builds a door and a separator): EG7 and EG8's shell part in the integration package, EG8's provider-direct part as EG8-k in the kit (Step 7b).
- Not ported here (checked): no case of `separator_tool_test.dart` or `new_document_test.dart` exists in `packages/jet_cad_2d_plan/test` or `packages/jet_cad_2d_kit/test` (the plan's `ST1`-`ST6` in `test/service/service_tool_test.dart` are the service tool's own).

Plan decisions and rulings:
- **R17-1 (ST1's shell half reads the pending start as `isMidShape`).** Today's case casts the shell's active tool to `SeparatorTool` and reads `isPending` (`separator_tool_test.dart:212, 217-219`). In the plan the canvas holds the kit's tool inside the plan's guard (`kits/guard.dart:253-276`), and the plan's `toolFor`, which unwraps it, is `@internal` (`plan_controller.dart:2131-2137`), so the integration package (public libraries only, ruling R-P1) reaches the guard through the canvas's `InteractionLayer.tools.active` (`interaction_layer.dart:90`). A `PlacementTool`'s `isMidShape` *is* its `isPending` (`placement_tool.dart:70, 76`), and the guard forwards it (`guard.dart:363-366`): the same predicate under its `Tool` name, a finder change in the sense of C7's class 3. The asserted values (`isTrue`, then `isFalse`) are unchanged.
- **R17-2 (ND4 without the sample).** ND4 decodes the sample flat's bytes (`new_document_test.dart:86-96`); the sample is Task 25's. Its live-page-and-walls case is ported over a plan built with the same shape — ten walls, each in its own turned group, and the page off the world origin — so the group's premises (`:92-95`: a page, not the new document's, ten walls) hold as written. Task 25 may point the fixture at `sampleFlatController()` (a fixture change).
- **The grips read F3 from the plan** (`PlanServices.objectSnap`, at each event: `objectSnap: () => s.objectSnap`), as today's shell passed its own (`object_grips.dart`, `objectSnap: () => snap`); the tool reads `ctx.snap.objectSnap` (today's, `separator_tool.dart:56`). Both use the kit's one `RoomInputs` per document (`roomInputsOf`), as today's shell shared one (`planner_shell.dart:473`).
- **No properties** (today's panel has no separator section, `selection_panel.dart:1303-1410`); the type's title is `type:architecture.separator`. Icon `Icons.horizontal_rule` (today's palette is text, `planner_shell.dart:588-594`).
- **Grip refusals (C1.8):** today's `SeparatorGrips.drag` answers null for every refusal (`separator_grips.dart:54-66`): it never throws, so C1.8's `ArgumentError` rule has nothing to change here.

- [ ] **Step 1: Precondition.** Tasks 5, 6, 9-16 are committed. `cd packages/jet_cad_2d_kit_architecture && flutter test` and `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice`: `All tests passed!`. Then:
  - `grep -n "roomInputsOf\|^(Vector2, Vector2)? trimSeparator\|RoomInputs(this.document" packages/jet_cad_2d_kit_architecture/lib/src/room/room_inputs.dart` — expected: the three, as "Consumes" gives them.
  - `grep -n "register<" packages/jet_cad_2d_kit_architecture/test/support/catalog.dart` — expected: the box's, the wall's, the opening's and the separator's (Tasks 10, 11, 13, 16). The names are R-P13's, `testCatalog()` and `installParametric`.
  - `grep -n "SeparatorParams" packages/jet_cad_2d_kit_architecture/lib/jet_cad_2d_kit_architecture.dart` — expected: Task 16's export (its Step 7). No hit is a finding: stop and report it.

- [ ] **Step 2: The failing kit tests.**
  1. Create `test/separator/separator_tool_test.dart`: **ported from `packages/jet_cad_floor_plan/test/separator_tool_test.dart`, ST1 (`:141-194`, the tool half), ST2 (`:226-308`), ST3 (`:310-349`), ST5 (`:382-456`), ST6 (`:458-484`), assertions unchanged.** The file:
     - Header: today's `:1-12` unchanged, then:

```dart
//
// Ported from jet_cad_floor_plan/test/separator_tool_test.dart; assertions
// unchanged. The tool is the kit's plan tool's (`separatorPlanTool.create`)
// over a FakePlanServices of the kit tests' catalog, its RoomInputs the
// services' one (`roomInputsOf`, spec 3a C2); everything else is today's.
// ST1's shell half (S, the palette, Escape) is the integration package's
// (test/separator/separator_shell_test.dart); ST4 needs a room and is
// Task 18's.
```

     - Imports (today's `:13-28` replaced; `planner_shell.dart`, `planner_view.dart`, `room.dart`, `live_objects.dart`, `package:flutter/material.dart` and `package:flutter/services.dart` were the shell half's and ST4's):

```dart
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/widgets.dart' show Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_architecture/src/room/room_inputs.dart';
import 'package:jet_cad_2d_kit_architecture/src/room/room_trace.dart'
    show distToSegment, pointInRing;
import 'package:jet_cad_2d_kit_architecture/src/separator/separator_plan.dart';
import 'package:jet_cad_2d_kit_architecture/src/separator/separator_tool.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/room_fixture.dart';
```

       (`testCatalog()` comes through `room_fixture.dart`, which re-exports it since Task 16; importing `../support/catalog.dart` as well would be an `unnecessary_import`, which fails `flutter analyze`.)
     - `Rig` (`:32`) unchanged; `separatorRig` (`:34-63`) becomes:

```dart
/// A Separator tool over [doc], made by the kit's plan tool over a
/// FakePlanServices of the kit tests' catalog (its RoomInputs the services'
/// shared one): a camera at 1 pixel per mm (a 10 mm aperture), object snap
/// as [objectSnap] says, no page (no grid).
Rig separatorRig(DraftDocument doc, {bool objectSnap = true}) {
  final index = SpatialIndex(doc);
  final camera = CameraController(
      ViewportTransform(worldToScreenMatrix: Transform2.identity()));
  final selection = SelectionController(doc);
  final snap = SnapSettings(objectSnap: objectSnap);
  final services = FakePlanServices(
      document: doc, catalog: testCatalog(), objectSnap: objectSnap);
  final tool = separatorPlanTool.create(services) as SeparatorTool;
  addTearDown(() {
    tool.dispose();
    services.dispose();
    snap.dispose();
    selection.dispose();
    camera.dispose();
    index.dispose();
  });
  return (
    tool: tool,
    ctx: ToolContext(
        document: doc,
        index: index,
        camera: camera,
        selection: selection,
        snap: snap),
    inputs: roomInputsOf(services),
  );
}
```

     - `pointerAt`, `hoverTo`, `pressAt` (`:65-81`) unchanged; `separators` (`:83-85`) becomes `List<Handle> separators(DraftDocument doc) => testCatalog().objectsOf<SeparatorParams>(doc);` (today's `liveObjectsOf<SeparatorParams>` asked `parametricCatalog.objectsOf`, `live_objects.dart:28-29`); `rooms`, `status`, `press` (`:87-88`, `:132-138`) are not copied (ST4's and the shell half's); `distToLine`, `faceNear`, `chamferWalls`, `draw` (`:90-130`) unchanged.
     - `void main() {`, then ST1 as a `test(` (not `testWidgets`: its shell half left): name `'ST1 S places one separator in two clicks, one undo step'`, body `:143-194` unchanged (ending at `expect(driftOf(doc), isEmpty);`), `});`. Then `:225-349` (ST2, ST3) unchanged, `:381-484` (ST5, ST6, the closing `}`) unchanged.
  2. Create `test/separator/separator_plan_test.dart` (new; ids SP-type, SP-order, SP-grips; and ND2's DASHED line):

```dart
// Spec 3a C3.4: the separator as the kit declares it. Its type is not
// exported, has grips (two ends, band-trimmed over the kit's RoomInputs with
// the plan's F3, read at each drag) and no properties; its tool is S, made
// over the same RoomInputs, in today's palette place. And ND2's DASHED
// line (jet_cad_floor_plan/test/new_document_test.dart:49-62): the kit's
// prepare alone sets the record and adds no page, entity or history (spec
// 3a C1.3; ND2's registration and unit lines are Task 5's).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show Grip, GripRole;
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_architecture/src/room/room_inputs.dart';
import 'package:jet_cad_2d_kit_architecture/src/separator/separator_plan.dart';
import 'package:jet_cad_2d_kit_architecture/src/separator/separator_tool.dart';
import 'package:jet_cad_2d_kit_architecture/src/separator_linetype.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

// testCatalog() through room_fixture.dart's re-export (Task 16).
import '../support/room_fixture.dart';

Vector2 at(Grip g) => Vector2(g.x, g.y);

/// The distance from [p] to the line through [a] and [b], relative to [a]
/// (separator_tool_test.dart:90-94).
double distToLine(Vector2 p, Vector2 a, Vector2 b) {
  final d = b - a, q = p - a;
  return (q.x * d.y - q.y * d.x).abs() / d.length;
}

void main() {
  test(
      'SP-type the kit carries the separator: its type is not exported, has '
      'grips and no properties, colour or section; its tool S needs '
      'structure, components and geometry, has no settings, and is made '
      'over the services\' one RoomInputs', () {
    expect(architectureKit.types, contains(separatorPlanType));
    expect(separatorPlanType.id, ArchitectureTypes.separator);
    expect(SeparatorParams.componentTypeId, separatorPlanType.id);
    // M-SP-1: the type exported.
    expect(separatorPlanType.exported, isFalse);
    expect(separatorPlanType.grips, isNotNull);
    expect(separatorPlanType.properties, isEmpty);
    expect(separatorPlanType.hasColour, isFalse);
    expect(separatorPlanType.hasSection, isFalse);
    expect(architectureKit.tools, contains(separatorPlanTool));
    expect(separatorPlanTool.id, ArchitectureTools.separator);
    // M-SP-3: another letter.
    expect(separatorPlanTool.letter, 'S');
    expect(separatorPlanTool.needs,
        {Capability.structure, Capability.components, Capability.geometry});
    expect(separatorPlanTool.settings, isNull);
    final doc = DraftDocument.empty();
    addTearDown(doc.dispose);
    final services = FakePlanServices(document: doc, catalog: testCatalog());
    addTearDown(services.dispose);
    final tool = separatorPlanTool.create(services) as SeparatorTool;
    addTearDown(tool.dispose);
    expect(identical(tool.inputs, roomInputsOf(services)), isTrue);
  });

  test(
      'SP-order the kit\'s tools keep today\'s palette order (box, wall, '
      'door, window, gap, room, separator, dimension)', () {
    const today = [
      ArchitectureTools.box,
      ArchitectureTools.wall,
      ArchitectureTools.door,
      ArchitectureTools.window,
      ArchitectureTools.gap,
      ArchitectureTools.room,
      ArchitectureTools.separator,
      ArchitectureTools.dimension,
    ];
    final ids = [for (final t in architectureKit.tools) t.id];
    expect(ids, contains(ArchitectureTools.separator));
    // M-SP-4: the separator's tool listed first.
    expect(ids, [
      for (final id in today)
        if (ids.contains(id)) id,
    ]);
  });

  test(
      'SP-grips the type\'s grips: two stretch grips at the world ends; the '
      'end dragged into the north wall\'s band is trimmed to its inner face '
      'with the plan\'s object snap on and kept as placed with it off; the '
      'start stays exactly; movable', () {
    // The separator and every wall in their own turned groups at the
    // corpus's far origin; the drop's segment from the start is not
    // collinear with the separator, so the end that stays matters.
    final plan = buildPlan(boxWalls,
        seps: const [(3000.5, 1000.25, 3000.5, 3000.75)],
        place: corpusGroups);
    final doc = plan.doc;
    final sep = plan.seps.single;
    final p = plan.at(3600.75, 4030.5);
    for (final on in [true, false]) {
      final why = 'F3 ${on ? 'on' : 'off'}';
      final services = FakePlanServices(
          document: doc, catalog: testCatalog(), objectSnap: on);
      addTearDown(services.dispose);
      final grips = separatorPlanType.gripsFor(services)!;
      expect(grips.movable(doc, sep), isTrue);
      final [g0, g1] = grips.gripsOf(doc, sep);
      expect([g0.role, g1.role], [GripRole.stretch, GripRole.stretch]);
      expect((at(g0) - plan.at(3000.5, 1000.25)).length, lessThan(1e-6));
      expect((at(g1) - plan.at(3000.5, 3000.75)).length, lessThan(1e-6));
      final stored = doc.components.get<SeparatorParams>(sep)!;
      final depth = doc.commands.undoDepth;
      doc.commands.execute(grips.drag(doc, sep, g1, p)!);
      expect(doc.commands.undoDepth, depth + 1, reason: '$why: one step');
      final now = doc.components.get<SeparatorParams>(sep)!;
      expect((now.sx, now.sy), (stored.sx, stored.sy),
          reason: '$why: the start stays, exactly');
      final w = doc.tree.accumulatedTransform(sep).transformPoint(now.end);
      if (on) {
        // M-SP-7: the end trimmed from the wrong end.
        expect(distToLine(w, plan.at(0, 3900), plan.at(8000, 3900)),
            lessThan(1e-6),
            reason: '$why: on the north wall\'s inner face');
        expect(distToLine(w, at(g0), p), lessThan(1e-6),
            reason: '$why: on the segment from the start to the drop');
        expect((w - p).length, greaterThan(20), reason: '$why: out of the band');
      } else {
        // M-SP-2: the grips' object snap fixed on.
        expect((w - p).length, lessThan(1e-6), reason: '$why: as placed');
      }
      expect(driftOf(doc), isEmpty);
      doc.commands.undo();
      expect(doc.components.get<SeparatorParams>(sep), stored);
    }
  });

  test(
      'ND2 the set-up alone sets DASHED, and adds no page, entity or '
      'history (spec 12a D4): the kit\'s prepare, on a document whose page '
      'type is registered as the plan library registers it', () {
    final doc = DraftDocument.empty();
    addTearDown(doc.dispose);
    PageComponent.register(doc.components);
    architectureKit.prepare!(doc);
    expect(doc.components.get<PageComponent>(doc.rootHandle), isNull);
    expect(doc.entities.liveCount, 0);
    expect(doc.commands.undoDepth, 0);
    // M-SP-9: the kit without its prepare.
    expect(doc.tables.linetypes[ReservedHandles.dashedLinetype],
        kDashedLinetypeRecord);
  });
}
```

- [ ] **Step 3: Run them, expecting failure.** `cd packages/jet_cad_2d_kit_architecture && flutter test test/separator/separator_tool_test.dart test/separator/separator_plan_test.dart`. Expected: compilation errors, `Target of URI doesn't exist` for `src/separator/separator_plan.dart` and `src/separator/separator_tool.dart`. Quote them.

- [ ] **Step 4: The kit's code.**
  1. `lib/src/separator/separator_grips.dart`: **copy `packages/jet_cad_floor_plan/lib/src/parametric/separator_grips.dart` lines 1-113**, adapted:
     - a header comment first: `// The separator's end grips (spec 3a C3.4), ported from jet_cad_floor_plan/lib/src/parametric/separator_grips.dart. The RoomInputs is the kit's one per document (roomInputsOf), no longer the shell's.`
     - `:5` `import 'room_inputs.dart';` → `import '../room/room_inputs.dart';`
     - doc `:15` `over the shell's` → `over the kit's shared`; doc `:34-35` `/// The shell's document adapter, shared with the Room and Separator` / `/// tools. Never disposed here.` → `/// The kit's document adapter ([roomInputsOf]), shared with the Room and` / `/// Separator tools. Never disposed here.`
     - every other line unchanged.
  2. `lib/src/separator/separator_tool.dart`: **copy `packages/jet_cad_floor_plan/lib/src/parametric/separator_tool.dart` lines 1-138**, adapted:
     - a header comment first: `// The Separator tool, S (spec 3a C3.4), ported from jet_cad_floor_plan/lib/src/parametric/separator_tool.dart. The RoomInputs is the kit's one per document (roomInputsOf).`
     - `:8` `import 'room_inputs.dart';` → `import '../room/room_inputs.dart';`
     - doc `:20-21` `over the shell's` → `over the kit's shared`; doc `:36` `/// The shell's document adapter, shared with the Room tool and the` → `/// The kit's document adapter ([roomInputsOf]), shared with the Room tool and the`
     - every other line unchanged.
  3. `lib/src/separator/separator_plan.dart` (new):

```dart
// The separator as the kit declares it (spec 3a C3.4): its PlanType -- the
// type Task 16 ported, not exported (today's exportOmitOwners,
// jet_cad_floor_plan/lib/src/export/export_bytes.dart:28-29), its grips the
// two band-trimmed ends over the kit's one RoomInputs and the plan's F3 --
// and its PlanTool, S (planner_shell.dart:588-594), which band-trims
// through the same RoomInputs. No properties: today's panel has no
// separator section.
import 'package:flutter/material.dart' show Icons;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../ids.dart';
import '../room/room_inputs.dart';
import 'separator.dart';
import 'separator_grips.dart';
import 'separator_tool.dart';

/// The separator's type: drawn DASHED, an input to rooms, left out of
/// every export.
final PlanType<SeparatorParams> separatorPlanType = PlanType<SeparatorParams>(
  id: ArchitectureTypes.separator,
  fromJson: SeparatorParams.fromJson,
  parametric: const SeparatorType(),
  grips: (s) => SeparatorGrips(
      inputs: roomInputsOf(s), objectSnap: () => s.objectSnap),
  exported: false,
);

/// The Separator tool: two clicks per separator, band-trimmed.
final PlanTool separatorPlanTool = PlanTool(
  id: ArchitectureTools.separator,
  icon: Icons.horizontal_rule,
  letter: 'S',
  needs: const {
    Capability.structure,
    Capability.components,
    Capability.geometry,
  },
  create: (s) => SeparatorTool(roomInputsOf(s)),
);
```

  4. `lib/src/kit.dart`: `import 'separator/separator_plan.dart';`; in `types:`, `separatorPlanType` right after `openingPlanType`; in `tools:`, `separatorPlanTool` right after `gapPlanTool` (today's palette order; Task 19 puts `roomPlanTool` between them).
  5. `lib/jet_cad_2d_kit_architecture.dart`: unchanged (Task 16 exported `SeparatorParams`; Step 1 checked it).
  6. `CHANGELOG.md`: append `- The room separator (`architecture.separator`, `SeparatorParams`): drawn DASHED, an input to rooms, left out of PDF and PNG exports; its two end grips and the Separator tool (S) trim an end to the wall face it enters.`

- [ ] **Step 5: Run the kit's tests, expecting pass.** `cd packages/jet_cad_2d_kit_architecture && dart format . && flutter test`. Expected: `All tests passed!` (ST1-3, ST5, ST6, SP-type, SP-order, SP-grips, ND2; Task 9's SC-example now lists `architecture.separator (not exported)` and `architecture.separator (S)`).

- [ ] **Step 6: The failing integration tests.**
  1. Create `packages/jet_cad_2d_integration/test/separator/separator_plans.dart` (test support, public libraries only):

```dart
// Plans for the separator's integration tests, built through the plan
// library's build seam (spec 3a C1.9) with the kit's public names: walls
// and separators by command, each in its own root group, as today's room
// fixture adds them (jet_cad_floor_plan/test/support/room_fixture.dart:
// 118-178).
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show KitWords, PlanKit;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// A wall from world [s] to world [e], [thickness] thick, centred, in its
/// own root group [at] (the identity by default): its stored ends are [s]
/// and [e] taken back through [at]. One command.
Handle addWall(DraftDocument doc, Vector2 s, Vector2 e,
    {double thickness = 200, Transform2? at}) {
  final h = doc.handleSeed.next();
  final g = at ?? Transform2.identity();
  final inv = g.invert();
  final ls = inv.transformPoint(s), le = inv.transformPoint(e);
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h, parent: doc.rootHandle, transform: g, children: const [])),
    SetComponentCommand<WallParams>(h,
        WallParams(ls.x, ls.y, le.x, le.y, thickness, Justification.centre)),
  ], label: 'Add wall'));
  return h;
}

/// A separator from world [s] to world [e] in its own root group [at]
/// (room_fixture.dart:165-178's addSeparator).
Handle addSeparator(DraftDocument doc, Vector2 s, Vector2 e,
    {Transform2? at}) {
  final h = doc.handleSeed.next();
  final g = at ?? Transform2.identity();
  final inv = g.invert();
  final ls = inv.transformPoint(s), le = inv.transformPoint(e);
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h, parent: doc.rootHandle, transform: g, children: const [])),
    SetComponentCommand<SeparatorParams>(
        h, SeparatorParams(ls.x, ls.y, le.x, le.y)),
  ], label: 'Add separator'));
  return h;
}

/// room_fixture.dart:469-475's boxWalls: an 8,000 × 4,000 rectangle of
/// 200 mm walls, centred on their centrelines, in plan millimetres.
const List<(double, double, double, double)> boxWalls = [
  (0, 0, 8000, 0),
  (8000, 0, 8000, 4000),
  (8000, 4000, 0, 4000),
  (0, 4000, 0, 0),
];

/// Where the box's plan points go: centred on the world origin (a new
/// plan's sheet), then turned 23°.
final Transform2 boxPlace = Transform2.rotation(23 * math.pi / 180)
    .multiply(Transform2.translation(-4000, -2000));

Vector2 boxAt(double x, double y) => boxPlace.transformPoint(Vector2(x, y));

/// Wall [k]'s own group: today's `_groupFor` (room_fixture.dart:94-96) on
/// [boxPlace], a turn that is never a multiple of 90°.
Transform2 groupFor(int k) => boxPlace
    .multiply(Transform2.translation(311.5 * (k % 7), -173.25 * (k % 5)))
    .multiply(Transform2.rotation(0.3 + 0.7 * (k % 9)));

/// A [PlanBuild]: [boxWalls] at [boxPlace], each wall in its own group.
void buildBox(DraftDocument doc, KitWords words) {
  for (final (k, (sx, sy, ex, ey)) in boxWalls.indexed) {
    addWall(doc, boxAt(sx, sy), boxAt(ex, ey), at: groupFor(k));
  }
}

/// A [PlanBuild]: a wall, and well clear of it (over 1 m) a separator in a
/// turned, mirrored group, both on a new plan's sheet (A4 landscape at 1:50
/// about the world origin).
void buildWallAndSeparator(DraftDocument doc, KitWords words) {
  addWall(doc, Vector2(-5000.25, 3000.5), Vector2(4000.75, 3600.25),
      at: Transform2.translation(120.5, -80.25)
          .multiply(Transform2.rotation(0.05)));
  addSeparator(doc, Vector2(-3000.5, -1200.25), Vector2(2500.75, 1800.5),
      at: Transform2.translation(-310.25, 140.5)
          .multiply(Transform2.rotation(0.3))
          .multiply(Transform2.scale(-1, 1)));
}

/// A [PlanBuild] of the sample flat's shape for new_document_test's ND4
/// (ruling R17-2): ten walls, each in its own turned group, and the page
/// off the world origin.
void buildTenWalls(DraftDocument doc, KitWords words) {
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle, PageComponent(originX: 2100.5, originY: -1300.25)));
  for (var k = 0; k < 10; k++) {
    addWall(doc, Vector2(900.5 * k, 250.25),
        Vector2(900.5 * k + 600.75, 1700.5),
        at: Transform2.translation(311.5 * (k % 7), -173.25 * (k % 5))
            .multiply(Transform2.rotation(0.3 + 0.7 * (k % 9))));
  }
}

/// [architectureKit] without its prepare: a plan it writes has no DASHED
/// record (a file from a writer that never had one).
PlanKit get unpreparedKit => PlanKit(
      id: architectureKit.id,
      version: architectureKit.version,
      symbols: architectureKit.symbols,
      types: architectureKit.types,
      tools: architectureKit.tools,
      attachments: architectureKit.attachments,
      names: architectureKit.names,
    );

/// Separator [h]'s ends in world.
(Vector2, Vector2) separatorEnds(DraftDocument doc, Handle h) {
  final p = doc.components.get<SeparatorParams>(h)!;
  final t = doc.tree.accumulatedTransform(h);
  return (t.transformPoint(p.start), t.transformPoint(p.end));
}

/// The kit's DASHED record, written out (it is not exported):
/// jet_cad_floor_plan/lib/src/parametric/separator.dart:128-133.
const LinetypeRecord dashed = LinetypeRecord(
  handle: ReservedHandles.dashedLinetype,
  name: 'DASHED',
  description: 'Dashed __ __ __',
  pattern: DashPattern(dashes: [200, -100], totalLength: 300),
);
```

  2. Create `test/separator/separator_shell_test.dart` (ST1's shell half, `separator_tool_test.dart:196-223`, assertions unchanged):

```dart
// Ported from jet_cad_floor_plan/test/separator_tool_test.dart, ST1's shell
// half (:196-223, spec 10 D20); assertions unchanged. PlannerShell becomes
// PlanEditor over a controller of the kit whose plan is today's boxWalls,
// built through the plan's build seam (spec 3a C1.9, C6), turned and in
// own groups; the palette's 'tool-separator' is
// 'tool-architecture.separator' (C7 class 1). The pending start is the
// active tool's isMidShape, a PlacementTool's isPending (ruling R17-1).
// ST1's tool half and ST2-ST6 are the kit's.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/editor_rig.dart';
import 'separator_plans.dart';

void main() {
  testWidgets(
      'ST1 (editor) S and the palette entry activate the Separator tool; '
      'Esc cancels a pending start, then returns to Select', (tester) async {
    final c = PlanController(kits: [architectureKit], build: buildBox);
    addTearDown(c.dispose);
    await pumpEditor(tester, c, centre: boxAt(4000, 2000), scale: 0.08);
    await press(tester, LogicalKeyboardKey.keyS);
    expect(status(tester), 'Separator');
    await press(tester, LogicalKeyboardKey.keyV);
    await tester
        .tap(find.byKey(const Key('tool-${ArchitectureTools.separator}')));
    await tester.pump();
    expect(status(tester), 'Separator');
    final sep = activeTool(tester);
    final p = boxAt(2500.5, 2000.25);
    await tester.tapAt(globalOf(tester, c, p.x, p.y));
    await tester.pump();
    expect(sep.isMidShape, isTrue);
    await press(tester, LogicalKeyboardKey.escape);
    expect(sep.isMidShape, isFalse, reason: 'the pending start cancelled');
    expect(status(tester), 'Separator');
    await press(tester, LogicalKeyboardKey.escape);
    expect(status(tester), 'Select');
    expect(liveOf<SeparatorParams>(c, ArchitectureTypes.separator), isEmpty);
  });
}
```

  3. Create `test/separator/separator_dashed_test.dart`:

```dart
// Ported from jet_cad_floor_plan/test/new_document_test.dart (spec 12a D4,
// D8): ND1's and ND3's DASHED lines and ND4's "with registerAppComponents:
// a live page and live walls", assertions unchanged, over the plan library
// (spec 3a C1.3, C6). ND2's DASHED line is the kit's
// (test/separator/separator_plan_test.dart); ND1-ND4's page, unit,
// page-only and catalog-only lines are the plan library's (Task 5).
// registerAppComponents is the plan's own registration, which a
// controller's json load runs; the codec's text is the plan's save().
//
// And SP-dashed-open, Review Focus 1's kit half (the plan half is Task 5's
// PB3-prepare-load): a file without the record opens without it, its
// separator still names handle 6, where no record is, so it draws
// continuous (the painter's _patternFor answers null,
// jet_cad_2d_flutter/lib/src/draft_painter.dart:684-690), and it saves back
// byte-identical (today's R-3; the app's DO3, document_open_test.dart:
// 217-247).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/editor_rig.dart';
import 'separator_plans.dart';

PageComponent? pageOf(DraftDocument d) =>
    d.components.get<PageComponent>(d.rootHandle);

void main() {
  testWidgets(
      'ND1 the new plan holds DASHED at handle 6 (spec 12a D4, T-11)',
      (tester) async {
    final c = architectureController();
    addTearDown(c.dispose);
    final doc = c.document;
    // M-SP-9: the kit without its prepare.
    expect(doc.tables.linetypes[ReservedHandles.dashedLinetype], dashed);
    expect(doc.tables.linetypes.byName('DASHED')!.handle,
        ReservedHandles.dashedLinetype);
  });

  testWidgets(
      'ND3 the new plan encodes, and decodes with the plan\'s registration '
      'to the same DASHED and bytes (spec 12a D4, D8)', (tester) async {
    final c = architectureController();
    addTearDown(c.dispose);
    final saved = c.save();
    final loaded = architectureController(json: saved);
    addTearDown(loaded.dispose);
    expect(loaded.document.tables.linetypes[ReservedHandles.dashedLinetype],
        dashed);
    expect(loaded.save(), saved);
  });

  testWidgets(
      'ND4 the sample\'s bytes, decoded with the plan\'s registration '
      '(registerAppComponents): a live page and live walls (spec 12a D8, '
      'S-1)', (tester) async {
    final sample = PlanController(kits: [architectureKit], build: buildTenWalls);
    addTearDown(sample.dispose);
    final bytes = sample.save();
    final sampleWalls = liveOf<WallParams>(sample, ArchitectureTypes.wall);
    // The group's premises (:92-95), unchanged: a page off the world
    // origin, not the new document's, and ten walls.
    expect(pageOf(sample.document), isNotNull);
    expect(pageOf(sample.document),
        isNot(PageComponent(originX: -7425, originY: -5250)));
    expect(sampleWalls, hasLength(10));

    final loaded = architectureController(json: bytes);
    addTearDown(loaded.dispose);
    expect(pageOf(loaded.document), pageOf(sample.document));
    expect(liveOf<WallParams>(loaded, ArchitectureTypes.wall), sampleWalls);
  });

  testWidgets(
      'SP-dashed-open a file without the DASHED record opens without it: its '
      'separator names handle 6, where no record is, so it draws '
      'continuous; the plan is clean and saves back byte-identical; a load '
      'does the same', (tester) async {
    final writer =
        PlanController(kits: [unpreparedKit], build: buildWallAndSeparator);
    addTearDown(writer.dispose);
    expect(
        writer.document.tables.linetypes
            .contains(ReservedHandles.dashedLinetype),
        isFalse,
        reason: 'premise: a writer that never had the record');
    final file = writer.save();

    final c = architectureController(json: file);
    addTearDown(c.dispose);
    final doc = c.document;
    final sep = liveOf<SeparatorParams>(c, ArchitectureTypes.separator).single;
    final leaves = [
      for (final slot in doc.leavesByOwner()[sep]!) doc.entities.read(slot),
    ];
    expect(leaves, hasLength(1), reason: 'premise: its polyline');
    expect(leaves.single.linetype, ReservedHandles.dashedLinetype,
        reason: 'premise: it names handle 6');
    // M-SP-8: open runs the kits' prepare.
    expect(doc.tables.linetypes[ReservedHandles.dashedLinetype], isNull,
        reason: 'no record there: it draws continuous');
    expect(doc.tables.linetypes.byName('DASHED'), isNull);
    expect(c.dirty.value, isFalse);
    expect(c.canUndo.value, isFalse);
    expect(c.save(), file, reason: 'byte-identical');

    final other = architectureController();
    addTearDown(other.dispose);
    expect(other.document.tables.linetypes[ReservedHandles.dashedLinetype],
        dashed,
        reason: 'premise: a new plan has it');
    other.load(file);
    expect(other.document.tables.linetypes[ReservedHandles.dashedLinetype],
        isNull,
        reason: 'a load adds nothing');
    expect(other.save(), file);
  });
}
```

  4. Create `test/separator/separator_export_test.dart` (new; ids SP-export-png, SP-export-pdf):

```dart
// Appendix A D-30 (spec 3a C3.4, C6): the separator's type is not exported
// (today's exportOmitOwners, jet_cad_floor_plan/lib/src/export/
// export_bytes.dart:28-29), so plan.png and plan.pdf leave every separator
// out, through the real kit. 2a's X-3 pins the plumbing over a test kit
// (jet_cad_2d_plan/test/export/registry_test.dart:78-115); the PDF is read
// back as the app's export test read it (apps/floor_planner/test/export/
// export_flow_test.dart:115-127; export_flat.dart:198-210's toPdf and
// pdfDistanceToSegment, copied here over the page's own origin and scale).
import 'dart:io' show zlib;
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/export_testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ExportDpi, exportPagePdf, exportPagePng;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/editor_rig.dart';
import 'separator_plans.dart';

/// World [p] in the PDF's points, under [page] (its origin is the sheet's
/// lower-left corner).
Vector2 toPdf(PageComponent page, Vector2 p) {
  final k = 72 / 25.4 / page.scaleDenominator;
  return Vector2((p.x - page.originX) * k, (p.y - page.originY) * k);
}

/// The distance from [p] to the segment [a]-[b], in pt.
double pdfDistanceToSegment(PdfXY p, Vector2 a, Vector2 b) {
  final ab = b - a;
  final t =
      (((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / ab.length2).clamp(0.0, 1.0);
  final q = a + ab * t;
  return math.sqrt(math.pow(p.x - q.x, 2) + math.pow(p.y - q.y, 2));
}

/// The plan: a wall, and well clear of it a separator in a turned,
/// mirrored group, on a new plan's sheet.
PlanController exportPlan() {
  final c = PlanController(
      kits: [architectureKit], build: buildWallAndSeparator);
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets(
      'SP-export-png plan.png leaves the separator out: its bytes are the '
      'page drawn without it', (tester) async {
    final c = exportPlan();
    final doc = c.document;
    final seps = liveOf<SeparatorParams>(c, ArchitectureTypes.separator);
    expect(seps, hasLength(1), reason: 'premise');
    final page = doc.components.get<PageComponent>(doc.rootHandle)!;
    final without = (await tester.runAsync(() => exportPagePng(
        document: doc,
        page: page,
        dpi: ExportDpi.d96,
        omitOwners: seps.toSet())))!;
    final whole = (await tester.runAsync(
        () => exportPagePng(document: doc, page: page, dpi: ExportDpi.d96)))!;
    expect(without, isNot(whole),
        reason: 'premise: the separator is on the sheet');
    final got = (await tester.runAsync(() =>
        c.export('plan.png', const PlanExportChoice(dpi: PlanExportDpi.d96))))!;
    // M-SP-1 (exported) and M-SP-10 (omittedOf answering nothing).
    expect(got.bytes, without);
  });

  testWidgets(
      'SP-export-pdf plan.pdf leaves the separator out: no path vertex '
      'within 1 pt of it, where the page exported with nothing omitted has '
      'one; the wall is drawn', (tester) async {
    final c = exportPlan();
    final doc = c.document;
    final sep =
        liveOf<SeparatorParams>(c, ArchitectureTypes.separator).single;
    final page = doc.components.get<PageComponent>(doc.rootHandle)!;
    final (s, e) = separatorEnds(doc, sep);
    final a = toPdf(page, s), b = toPdf(page, e);
    bool onSeparator(PdfContent content) => [
          for (final p in content.paths)
            for (final sub in p.subpaths)
              for (final v in sub.vertices)
                if (pdfDistanceToSegment(v, a, b) < 1.0) v,
        ].isNotEmpty;

    final font = (await tester.runAsync(
        () => rootBundle.load('packages/jet_cad_2d_plan/lib/fonts/Roboto-Regular.ttf')))!;
    final all = (await tester.runAsync(() => exportPagePdf(
        document: doc,
        page: page,
        fontBytes: font.buffer.asUint8List())))!;
    expect(onSeparator(PdfContent.parse(all, inflate: zlib.decode)), isTrue,
        reason: 'premise: exported with nothing omitted, the separator '
            'plots where the check looks');

    final got = (await tester.runAsync(
        () => c.export('plan.pdf', PlanExportChoice.initial)))!;
    final content = PdfContent.parse(got.bytes, inflate: zlib.decode);
    // M-SP-1 and M-SP-10.
    expect(onSeparator(content), isFalse, reason: 'no path at the separator');
    expect(content.paths, isNotEmpty, reason: 'the wall is drawn');
  });
}
```

  (The font key is `kPlanFontAsset`'s value, `jet_cad_2d_plan/lib/src/fonts/plan_fonts.dart:21-22`; the constant itself is not exported.)

- [ ] **Step 7: Run them.** `cd packages/jet_cad_2d_integration && dart format . && flutter test --enable-vmservice test/separator`. Expected: `All tests passed!` (the kit's code is in from Step 4; the red runs of these tests are the mutations below). Any failure is a finding: quote it and stop.

- [ ] **Step 7b: `wall_grips_test` EG7, EG8 (carried from Task 12, R-P8).** Both need the door and the separator (`shadowDoc`, `packages/jet_cad_floor_plan/test/wall_grips_test.dart:155-218`), which this task completes. **Assertions unchanged**; split by R-P1 as Task 12 split EG1-EG6 (its ruling R12-3: the provider-direct lines in the kit, the rest over the editor).
  1. Kit, `packages/jet_cad_2d_kit_architecture/test/wall/wall_grips_test.dart` (Task 12's): add the imports `package:jet_cad_2d_kit_architecture/src/opening/opening.dart` and `package:jet_cad_2d_kit_architecture/src/separator/separator.dart`; after `addL`, copy `shadow`, `sep` (`:155`) and `shadowTip` (`:213-218`) unchanged, and `shadowDoc` (`:157-211`) with `gripDoc(FlutterTextMeasurer(), (doc) {` → `gripDoc((doc) {` (the kit's `gripDoc`: `wallDoc()` with the kit tests' system, so the door and the separator regenerate through `testCatalog()`, where Opening is registered after Wall and Separator after Opening, today's order). Append inside `main`: `test("EG8-k the corner drag's command and preview, the provider directly: the real walls only (a file's opening carrying WallParams on the joint, a separator carrying OpeningParams on B)", () {`, today's `:616-623` (the fixture and its premises), `final q = gridOf(plan(3500, -400));` (`:624`, the kit's `gridOf`), then `:626-639` with `WallGrips()` → `WallGrips(live: liveOf(doc))` and, above `:629` (`expect([for (final m in c.children) (m as dynamic).handle as Handle],`), the line `// ignore: avoid_dynamic_calls` (the kit's analysis options enable that lint, today's floor planner's do not; the assertion is unchanged), and `});`. `liveOf(doc)` (R-P17) names the shadow an opening and `sep` a separator, as the plan's live rule does.
  2. Integration, `packages/jet_cad_2d_integration/test/wall/wall_grips_test.dart` (Task 12's): after its `addL`, copy `shadow`, `sep`, `shadowTip` unchanged and `shadowDoc` as `PlanController shadowController({required bool dangling})`: `final ctrl = wallController(gripPlan((doc) { <today's :172-196, the L, the door and the separator> }));`, then today's `:198-210` (the strays written straight into the store, and EG7's dangling host) on `final doc = ctrl.document;`, before any pump (today's order, as Task 12 does for EG6), `return ctrl;`. Append EG7 (`:582-608`) and EG8 (`:611-653`) with A12-shell and Task 12's EG1-EG6 mapping (`final doc = shadowDoc(dangling: …);` → `final ctrl = shadowController(dangling: …); final doc = ctrl.document;`; `final view = await pumpGrips(tester, doc, lCorner);` → `await pumpEditor(tester, ctrl, centre: lCorner, scale: 0.15);`; `view` → `ctrl` in `selectWall` and `dragWorld`); EG8's provider-direct lines `:626-639` → `// The provider directly: EG8-k (the kit).` (R12-3). Every other line, the premises included, unchanged. The shadow's and `sep`'s stray components reach the controller's document after its load, as EG6's do; a different outcome there (an exception, a frozen object, a second undo step) is a finding: stop and report it.
  - Run `cd packages/jet_cad_2d_kit_architecture && flutter test test/wall/wall_grips_test.dart` and `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice test/wall/wall_grips_test.dart`: `All tests passed!`.

- [ ] **Step 8: Non-ASCII literals.** `grep -n "[^ -~]" packages/jet_cad_2d_integration/test/separator/separator_plans.dart packages/jet_cad_2d_kit_architecture/test/separator/separator_tool_test.dart` — the `×` and `°` in comments and today's header (`:1-12`) are literal characters, as in the source (`grep -n "[^ -~]" packages/jet_cad_floor_plan/test/separator_tool_test.dart`).

- [ ] **Step 9: The gates.** From the repository root:
  - `cd packages/jet_cad_2d_kit_architecture && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0.
  - `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .` — the same.
  - `dart run tool/ci/check_kit_deps.dart` — `kit dependencies: 2 package(s) checked, none names the plan library or another kit`.
  - `git status --short`: only this task's files.

- [ ] **Step 10: Commit.**

```bash
git add packages/jet_cad_2d_kit_architecture/lib/src/separator/separator_grips.dart packages/jet_cad_2d_kit_architecture/lib/src/separator/separator_tool.dart packages/jet_cad_2d_kit_architecture/lib/src/separator/separator_plan.dart packages/jet_cad_2d_kit_architecture/lib/src/kit.dart packages/jet_cad_2d_kit_architecture/CHANGELOG.md packages/jet_cad_2d_kit_architecture/test/separator/separator_tool_test.dart packages/jet_cad_2d_kit_architecture/test/separator/separator_plan_test.dart packages/jet_cad_2d_integration/test/separator/separator_plans.dart packages/jet_cad_2d_integration/test/separator/separator_shell_test.dart packages/jet_cad_2d_integration/test/separator/separator_dashed_test.dart packages/jet_cad_2d_integration/test/separator/separator_export_test.dart packages/jet_cad_2d_kit_architecture/test/wall/wall_grips_test.dart packages/jet_cad_2d_integration/test/wall/wall_grips_test.dart
```

  then:

```bash
git commit -m "$(cat <<'EOF'
feat(kit-architecture): the separator's grips, tool and plan type

The separator type is not exported; its two end grips and the Separator
tool (S) band-trim through the kit's one RoomInputs per document, with
the plan's object snap. The tool's tests are ported (its shell half onto
PlanEditor); new_document_test's DASHED lines come back over the plan, a
file without the record opens and saves back byte-identical, and PDF and
PNG exports leave separators out through the real kit.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 11: Mutation check** (committed files only; after each: run the named test, see it red, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0). Kit: `cd packages/jet_cad_2d_kit_architecture && flutter test <file>`; integration: `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice <file>`.
  - M-SP-1 `packages/jet_cad_2d_kit_architecture/lib/src/separator/separator_plan.dart`: delete `exported: false,` → SP-type, SP-export-png and SP-export-pdf red.
  - M-SP-2 `separator_plan.dart`: `objectSnap: () => s.objectSnap` → `objectSnap: () => true` → SP-grips red (F3 off).
  - M-SP-3 `separator_plan.dart`: `letter: 'S'` → `letter: 'X'` → SP-type red, and ST1 (editor) red (`S` activates nothing).
  - M-SP-4 `lib/src/kit.dart`: move `separatorPlanTool` to the front of `tools:` → SP-order red.
  - M-SP-5 `lib/src/separator/separator_tool.dart`: in `accept`, delete the first `inputs.invalidate();` (before the trim) → ST2 red (the wall added in the click's task is not trimmed to).
  - M-SP-6 `separator_tool.dart`: in `accept`, `objectSnap: _objectSnap(ctx)` → `objectSnap: true` → ST2 red (F3 off).
  - M-SP-7 `lib/src/separator/separator_grips.dart`: in `_moved`, `final kept = start ? ends.$2 : ends.$1;` → `final kept = start ? ends.$1 : ends.$2;` → SP-grips red (F3 on).
  - M-SP-9 `lib/src/kit.dart`: delete `prepare: ensureDashedLinetype,` → ND1, ND3 (integration) and ND2 (kit) red.
  - M-SP-8 (the plan library, Task 5's code) `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart`: in `load`, right after the `try` block that assigns `next = decodePlan(...)`, insert `for (final kit in kits.kits) { kit.prepare?.call(next); }` → SP-dashed-open red (the record appears; the save differs).
  - M-SP-10 (the plan library) `packages/jet_cad_2d_plan/lib/src/export/page_flows.dart`: in `omittedOf`, `if (_unexported.isEmpty) return const {};` → `return const {};` → SP-export-png and SP-export-pdf red.

  Quote each red line.

#### Assumed from earlier tasks

- Task 16: the names under "Consumes"; `room_fixture.dart`'s `buildPlan` installs a system over the kit tests' catalog with the separator registered (raw `SeparatorType`, Task 16's Step 3), and `liveOf`/`installParametric` as Task 16 settled them. `RoomInputs` is the `Disposable` `FakePlanServices.dispose()` disposes (Task 16's RR-shared).
- Task 10: `test/support/catalog.dart` declares `ParametricCatalog testCatalog()` and `installParametric` (ruling R-P13; Task 16 uses the same names).
- Tasks 11-15: the barrel exports `WallParams` and `Justification`; `architectureKit.tools` holds box, wall, door, window, gap in that order, and `.types` box, wall, opening.
- Task 5: `PlanController(build:)` runs `build` with the plan's system installed, then clears the history and takes the save point; a `json` plan is never prepared.
- Task 4: the status line is the tool's label alone with no selection and no notice.

#### Notes for later tasks

- Task 18 ports ST4 into this task's `test/separator/separator_tool_test.dart` (see "Interface problem" 1; Task 18's Step 3b) and `room_grips_test.dart` GR5 (the separator's grips with two rooms; GR5's shell half to the integration package over `separatorPlanType`'s grips through `plan.select`).
- Task 19 inserts `roomPlanTool` between `gapPlanTool` and `separatorPlanTool`; SP-order then holds the room's place too.
- Task 25 may point ND4's fixture at `sampleFlatController()` (R17-2).

#### Interface problem

1. **(Resolved in the reconcile: Task 18's Step 3b ports ST4.)** **ST4 needs the room type, which lands after this task.** ST4 (`separator_tool_test.dart:351-380`) adds a room (`addRoom`, `room_fixture.dart:567-588`), reads its label strings (`labelStrings`, `:700-702`) and lists rooms (`liveObjectsOf<RoomParams>`); `RoomParams`, `RoomType` and those helpers are Task 18's (Task 16 ports the room fixture "less its three `RoomParams` helpers, which Task 18 adds"). **Proposed fix:** Task 18 appends ST4 to `packages/jet_cad_2d_kit_architecture/test/separator/separator_tool_test.dart`, copying `:351-380` with today's `rooms` helper (`:87-88`, as `testCatalog().objectsOf<RoomParams>(doc)`) and `faceAt` as its fixture gives it, assertions unchanged.
2. **ND4's live case decodes the sample flat (Task 25).** **Fix taken here** (R17-2): a built plan of the same shape; no interface change. Listed so the controller can move the case to Task 25 instead if it prefers the real sample.

#### New shared name

- `packages/jet_cad_2d_integration/test/separator/separator_plans.dart`: test-local to this task's integration tests (`addWall`, `addSeparator`, `boxWalls`, `boxPlace`, `boxAt`, `groupFor`, `buildBox`, `buildWallAndSeparator`, `buildTenWalls`, `unpreparedKit`, `separatorEnds`, `dashed`). Task 18's GR5 shell half and Task 26's rows may import it; no other task must.

---

