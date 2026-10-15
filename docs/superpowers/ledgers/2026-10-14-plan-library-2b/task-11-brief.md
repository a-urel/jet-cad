### Task 11: The service session and the mode (spec S3 "Mode and copy", the copy's lock expander and failure boundary, "2a's members in service", "The members that switch on `mode`"; S5 controller rows 1-2)

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/service/service_session.dart` (`PlanMode`, `serviceCopyOf`, `ServiceSession`)
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` (the mode, the copy's lifetime, the members that switch on `mode`, `execute`, `deleteSelection`, `_requireDesign`, the copy's lock and damage callbacks)
- Modify: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (export `PlanMode`), `packages/jet_cad_2d_plan/test/barrel_test.dart` (ED-9 gains `PlanMode`)
- Create (test support): `packages/jet_cad_2d_plan/test/support/service_plans.dart` (Tasks 12 and 13 extend it)
- Test: `packages/jet_cad_2d_plan/test/service/service_session_test.dart` (SM-*), `packages/jet_cad_2d_plan/test/controller/mode_test.dart` (ported); `packages/jet_cad_2d_plan/test/controller/unit_colour_test.dart`, `unit_data_test.dart` and `unit_detail_test.dart` (Task 9's files) gain TC6, HD4 and TA3 (ported; Task 9 hands them here)

(Paths below are under `packages/jet_cad_2d_plan/`.)

**Interfaces:**
- Consumes:
  - Engine: `DraftDocumentCodec.encodeToString`, `DraftDocumentCodec.decodeString(…, permissions:, diagnostics:, keepUnreadableComponents:, registerComponents:)` (`jet_cad_2d/lib/src/codec/json_codec.dart:86`, `:164-172`); `DraftPermissions.runtime` (`document/command.dart:58-59`); `CommandDispatcher.notifyLoaded`, `clearHistory`, `stateId`, `canUndo`, `canRedo`, `undoDepth`, `isDisposed` (`document/undo.dart:261-285`); `ParametricSystem(document, catalog, isFrozen:)`, `install`, `dispose`; `PartialMutationError`.
  - Flutter layer: `SelectionController`, `SelectionKey.root`, `OutlineCache`, `SpatialIndex`, `PageNotifier`, `ToolContext` (`jet_cad_2d_flutter/lib/src/tool.dart:82-109`), `Tool` (`:116-157`), `ToolController` (`:159-189`), `FlutterTextMeasurer`, `CameraController`.
  - 2a: `LockSet`, `LockExpander` (`kits/locks.dart:28-226`; `onHookFailure`, `onPartialMutation`, `onRefusedEdit`, `onRetryFailed` at `:199-214`), `FailureBoundary` (`kits/guard.dart:574-763`), `DiagnosticsLog`, `DocumentSession` (`controller/session.dart:29-284`), `PlanController._registerComponents`, `_locked`, `_diagnostics`, `_refreshFlags`, `_unrestricted`, `_drop`, `_replace`, `_open` (`controller/plan_controller.dart:209-217`, `:518-542`, `:630-755`, `:765-806`).
  - Task 6: `UnitIndex`, `UnitIndexCache(document, {catalog, locks, locked})`, `UnitInfo` (Shared interfaces).
  - Task 7: `UnitLabelSystem(document)`, `install`, `dispose`; the stack parametric → labels → lock.
  - Task 9: the unit API and its private seams (see "Assumed from earlier tasks").
  - Task 5: `serviceFixture()` (through `hall()` in the support file; see "Assumed").
- Produces (Shared interfaces, Task 11):
  - `enum PlanMode { design, service }` (exported).
  - `final class ServiceSession` with `document`, `parametric`, `labels`, `lockExpander`, `boundary`, `index`, `page`, `selection`, `outlines`, `tools`, `units` (`UnitIndexCache`), `canUndo`, `canRedo`, `dispose()`; plus `measurer`, `toolContext`, `tool`, `history`, `onSelection`, `detach()`. Its one tool is a private idle placeholder (`_IdleTool`) until Task 14 builds the `ServiceTool` in the constructor and deletes the placeholder (controller ruling R-17: no `tool:` factory is created here).
  - `DraftDocument serviceCopyOf(DraftDocument design, {required void Function(ComponentRegistry) register, required TextMeasurer measurer})`.
  - On `PlanController`: `ValueListenable<PlanMode> get mode`; `void setMode(PlanMode next)`; `DraftDocument get activeDocument`; `SelectionController get activeSelection`; `@internal ServiceSession? get serviceSession`. `execute()` answers false in service; `undo`, `redo`, `canUndo`, `canRedo`, `export`, `print`, `revision`, `units`, `unitDetails`, `unitAt`, `unitIndex`, `select`, `selectedUnits` act on the active document.
  - `ValueListenable<Set<String>> get selectedUnits` (the Shared interfaces list it under Task 12, but spec S3 and this task re-point it, so it lands here over Task 9's private `_selectedUnits`; Task 12 consumes it).
  - Private seams Tasks 12 and 13 use: `_buildService()`, `_attachService(ServiceSession)`, `_dropService(ServiceSession)`, `_onServiceChanged()`; Task 9's `_select(Set<String>)`, `_refreshSelected()`, `_activeUnits` (a `UnitIndexCache`), `_expandLabels`, re-pointed here.

Plan decisions:
- **The copy is the design's text, decoded under `DraftPermissions.runtime`** (today's `_copyOf`, `jet_cad_floor_plan/lib/src/host/floor_plan_controller.dart:1305-1319`), with the controller's own registration (`_registerComponents`, which by Task 6 registers the unit components too) and `keepUnreadableComponents: true`, so a component E4 kept raw in the design is kept raw in the copy. No manifest check, no load probe: the design passed both.
- **The copy's systems** stack as the design's (Task 7): `ParametricSystem(copy, catalog, isFrozen: design.frozen.contains)` → `UnitLabelSystem(copy)` → `LockExpander(copy, design.locks)`; disposed in reverse. The frozen set and the lock set are the design session's objects themselves (spec S3: "the handles are the same in both documents").
- **The copy's boundary** is a `FailureBoundary` of its own (document = the copy, system = the copy's, frozen = the design's set, log = the controller's), wired to the copy's lock expander exactly as `_open` wires the design's (`plan_controller.dart:669-681`). Its `lock` callback is `_lockFromCopy(session, objects)`: the objects go into the design's `LockSet` (refreshed over the **design**, so the closure that catches a removal holds the design's handles, which the copy shares), the **copy's** history is cleared, `locked` and the flags are refreshed, the design's grips are told; the design's history is never touched (spec S3, B3 ruling in Risks). The callbacks take the session, so a copy being built (Task 13's restore) clears its own history, never the active one's.
- **A rollback that throws in the copy** (E3) is the copy's alone: `_damageCopy` calls `notifyLoaded()` on the copy (which clears its history, `undo.dart:261-266`), refreshes the flags and notifies; the design's `damaged` stays as it is (the design was not touched). The boundary logs `rollbackFailed` as in the design.
- **The tool:** until Task 14 the copy's tool controller holds an idle placeholder (`_IdleTool`, name `plan.service`): it reacts to nothing. `ToolController` needs an initial tool (`jet_cad_2d_flutter/lib/src/tool.dart:159-163`) and the service tool needs Task 12's groups, so the placeholder is the one temporary piece; Task 14 builds `ServiceTool` in the constructor and deletes `_IdleTool` (controller ruling R-17). There is no `tool:` factory.
- **`deleteSelection` answers false in service** (today's `floor_plan_controller.dart:708-709`): the design is not edited in service, as `execute` (spec S3).
- **The design's tool is reset to `plan.select` on entering service** (today's `toolChanged(FloorPlanTool.select)`, `floor_plan_controller.dart:1279-1281`), so a shape part-way is cancelled and `undo` in service is never held back by a design tool (`_midShape` is consulted in design only, today's `_editorMidShape`, `:1082-1083`).
- **The camera is not reframed on a switch here**: today's `_reframe` moves it by the two views' chrome (`floor_plan_controller.dart:1272-1277`); the chrome is Task 16's (`PlanServiceView`).
- **`_unrestricted` takes the dispatcher it lifts** (`_unrestricted(CommandDispatcher commands, void Function() step)`): `undo`/`redo` pass the active document's, `reportLocale` the design's (it settles the design's separator even in service).

- [ ] **Step 1: The test support.** Create `test/support/service_plans.dart`:

```dart
// Plans for the service-mode tests (2b Tasks 11-13). A placed unit is built
// by engine commands, independent of any symbol library: a definition
// carrying `jetcad.symbol` and `jetcad.unit` with one closed leaf off the
// origin, and an instance carrying its UNIT label (`unitLabelAttrib`, Task
// 3). Every placement is off the origin, turned, most mirrored (CLAUDE.md).
// The helpers are today's (jet_cad_floor_plan's
// test/host/controller_test.dart:26-79): `move`, `drawLine`, `parts`.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart'
    show placementTransform;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'harness.dart';
import 'service_fixture.dart' show serviceFixture;
import 'test_kit.dart';
import 'unit_fixtures.dart' show addLayer, kDeg37;

// One owner per helper (controller ruling R-19): `kDeg37` and `addLayer`
// are the units' fixture's (Tasks 6 and 8), re-exported for Tasks 11-13.
export 'unit_fixtures.dart' show addLayer, kDeg37;

/// A unit definition made by [unitDefinition]: its handle, its base point
/// and its first leaf's box (the served top).
typedef UnitDef = ({Handle handle, Vector2 base, Aabb2 top});

/// The table's leaf: a closed 1200 x 800 rectangle off the origin; the base
/// point is its box's centre.
final List<Vector2> tableOutline = [
  Vector2(50, 30),
  Vector2(1250, 30),
  Vector2(1250, 830),
  Vector2(50, 830),
];

/// The table's base point, the centre of [tableOutline]'s box.
final Vector2 tableBase = Vector2(650, 430);

/// Adds a symbol definition keyed [key] (version 1) to [d], one closed
/// leaf (a rectangle, or a circle when [round]); with [unit], a
/// `jetcad.unit` of [kind], [capacity] and [labelling].
UnitDef unitDefinition(DraftDocument d,
    {required String key,
    String name = 'Table',
    String kind = UnitKinds.table,
    int capacity = 4,
    UnitLabelling labelling = UnitLabelling.numbered,
    bool unit = true,
    bool round = false}) {
  final def = d.handleSeed.next();
  final leaf = d.handleSeed.next();
  final base = round ? Vector2(300, 260) : tableBase;
  final top = round
      ? Aabb2.fromPoints([Vector2(50, 10), Vector2(550, 510)])
      : Aabb2.fromPoints(tableOutline);
  d.commands.execute(CompoundCommand([
    AddDefinitionCommand(Definition(
        handle: def,
        name: '$key@1',
        basePoint: base,
        children: const [])),
    SetComponentCommand<SymbolComponent>(
        def,
        SymbolComponent(
            key: key,
            version: 1,
            name: name,
            category: 'Service',
            tags: const ['service'])),
    if (unit)
      SetComponentCommand<UnitComponent>(
          def,
          UnitComponent(
              kind: kind, capacity: capacity, labelling: labelling)),
    AddEntityCommand(
        record: draftRecord(
            leaf, def, round ? EntityKind.circle : EntityKind.polyline,
            layer: ReservedHandles.layerZero),
        payload: round
            ? circlePayload(Vector2(300, 260), 250)
            : polylinePayload(tableOutline, closed: true)),
  ], label: 'Add definition'));
  return (handle: def, base: base, top: top);
}

/// Places [def] at [at] on [layer] (layer 0 by default), with a UNIT label
/// reading [label] when one is given (the shape the placer writes: layer
/// 0, BYBLOCK, centred, upright in the world); the instance's handle.
Handle placeDef(DraftDocument d, UnitDef def, Transform2 at,
    {String? label, Handle? layer}) {
  final instance = d.handleSeed.next();
  final commands = <DraftCommand>[
    AddNodeCommand(InstanceNode(
        handle: instance,
        parent: d.rootHandle,
        definition: def.handle,
        layer: layer ?? ReservedHandles.layerZero,
        transform: at)),
  ];
  if (label != null) {
    final a = unitLabelAttrib(label,
        instanceToWorld: at, anchor: def.base, top: def.top);
    commands.add(AddEntityCommand(
        record: EntityRecord(
            handle: d.handleSeed.next(),
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
            text: a.text,
            tag: a.tag,
            textAttrs: a.textAttrs),
        payload: a.payload));
  }
  d.commands.execute(CompoundCommand(commands, label: 'Place unit'));
  return instance;
}

/// A placement whose [def]'s base point lands at ([x], [y]), turned by
/// [angle] (radians), mirrored when [mirrored].
Transform2 turned(UnitDef def, double x, double y, double angle,
        {bool mirrored = false}) =>
    Transform2.translation(x, y)
        .multiply(Transform2.rotation(angle))
        .multiply(Transform2.scale(mirrored ? -1 : 1, 1))
        .multiply(Transform2.translation(-def.base.x, -def.base.y));

/// Today's `planJson` (controller_test.dart:26-43), saved: tables 1
/// (a quarter turn, mirrored) and 2, a stool 3 (capacity 1, half-turned)
/// and a planter (a symbol that is no unit). [duplicate] labels the stool
/// "2"; [secondAt] moves table 2.
String servicePlanText({bool duplicate = false, Vector2? secondAt}) =>
    planText([testKit()], (d) {
      final table = unitDefinition(d, key: 'test.table.square.four');
      final stool = unitDefinition(d,
          key: 'test.stool.round.one',
          name: 'Stool',
          capacity: 1,
          round: true);
      final planter = unitDefinition(d,
          key: 'test.planter.square.one', name: 'Planter', unit: false);
      placeDef(
          d,
          table,
          placementTransform(
              at: Vector2(-2600, 1400),
              basePoint: table.base,
              quarterTurns: 1,
              mirrored: true),
          label: '1');
      placeDef(
          d,
          table,
          placementTransform(
              at: secondAt ?? Vector2(2300, 1400), basePoint: table.base),
          label: '2');
      placeDef(
          d,
          stool,
          placementTransform(
              at: Vector2(300, -2100),
              basePoint: stool.base,
              quarterTurns: 2),
          label: duplicate ? '2' : '3');
      placeDef(d, planter,
          placementTransform(at: Vector2(4100, -900), basePoint: planter.base));
    });

/// A saved plan with tables 1 and 2 of the test kit and a table 5 whose
/// symbol's kit (`gone`) the host does not load: locked (spec S2 "Locked
/// units").
String lockedPlanText() => planText([testKit()], (d) {
      final table = unitDefinition(d, key: 'test.table.square.four');
      final gone = unitDefinition(d, key: 'gone.table.square.four');
      placeDef(d, table, turned(table, -2600.25, 1400.5, kDeg37, mirrored: true),
          label: '1');
      placeDef(d, table, turned(table, 2300.75, 1700.25, -kDeg37), label: '2');
      placeDef(d, gone, turned(gone, 5100.5, -900.75, kDeg37 * 2), label: '5');
    });

/// [instance]'s UNIT label entity: the lowest handle, as `UnitIndex` reads
/// it; null when it has none.
Handle? labelEntityOf(DraftDocument d, Handle instance) {
  Handle? lowest;
  final e = d.entities;
  for (final slot in e.liveSlots) {
    if (e.ownerAt(slot) != instance) continue;
    if (e.kindAt(slot) != EntityKind.attrib || e.tagAt(slot) != kUnitLabelTag) {
      continue;
    }
    final h = e.handleAt(slot);
    if (lowest == null || h.value < lowest.value) lowest = h;
  }
  return lowest;
}

/// [instance]'s label, trimmed; null when it has none or an empty one.
String? labelOf(DraftDocument d, Handle instance) {
  final h = labelEntityOf(d, instance);
  if (h == null) return null;
  final text = d.entities.textAt(d.entities.slotOf(h)!).trim();
  return text.isEmpty ? null : text;
}

/// The root-level instances of [d] labelled [label], ascending.
List<InstanceNode> unitNodes(DraftDocument d, String label) => [
      for (final n in d.tree.nodes)
        if (n is InstanceNode &&
            n.parent == d.rootHandle &&
            labelOf(d, n.handle) == label)
          n,
    ]..sort((a, b) => a.handle.value.compareTo(b.handle.value));

/// The one root-level instance of [d] labelled [label] (today's
/// `tableNode`).
InstanceNode unitNode(DraftDocument d, String label) =>
    unitNodes(d, label).single;

List<double> parts(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

/// A move of the unit labelled [label] in the active document (a service
/// move in service, a design edit in design): one step.
void move(PlanController c, String label, double dx, double dy) {
  final node = unitNode(c.activeDocument, label);
  c.activeDocument.commands.execute(CompoundCommand([
    TransformNodeCommand(
        node.handle, Transform2.translation(dx, dy).multiply(node.transform))
  ], label: 'Move'));
}

/// An edit of the active document: a line on layer 0 (refused by the
/// copy's runtime permissions).
void drawLine(PlanController c) =>
    addLine(c.activeDocument, Vector2(-500, 700), Vector2(1800, 2400));

/// Task 5's service fixture as these tests read it (a plan over
/// `unitKit()`): the plan text, the placed table (labelled `12`, turned and
/// mirrored), the two rows (A, six seats, turned; B, five seats, curved)
/// and each row's seats ascending by handle (`A1…`, `B1…`).
({String json, Handle table, List<Handle> rows, List<List<Handle>> seats})
    hall() {
  final f = serviceFixture();
  return (
    json: f.json,
    table: f.table,
    rows: [f.rowA, f.rowB],
    seats: [f.seatsA, f.seatsB],
  );
}
```

  `hall()` is the only place that reads Task 5's `serviceFixture()` (`test/support/service_fixture.dart`). Task 5's `ServiceFixture` record holds `json`, `table`, `rowA`, `seatsA`, `rowB`, `seatsB` (its Step 4), as the body reads them. A controller over `hall().json` loads `unitKit()` (Task 5: the test kit with its unit library and `test.row`).

- [ ] **Step 2: Write the failing tests (new).** Create `test/service/service_session_test.dart`:

```dart
// Spec 2b S3 "Mode and copy": the service copy in a ServiceSession of its
// own, with its own lock expander over the design's lock set and its own
// failure boundary (its freeze clears the copy's history only, then
// retries once); which members stay on the design and which switch on
// `mode`; execute and the design writes refused in service; the copy's
// lifetime.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

// box_kit.dart and test_kit.dart both declare `addObject` and `DiscType`;
// box_kit.dart and harness.dart both declare `addLine`: only what is used
// is shown.
import '../support/box_kit.dart'
    show Switches, SquareParams, DiscParams, boxKit, ringKit, addObject,
        atSquare, nearSquare;
import '../support/harness.dart' show controllerFor;
import '../support/recording_exporters.dart';
import '../support/service_plans.dart';
import '../support/test_kit.dart' show testKit, unitKit;

List<KitDiagnostic> failuresOf(PlanController c) => [
      for (final d in c.diagnostics.value)
        if (d.code == KitDiagnosticCode.hookFailed) d
    ];

Transform2 transformOf(DraftDocument d, Handle h) => switch (d.tree[h]) {
      final InstanceNode n => n.transform,
      final GroupNode n => n.transform,
      _ => throw StateError('no node ${h.toHex()}'),
    };

void main() {
  testWidgets(
      'SM-members document, selection, index, page, outlines, parametric, '
      'frozen and the kits\' services stay on the design in service; '
      'activeDocument and activeSelection are the copy\'s, runtime, with '
      'the design\'s handles; back in design both are the design\'s',
      (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    final design = c.document;
    final selection = c.selection;
    final index = c.index;
    final page = c.page;
    final outlines = c.outlines;
    final parametric = c.parametric;
    final frozen = c.frozen;
    expect(c.mode.value, PlanMode.design);
    expect(c.activeDocument, same(design));
    expect(c.activeSelection, same(selection));
    expect(c.serviceSession, isNull);

    c.setMode(PlanMode.service);
    expect(c.mode.value, PlanMode.service);
    final s = c.serviceSession!;
    // M-SM3: `document` reads the active document.
    expect(c.document, same(design));
    expect(c.selection, same(selection));
    expect(c.index, same(index));
    expect(c.page, same(page));
    expect(c.outlines, same(outlines));
    expect(c.parametric, same(parametric));
    expect(c.frozen, same(frozen));
    expect(c.servicesOf('test').document, same(design));
    expect(c.activeDocument, same(s.document));
    expect(c.activeDocument, isNot(same(design)));
    expect(c.activeSelection, same(s.selection));
    expect(c.activeSelection, isNot(same(selection)));
    expect(s.document.commands.permissions, DraftPermissions.runtime);
    for (final label in ['1', '2', '3']) {
      expect(unitNode(s.document, label).handle,
          unitNode(design, label).handle,
          reason: 'the copy keeps the design\'s handles');
    }
    expect(c.unitIndex.units.map((u) => u.instance),
        [for (final l in ['1', '2', '3']) unitNode(design, l).handle],
        reason: 'the unit index is the copy\'s, ascending');

    c.setMode(PlanMode.design);
    expect(c.serviceSession, isNull);
    expect(c.activeDocument, same(design));
    expect(c.activeSelection, same(selection));
    await tester.pump();
  });

  testWidgets(
      'SM-lifetime a load and a new plan in service rebuild the copy from '
      'the new design; leaving service drops it; each dropped copy is '
      'disposed after the frame, its systems uninstalled', (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.setMode(PlanMode.service);
    final first = c.serviceSession!;
    c.load(servicePlanText(secondAt: Vector2(5000.5, -3700.25)));
    expect(c.mode.value, PlanMode.service);
    final second = c.serviceSession!;
    expect(second, isNot(same(first)));
    expect(parts(unitNode(c.activeDocument, '2').transform),
        parts(unitNode(c.document, '2').transform),
        reason: 'the copy of the new design');
    c.newPlan();
    final third = c.serviceSession!;
    expect(third, isNot(same(second)));
    expect(c.unitIndex.units, isEmpty);
    c.setMode(PlanMode.design);
    expect(c.serviceSession, isNull);
    await tester.pump();
    for (final s in [first, second, third]) {
      // M-SM10: a dropped copy is never disposed.
      expect(() => s.selection.addListener(() {}), throwsFlutterError);
      expect(s.document.commands.isDisposed, isTrue);
      expect(s.document.commands.expander, isNull,
          reason: 'the lock, label and parametric systems, last in first out');
    }
  });

  testWidgets(
      'SM-select the selection is kept by label across a mode switch; '
      'design selects placed units only, service a seat too; '
      'editorSelectedUnits is empty in service', (tester) async {
    final h = hall();
    final c = controllerFor(kits: [unitKit()], json: h.json);
    final seat = h.seats[0][1];
    final seatLabel = labelOf(c.document, seat)!;
    final tableLabel = labelOf(c.document, h.table)!;
    c.select({tableLabel, seatLabel});
    expect(c.activeSelection.keys, {SelectionKey.root(h.table)},
        reason: 'design: placed units only');
    expect(c.selectedUnits.value, {tableLabel});
    expect(c.editorSelectedUnits.value, {tableLabel});

    c.setMode(PlanMode.service);
    // M-SM9: setMode does not select again by label.
    expect(c.activeSelection.keys, {SelectionKey.root(h.table)});
    expect(c.selectedUnits.value, {tableLabel});
    // M-SM8: `_inDesign` does not follow the mode.
    expect(c.editorSelectedUnits.value, isEmpty, reason: 'service');
    c.select({tableLabel, seatLabel, 'nope'});
    expect(c.activeSelection.keys,
        {SelectionKey.root(h.table), SelectionKey.root(seat)});
    expect(c.selectedUnits.value, {tableLabel, seatLabel});
    expect(c.selection.keys, {SelectionKey.root(h.table)},
        reason: 'the design\'s selection is untouched in service');

    c.setMode(PlanMode.design);
    expect(c.selectedUnits.value, {tableLabel},
        reason: 'the seat is not selectable in design');
    expect(c.selection.keys, {SelectionKey.root(h.table)});
    expect(c.editorSelectedUnits.value, {tableLabel});
    await tester.pump();
  });

  testWidgets(
      'SM-undo undo, redo, canUndo and canRedo act on the copy in service '
      'and on the design in design; a service undo never reaches the '
      'design', (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    drawLine(c);
    await tester.pump();
    expect(c.canUndo.value, isTrue, reason: 'premise: a design step');
    c.setMode(PlanMode.service);
    // M-SM12: the flags read the design.
    expect(c.canUndo.value, isFalse, reason: 'the copy has no history');
    final designed = parts(unitNode(c.activeDocument, '1').transform);
    move(c, '1', 333.5, -71.25);
    await tester.pump();
    expect(c.canUndo.value, isTrue);
    // M-SM11: undo acts on the design.
    c.undo();
    expect(parts(unitNode(c.activeDocument, '1').transform), designed);
    await tester.pump();
    expect(c.canUndo.value, isFalse);
    expect(c.canRedo.value, isTrue);
    c.redo();
    expect(parts(unitNode(c.activeDocument, '1').transform),
        isNot(designed));
    expect(c.document.commands.undoDepth, 1, reason: 'the design untouched');
    expect(c.document.commands.canRedo, isFalse);
    c.setMode(PlanMode.design);
    expect(c.canUndo.value, isTrue);
    expect(c.canRedo.value, isFalse);
    await tester.pump();
  });

  testWidgets(
      'SM-execute-false in service execute answers false and leaves the '
      'design as it was; deleteSelection answers false; the design writes '
      'throw StateError; back in design execute applies', (tester) async {
    final c = controllerFor(kits: [testKit()], json: servicePlanText());
    c.select({'1'});
    expect(c.selection.keys, hasLength(1), reason: 'premise');
    c.setMode(PlanMode.service);
    final state = c.document.commands.stateId;
    final before = c.save();
    // M-SM1: execute does not check the mode.
    expect(
        c.execute(addDrafted(c.document, EntityKind.line,
            linePayload(Vector2(-500.5, 700.25), Vector2(1800.75, 2400.5)),
            layer: ReservedHandles.layerZero)),
        isFalse);
    expect(c.document.commands.stateId, state);
    expect(c.dirty.value, isFalse);
    // M-SM14: deleteSelection does not check the mode.
    expect(c.deleteSelection(), isFalse);
    expect(c.save(), before, reason: 'table 1 is still in the design');
    // M-SM2: `_requireDesign` lets the write through.
    expect(() => c.setUnitData('1', const {'seat': 'window'}),
        throwsStateError);
    expect(() => c.setUnitColour('1', PlanSwatch.teal), throwsStateError);
    expect(() => c.setUnitLabel('1', '7'), throwsStateError);
    c.setMode(PlanMode.design);
    expect(
        c.execute(addDrafted(c.document, EntityKind.line,
            linePayload(Vector2(-500.5, 700.25), Vector2(1800.75, 2400.5)),
            layer: ReservedHandles.layerZero)),
        isTrue);
    await tester.pump();
  });

  testWidgets(
      'SM-export in service an export is handed the copy as it is; in '
      'design the design', (tester) async {
    final acme = RecordingExporter('acme.json', 'json', 'application/json');
    final c = PlanController(
        kits: [testKit()], json: servicePlanText(), exporters: [acme]);
    addTearDown(c.dispose);
    c.setMode(PlanMode.service);
    move(c, '1', 750.5, -250.25);
    final copy = DraftDocumentCodec.encodeToString(c.activeDocument);
    final design = DraftDocumentCodec.encodeToString(c.document);
    expect(copy, isNot(design), reason: 'premise: a service move');
    await tester.runAsync(
        () => c.export('acme.json', PlanExportChoice.initial));
    // M-SM13: the page flows read the design.
    expect(acme.seen.single, copy);
    c.setMode(PlanMode.design);
    await tester.runAsync(
        () => c.export('acme.json', PlanExportChoice.initial));
    expect(acme.seen.last, design);
  });

  testWidgets(
      'SM-copy-lock the copy refuses a forged command under a locked '
      'object (a table of a missing kit), rolled back, nothing in its '
      'history; an unlocked table moves', (tester) async {
    final c = controllerFor(kits: [testKit()], json: lockedPlanText());
    final gone = unitNode(c.document, '5').handle;
    expect(c.isLocked(gone), isTrue, reason: 'premise: the design locks it');
    c.setMode(PlanMode.service);
    final copy = c.activeDocument;
    final before = DraftDocumentCodec.encodeToString(copy);
    final at = transformOf(copy, gone);
    // M-SM4: the copy's lock expander is not installed.
    expect(
        () => copy.commands.execute(TransformNodeCommand(
            gone, Transform2.translation(410.5, -95.25).multiply(at))),
        throwsA(isA<PlanLocked>()));
    expect(DraftDocumentCodec.encodeToString(copy), before,
        reason: 'rolled back');
    expect(copy.commands.canUndo, isFalse);
    expect(() => move(c, '1', 410.5, -95.25), returnsNormally);
    await tester.pump();
  });

  testWidgets(
      'SM-copy-boundary a kit hook throwing during a service move: the '
      'object frozen and locked in both documents, one diagnostic, the '
      'copy\'s history cleared and the design\'s kept, the move applied by '
      'the retry; a second type throwing on the retry refuses the move',
      (tester) async {
    final sw = Switches();
    final c = controllerFor(kits: [boxKit(sw), ringKit(sw)]);
    final d = c.document;
    final square =
        addObject(d, atSquare, const SquareParams(side: 1200, poisoned: true));
    final table = unitDefinition(d, key: 'box.table.square.four');
    final t = placeDef(d, table, turned(table, -2600.25, 1400.5, kDeg37,
        mirrored: true), label: '1');
    await tester.pump();
    expect(c.canUndo.value, isTrue, reason: 'premise: the design has history');

    c.setMode(PlanMode.service);
    final copy = c.activeDocument;
    move(c, '1', 120.5, 0);
    expect(copy.commands.undoDepth, 1, reason: 'premise: a first step');
    sw.failing.add('reach');
    final at = transformOf(copy, t);
    final to = Transform2.translation(750.5, -250.25).multiply(at);
    copy.commands.execute(TransformNodeCommand(t, to));
    expect(parts(transformOf(copy, t)), parts(to), reason: 'the retry');
    // M-SM6: `_lockFromCopy` does not add to the lock set.
    expect(c.locked.value, {square});
    // M-SM7: the copy's system ignores the shared frozen set.
    expect(c.frozen, {square});
    final failures = failuresOf(c);
    expect(failures, hasLength(1));
    expect((failures.single.kitId, failures.single.subject),
        ('box', SquareParams.id));
    // M-SM5: the lock clears the design's history instead of the copy's.
    expect(copy.commands.undoDepth, 1,
        reason: 'the copy\'s history cleared, then the retried move');
    expect(c.document.commands.canUndo, isTrue,
        reason: 'the design\'s history is kept');
    final sq = transformOf(copy, square);
    expect(
        () => copy.commands.execute(TransformNodeCommand(
            square, Transform2.translation(10.5, 0).multiply(sq))),
        throwsA(isA<PlanLocked>()),
        reason: 'locked in the copy');

    c.setMode(PlanMode.design);
    expect(c.canUndo.value, isTrue);
    expect(
        c.execute(TransformNodeCommand(
            square,
            Transform2.translation(10.5, 0)
                .multiply(transformOf(c.document, square)))),
        isFalse,
        reason: 'locked in the design');
    expect(c.lockHint.value, isTrue);

    // A second type's hook throws on the retry: the move is refused.
    final sw2 = Switches();
    final c2 = controllerFor(kits: [boxKit(sw2), ringKit(sw2)]);
    final d2 = c2.document;
    final square2 =
        addObject(d2, atSquare, const SquareParams(side: 1200, poisoned: true));
    final disc = addObject(d2, nearSquare(-3000.5, 2500.25, 0.5),
        const DiscParams(radius: 400, poisoned: true));
    expect(square2.value < disc.value, isTrue,
        reason: 'premise: the square is surveyed first');
    final table2 = unitDefinition(d2, key: 'box.table.square.four');
    final t2 = placeDef(
        d2, table2, turned(table2, 2300.75, -1700.5, -kDeg37), label: '1');
    c2.setMode(PlanMode.service);
    final copy2 = c2.activeDocument;
    final before = DraftDocumentCodec.encodeToString(copy2);
    sw2.failing.add('reach');
    expect(
        () => copy2.commands.execute(TransformNodeCommand(t2,
            Transform2.translation(640.375, 12.5).multiply(transformOf(copy2, t2)))),
        throwsA(isA<KitHookFailure>()));
    expect(DraftDocumentCodec.encodeToString(copy2), before,
        reason: 'refused: nothing applied');
    expect(c2.frozen, {square2},
        reason: 'the first type froze; the second failed on the retry');
    expect(copy2.commands.canUndo, isFalse);
    await tester.pump();
  });
}
```

- [ ] **Step 3: Port the mode tests.** Create `test/controller/mode_test.dart` from `jet_cad_floor_plan/test/host/controller_test.dart`: C3 (`:143-155`), C4 (`:157-166`), C5 (`:168-184`), C8 (`:213-233`; 2a ported only its design half, as its C3, `test/controller/plan_controller_test.dart:67-84`; the whole test is ported here) and CD1 (`:304-328`). **Assertions unchanged.** Adaptations, all fixtures, names and imports:
  - ids: `MD-C3`, `MD-C4`, `MD-C5`, `MD-C8`, `MD-CD1`, each name keeping today's, "the selection mode" read as "service";
  - `FloorPlanController(json:)` → `controllerFor(kits: [testKit()], json:)`; `planJson()` → `servicePlanText()`; `tableNode` → `unitNode`; `FloorPlanMode.selection` → `PlanMode.service`; `selectedTables` → `selectedUnits`; `placementAt(5000, -3700, 0)` → `placementTransform(at: Vector2(5000, -3700), basePoint: tableBase)`;
  - CD1: `embedding.embeddingPlanJson()` → `servicePlanText()`; the designed centre is `unitNode(c.document, '1').transform.transformPoint(tableBase)` (the box's centre is the base point); `tableDetails` → `unitDetails`; `.table.number` → `.unit.label`.
  - **TC6** (`host/table_color_test.dart:309-338`, "in the selection mode setTableColor and setTablesColor throw a StateError, the design untouched; the service copy reads the design's colour"), which Task 9 sends here (it needs the mode), is appended to Task 9's `test/controller/unit_colour_test.dart` over that file's `controller` and `detailsOf`: `FloorPlanMode.selection` → `PlanMode.service`; `setTableColor` → `setUnitColour`, `setTablesColor` → `setUnitsColour`, `setTableData` → `setUnitData`; `purple`, `teal` → `PlanSwatch.purple`, `PlanSwatch.teal`; `designJson()` → `save()`; `.color` → `.colour`. Its two expected messages name the renamed methods (`'setUnitColour needs the design mode (P-5)'`, `'setUnitData needs the design mode (P-5)'`): a name inside an expected text follows the rename (controller ruling R-13's extension of 2a's ruling); every other assertion unchanged. Mutation: M-SM2 (`_requireDesign`'s body emptied) turns it red too.
  - **HD4** (`host/table_data_test.dart:170-190`, "in the selection mode both throw a StateError; the design and the copy are untouched"), which Task 9 sends here, is appended to Task 9's `test/controller/unit_data_test.dart` over that file's `controller`, `detailsOf` and `hostData`: `FloorPlanMode.selection` → `PlanMode.service`; `setTableData` → `setUnitData`, `setTablesData` → `setUnitsData`; `tableDetails` → `unitDetails`; `designJson()` → `save()`. Assertions unchanged. Mutation: M-SM2 turns it red.
  - **TA3** (`host/table_detail_test.dart:504-533`, "tableAt follows the camera and the mode: a service move is found at the table's new place in the selection mode, at its old one after switching back"), which Task 9 sent to Task 14 for "the service tool's move", lands here: the move is a `TransformNodeCommand` executed on the copy (`:522-525`), no tool, so the mode is all it needs. Appended to Task 9's `test/controller/unit_detail_test.dart` over that file's `embeddingController`, `fixtureTable` and `canvasAt`: `c.tableAt` → `c.unitAt`; `c.cameraController` → `c.camera`; `FloorPlanMode` → `PlanMode` (`selection` → `service`); `TableSurvey.of(d).withNumber('1')` → `c.unitIndex.withLabel('1')` (the active document's, Task 9). Assertions unchanged. Mutation M-SM15 (Step 12): `UnitIndexCache get _activeUnits => _service?.units ?? _session.units;` → `UnitIndexCache get _activeUnits => _session.units;` → TA3 red (the move is not found in service).

```dart
// jet_cad_floor_plan's test/host/controller_test.dart C3, C4, C5, C8 and
// CD1, the service halves, assertions unchanged (spec 2b S3, A12): the
// copy, its permissions, a load in service, a refused load in service,
// unitDetails following the active document.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart'
    show placementTransform;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/service_plans.dart';
import '../support/test_kit.dart';

PlanController controller(String json) =>
    controllerFor(kits: [testKit()], json: json);

void main() {
  testWidgets(
      'MD-C3 leaving service discards the copy; re-entering shows the design '
      '(C3, M-14b2-2)', (tester) async {
    final c = controller(servicePlanText());
    final designed = parts(unitNode(c.activeDocument, '1').transform);
    c.setMode(PlanMode.service);
    move(c, '1', 750, -250);
    expect(parts(unitNode(c.activeDocument, '1').transform), isNot(designed));
    c.setMode(PlanMode.design);
    c.setMode(PlanMode.service);
    expect(parts(unitNode(c.activeDocument, '1').transform), designed);
    await tester.pump();
  });

  testWidgets('MD-C4 the copy refuses geometry and structure (C4, M-14b2-6)',
      (tester) async {
    final c = controller(servicePlanText());
    c.setMode(PlanMode.service);
    expect(c.activeDocument.commands.permissions, DraftPermissions.runtime);
    expect(() => drawLine(c), throwsA(isA<PermissionDeniedError>()));
    expect(() => move(c, '3', 10, 10), returnsNormally,
        reason: 'a move is a transform');
    await tester.pump();
  });

  testWidgets(
      'MD-C5 load clears the selection and rebuilds the copy from the new '
      'plan (C5, M-14b2-3)', (tester) async {
    final c = controller(servicePlanText());
    c.setMode(PlanMode.service);
    c.select({'1', '2'});
    expect(c.selectedUnits.value, {'1', '2'});
    move(c, '2', 900, 900);
    // The same plan, table 2 elsewhere: same handles, same labels.
    c.load(servicePlanText(secondAt: Vector2(5000, -3700)));
    expect(c.mode.value, PlanMode.service);
    expect(c.selectedUnits.value, isEmpty);
    final placed =
        placementTransform(at: Vector2(5000, -3700), basePoint: tableBase);
    expect(parts(unitNode(c.activeDocument, '2').transform), parts(placed));
    expect(c.dirty.value, isFalse);
    await tester.pump();
  });

  testWidgets(
      'MD-C8 a bad plan changes nothing in service: broken structure, '
      'unknown schema (C8, M-14b2-8)', (tester) async {
    final c = controller(servicePlanText());
    c.setMode(PlanMode.service);
    c.select({'3'});
    move(c, '3', -300, 200);
    final moved = parts(unitNode(c.activeDocument, '3').transform);
    final document = c.activeDocument;
    final good = jsonDecode(servicePlanText()) as Map<String, Object?>;
    final broken = jsonEncode({...good, 'entities': 7});
    final future = jsonEncode({...good, 'schemaVersion': 9999});
    for (final bad in [broken, future, '{}']) {
      expect(() => c.load(bad), throwsFormatException, reason: bad);
    }
    expect(c.activeDocument, same(document));
    expect(c.mode.value, PlanMode.service);
    expect(c.selectedUnits.value, {'3'});
    expect(parts(unitNode(c.activeDocument, '3').transform), moved);
    await tester.pump();
  });

  testWidgets(
      'MD-CD1 a service move changes unitDetails in service, and not the '
      'design\'s: back in design the unit is where it was designed (CD1, '
      'M-H4)', (tester) async {
    final c = controller(servicePlanText());
    final designed =
        unitNode(c.document, '1').transform.transformPoint(tableBase);
    double x() => c.unitDetails.first.center!.dx;
    double y() => c.unitDetails.first.center!.dy;
    expect(c.unitDetails.first.unit.label, '1', reason: 'premise');
    expect(x(), closeTo(designed.x, 1e-12 * designed.x.abs()));

    c.setMode(PlanMode.service);
    move(c, '1', 750, -250);
    await tester.pump();
    expect(x(), closeTo(designed.x + 750, 1e-12 * designed.x.abs()));
    expect(y(), closeTo(designed.y - 250, 1e-12 * designed.y.abs()));

    c.setMode(PlanMode.design);
    await tester.pump();
    expect(x(), closeTo(designed.x, 1e-12 * designed.x.abs()));
    expect(y(), closeTo(designed.y, 1e-12 * designed.y.abs()));
  });
}
```

  Not ported here: C2 (it reads `serviceEdited`), C10, C14 (`resetLayout`) go to Task 13. `test/host/view_replace_test.dart` VR1-VR3 are **not ported, by controller ruling R-11 (R11-a; an execution ruling the ledger records)**: their premise is that each mounted view acquires the document's systems (`DocumentSystems.acquire`, `view_replace_test.dart:24-115`); in 2a and 2b the sessions own the systems for the document's life (`controller/session.dart:84-88`, this task's `ServiceSession`), so no view installs or releases them and the premise cannot exist; SM-lifetime pins what replaces it (one install per copy, uninstalled when the copy goes). `test/host/seams_test.dart` SM1-SM3 test `PlannerShell`'s design seams (a host selection, fit requests, framing), no service member: outside 2b, left to the ledger as 2a's.

- [ ] **Step 4: Run the tests to see them fail.** Run: `cd packages/jet_cad_2d_plan && flutter test test/service/service_session_test.dart test/controller/mode_test.dart`. Expected: compilation errors, `Undefined name 'PlanMode'` and `The method 'setMode' isn't defined for the type 'PlanController'`.

- [ ] **Step 5: The service session.** Create `lib/src/service/service_session.dart`:

```dart
// The service copy and everything over it (spec 2b S3 "Mode and copy"):
// the design's text decoded under runtime permissions, its parametric
// system over the guarded catalog and the design's frozen set, its unit
// label system, its lock expander over the design's lock set, its own
// failure boundary, its index, page, selection, outlines, unit index and
// tool controller. Today's service copy and its systems
// (jet_cad_floor_plan's floor_plan_controller.dart:1305-1319,
// host/service_view.dart:124-130, :242-245), built like 2a's
// DocumentSession (controller/session.dart:29-89).
import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, VoidCallback;
import 'package:flutter/material.dart' show Canvas, KeyEventResult, Size;
import 'package:flutter/services.dart' show KeyEvent;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../controller/diagnostics_log.dart';
import '../kits/guard.dart';
import '../kits/locks.dart';
import '../units/unit_index.dart';
import '../units/unit_label_system.dart';

/// The controller's two modes (spec S3).
enum PlanMode {
  /// The editor over the plan the host loads and saves.
  design,

  /// A copy of the design under runtime permissions: units are tapped,
  /// selected, given statuses, grouped and moved; nothing done here
  /// reaches the design.
  service,
}

/// [design]'s text decoded as a service copy (today's `_copyOf`): under
/// `DraftPermissions.runtime` (transforms and components only), with
/// [register]'s components, a component the design keeps raw (E4) kept
/// raw. The handles are the design's.
DraftDocument serviceCopyOf(DraftDocument design,
        {required void Function(ComponentRegistry registry) register,
        required TextMeasurer measurer}) =>
    DraftDocumentCodec.decodeString(DraftDocumentCodec.encodeToString(design),
        measurer: measurer,
        permissions: DraftPermissions.runtime,
        diagnostics: <Diagnostic>[],
        keepUnreadableComponents: true,
        registerComponents: register);

/// The service copy and its systems and views (spec S3). Made when service
/// is entered (and by a load, a new plan, a reset or a restore in
/// service), disposed after the frame that unmounts its view.
final class ServiceSession {
  /// [locks] and [frozen] are the design session's own (the handles are
  /// the same in both documents); [lock] and [damage] receive this
  /// session with what its boundary found. The copy's one tool is an idle
  /// placeholder until Task 14's `ServiceTool`.
  ServiceSession({
    required this.document,
    required this.measurer,
    required ParametricCatalog catalog,
    required CameraController camera,
    required LockSet locks,
    required Set<Handle> frozen,
    required ValueListenable<Set<Handle>> locked,
    required DiagnosticsLog log,
    required void Function(ServiceSession session, Set<Handle> objects) lock,
    required void Function(ServiceSession session, PartialMutationError error)
        damage,
  })  : page = PageNotifier(document),
        index = SpatialIndex(document) {
    // The selection before the outlines (it prunes a dead key first), as
    // the design's (session.dart:49-56).
    selection = SelectionController(document);
    outlines = OutlineCache(document, selection);
    units = UnitIndexCache(document,
        catalog: catalog, locks: locks, locked: locked);
    toolContext = ToolContext(
        document: document,
        index: index,
        camera: camera,
        selection: selection,
        page: page);
    tool = _IdleTool();
    tools = ToolController(initial: tool, context: toolContext);
    // The design's stack (Task 7): parametric, unit labels, lock.
    parametric = ParametricSystem(document, catalog, isFrozen: frozen.contains)
      ..install();
    labels = UnitLabelSystem(document)..install();
    lockExpander = LockExpander(document, locks)..install();
    boundary = FailureBoundary(
        document: document,
        catalog: catalog,
        system: parametric,
        frozen: frozen,
        log: log,
        lock: (objects) => lock(this, objects),
        damage: (error) => damage(this, error));
    // As the design's (plan_controller.dart:677-681): a hook failure is
    // probed, frozen and retried once.
    lockExpander
      ..onHookFailure = boundary.recover
      ..onPartialMutation = boundary.partialMutation
      ..onRefusedEdit = boundary.recoverRefused
      ..onRetryFailed = boundary.retryFailed;
  }

  /// The copy.
  final DraftDocument document;
  final FlutterTextMeasurer measurer;
  final PageNotifier page;
  final SpatialIndex index;
  late final SelectionController selection;
  late final OutlineCache outlines;

  /// The copy's units: what everything in service reads.
  late final UnitIndexCache units;
  late final ToolContext toolContext;

  /// The copy's one tool, which [tools] holds.
  late final Tool tool;
  late final ToolController tools;
  late final ParametricSystem parametric;
  late final UnitLabelSystem labels;
  late final LockExpander lockExpander;
  late final FailureBoundary boundary;

  /// The controller's subscription to the copy's changes, and its
  /// selection listener; [detach] drops both.
  StreamSubscription<DocChange>? history;
  VoidCallback? onSelection;

  bool get canUndo => document.commands.canUndo;
  bool get canRedo => document.commands.canRedo;

  /// Stops the controller listening, at once.
  void detach() {
    final h = history;
    history = null;
    if (h != null) unawaited(h.cancel());
    final l = onSelection;
    onSelection = null;
    if (l != null) selection.removeListener(l);
  }

  /// Everything, after the frame that unmounts the view: the tool
  /// controller before the tool, the outlines before the selection, the
  /// systems last in first out, the index before the document.
  void dispose() {
    tools.dispose();
    tool.dispose();
    outlines.dispose();
    selection.dispose();
    page.dispose();
    units.dispose();
    lockExpander.dispose();
    labels.dispose();
    parametric.dispose();
    index.dispose();
    unawaited(document.dispose());
    measurer.clear();
  }
}

/// The copy's tool until Task 14's service tool: it reacts to nothing.
final class _IdleTool extends Tool {
  @override
  String get name => 'plan.service';
  @override
  ToolPhase get phase => ToolPhase.idle;
  @override
  void onPointerDown(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerMove(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerUp(ToolPointerEvent e, ToolContext ctx) {}
  @override
  void onPointerExit(ToolContext ctx) {}
  @override
  KeyEventResult onKey(KeyEvent event, ToolContext ctx) =>
      KeyEventResult.ignored;
  @override
  void cancel(ToolContext ctx) {}
  @override
  void paintOverlay(Canvas canvas, ViewportTransform camera, Size viewport,
      PaperPalette paper) {}
}
```

- [ ] **Step 6: The controller: the mode and the copy.** In `lib/src/controller/plan_controller.dart`, import `'../service/service_session.dart'`, then:
  1. Add the mode's members (a new section after "Opening and replacing documents"):

```dart
  // ---------------------------------------------------------------------
  // The mode (spec 2b S3 "Mode and copy").

  final ValueNotifier<PlanMode> _mode = ValueNotifier(PlanMode.design);

  /// The service copy while the mode is service; null in design.
  ServiceSession? _service;

  /// Copies let go of whose disposal waits for the next frame (R-2).
  final List<ServiceSession> _droppedServices = [];

  /// The mode. Changed by [setMode].
  ValueListenable<PlanMode> get mode => _mode;

  /// The document the mode shows: the design, or the service copy.
  DraftDocument get activeDocument => _service?.document ?? _session.document;

  /// The active document's selection: the design's, or the copy's.
  SelectionController get activeSelection =>
      _service?.selection ?? _session.selection;

  /// The service copy and its systems; null in design.
  @internal
  ServiceSession? get serviceSession => _service;

  /// Switches the mode (spec S3). Into service: a copy of the design, the
  /// design's tool back to plan.select. Out of it: the copy is discarded
  /// with every service edit. The selected labels are selected again in
  /// the new mode, by its rules. Moves [revision] and notifies.
  void setMode(PlanMode next) {
    if (next == _mode.value) return;
    settlePendingInput();
    // The settle may have relabelled a selected unit: read it now.
    _refreshSelected();
    final labels = _selectedUnits.value;
    if (next == PlanMode.service) {
      final design = _session;
      // `_onTools` moves `activeTool` back to plan.select.
      design.tools.activate(design.toolById(planSelectToolId)!);
      final copy = _buildService();
      _attachService(copy);
      _service = copy;
    } else {
      final old = _service!;
      _service = null;
      _dropService(old);
    }
    _mode.value = next;
    _select(labels);
    _refreshFlags();
    _revision.value++;
    notifyListeners();
  }

  /// A copy of the design, its systems installed, nothing listening yet.
  ServiceSession _buildService() {
    final design = _session;
    final measurer = FlutterTextMeasurer();
    final DraftDocument copy;
    try {
      copy = serviceCopyOf(design.document,
          register: _registerComponents, measurer: measurer);
    } catch (_) {
      measurer.clear();
      rethrow;
    }
    return ServiceSession(
        document: copy,
        measurer: measurer,
        catalog: catalog,
        camera: camera,
        locks: design.locks,
        frozen: design.frozen,
        locked: _locked,
        log: _diagnostics,
        lock: _lockFromCopy,
        damage: _damageCopy);
  }

  /// The controller listens to [s]: its changes and its selection.
  void _attachService(ServiceSession s) {
    s.history = s.document.commands.changes.listen((_) {
      if (_disposed || !identical(s, _service)) return;
      _onServiceChanged();
    });
    void onSelection() {
      if (!_disposed && identical(s, _service)) _refreshSelected();
    }

    s.onSelection = onSelection;
    s.selection.addListener(onSelection);
  }

  /// The active copy changed (a move, an undo or a redo of one).
  void _onServiceChanged() {
    _refreshFlags();
    _revision.value++;
    _refreshSelected();
  }

  /// Lets [s] go (R-2): its listeners now, the session after the frame
  /// that unmounts its view.
  void _dropService(ServiceSession s) {
    s.detach();
    _droppedServices.add(s);
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (_droppedServices.remove(s)) s.dispose();
      })
      ..ensureVisualUpdate();
  }

  /// The copy's boundary froze [objects] (spec S3): they join the design's
  /// lock set (refreshed over the design, whose handles the copy shares),
  /// the copy's history is cleared so no earlier service step is undone
  /// onto them, and the listeners are told. The design's history is never
  /// touched (Risks, B3).
  void _lockFromCopy(ServiceSession s, Set<Handle> objects) {
    if (objects.isEmpty) return;
    _session.locks.addBroken(document, objects);
    s.document.commands.clearHistory();
    _locked.value = _session.locks.objects;
    _refreshFlags();
    grips.gatesChanged();
    notifyListeners();
  }

  /// E3 in the copy: a rollback threw there. The copy is rebuilt from
  /// what it holds (its history cleared); the design is not touched.
  void _damageCopy(ServiceSession s, PartialMutationError error) {
    s.document.commands.notifyLoaded();
    _refreshFlags();
    notifyListeners();
  }
```

  2. `execute`: its first line becomes `if (_service != null) return false;`, and its doc gains: "False in service (spec 2b S3): the design is not edited there."
  3. `deleteSelection`: its first line becomes `if (_service != null || _midShape) return false;` (today's `floor_plan_controller.dart:708-709`), and its doc gains "false in service".
  4. Task 9's `_requireDesign(String who)` gets its body (today's message, `floor_plan_controller.dart`'s P-5 check, which the ported TC6 asserts with the method's new name):

```dart
  void _requireDesign(String who) {
    if (_service != null) {
      throw StateError('$who needs the design mode (P-5)');
    }
  }
```

  5. `undo` and `redo` act on the active document; a design tool part-way holds them in design only:

```dart
  void undo() {
    if (_service == null && _midShape) return;
    settlePendingInput();
    final commands = activeDocument.commands;
    if (!commands.canUndo) return;
    try {
      _unrestricted(commands, commands.undo);
    } on PartialMutationError catch (error) {
      (_service?.boundary ?? _session.boundary).partialMutation(error);
    }
  }
```

     `redo` the same with `canRedo` and `commands.redo`. `_unrestricted` takes its dispatcher:

```dart
  void _unrestricted(CommandDispatcher commands, void Function() step) {
    final saved = commands.permissions;
    commands.permissions = DraftPermissions.all;
    try {
      step();
    } finally {
      commands.permissions = saved;
    }
  }
```

     and `reportLocale`'s call becomes `_unrestricted(d.commands, () => d.commands.execute(SetComponentCommand<PageComponent>(d.rootHandle, page.copyWith(decimalSeparator: separator))));` (the design's).
  6. `_refreshFlags` reads `dirty` from the design and the history from the active document:

```dart
  void _refreshFlags() {
    _dirty.value = document.commands.stateId != _savedState;
    final active = activeDocument.commands;
    _canUndo.value = active.canUndo;
    _canRedo.value = active.canRedo;
  }
```

  7. The page flows read the active document: in the constructor's `PlanPageFlows(...)`, `document: () => this.document,` becomes `document: () => activeDocument,` (export and print act on the active document, spec S3; a switch before the bytes are made then answers null, as today's "the plan shown is replaced", `floor_plan_controller.dart:1331-1332`).
  8. `_replace`: right after `_open(document, measurer, loadDiagnostics);` add (today's `_replaceDesign`, `floor_plan_controller.dart:1235-1239`: the copy is rebuilt from the new design, the mode kept):

```dart
    final service = _service;
    if (service != null) {
      final copy = _buildService();
      _attachService(copy);
      _service = copy;
      _dropService(service);
    }
```

     Task 9's Step 8 item 4 already ends `_replace` with `_refreshSelected();` and `_revision.value++;` (exactly one `_revision` move per load or new plan): this step adds neither.
  9. `dispose`: before the design session's disposal add

```dart
    for (final s in _droppedServices) {
      s.dispose();
    }
    _droppedServices.clear();
    final service = _service;
    _service = null;
    if (service != null) {
      service
        ..detach()
        ..dispose();
    }
```

     and after `_locked.dispose();` add `_mode.dispose();`.

- [ ] **Step 7: Re-point Task 9's members to the active document** (spec S3 "The members that switch on `mode`"). Task 9 wrote `units`, `unitDetails`, `labelWarnings`, `unitIndex`, `unitAt`, `select`/`_select`, `fitToUnits`, `_refreshSelected` and the writes against its private seams (Task 9 Step 8, item 3); this step changes the seams' bodies, not those members.
  1. The seams:

```dart
  /// The active document's units: the copy's in service (spec S3).
  UnitIndexCache get _activeUnits => _service?.units ?? _session.units;

  /// The active document: the copy in service.
  DraftDocument get _activeDocument => activeDocument;

  /// The active selection: the copy's in service.
  SelectionController get _activeSelection => activeSelection;

  /// Whether the design is the active document.
  bool get _inDesign => _service == null;
```

     Task 9's `unitAt` makes its picker again when `_activeUnits` is another cache (`!identical(picker.units, units)`), so it follows a switch, a load, a reset and a restore by itself; `_select` takes placed units only while `_inDesign`; `_refreshSelected` gives the editor's labels in design and none in service.
  2. `selectedUnits` (Shared interfaces, listed under Task 12; this task exposes it because spec S3 re-points it here, and Task 9 keeps it private): after Task 9's `editorSelectedUnits` add

```dart
  /// The labels of the active selection's units (today's
  /// `selectedTables`): the design's in design, the copy's in service.
  ValueListenable<Set<String>> get selectedUnits => _selectedUnits;
```

  3. `revision` moves on a change of the active document only: Task 9's design-change subscription bumps `_revision` only `if (_inDesign)`; the copy's bumps it through `_onServiceChanged`; `setMode` and `_replace` bump it once each.
  4. The design's selection listener (Task 9) calls `_refreshSelected()` only `if (_inDesign)`.

- [ ] **Step 8: Export `PlanMode`.** In `lib/jet_cad_2d_plan.dart` add `export 'src/service/service_session.dart' show PlanMode;` (sorted among the exports). In `test/barrel_test.dart`, ED-9's expected set gains `// 2b Task 11` and `'PlanMode',`.

- [ ] **Step 9: Run the tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/service/service_session_test.dart test/controller/mode_test.dart test/barrel_test.dart`. Expected: `All tests passed!`. Then the whole package: `flutter test`. Expected: `All tests passed!` (2a's controller, lock and failure tests unchanged: in design every re-pointed member reads what it read).

- [ ] **Step 10: Format and the gate.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0. If `flutter analyze` reports an import of this task's files as unused or unnecessary, delete that import line only. From the root, `git status --short`: only this task's files.

- [ ] **Step 11: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/service/service_session.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart packages/jet_cad_2d_plan/test/barrel_test.dart packages/jet_cad_2d_plan/test/support/service_plans.dart packages/jet_cad_2d_plan/test/service/service_session_test.dart packages/jet_cad_2d_plan/test/controller/mode_test.dart packages/jet_cad_2d_plan/test/controller/unit_colour_test.dart packages/jet_cad_2d_plan/test/controller/unit_data_test.dart packages/jet_cad_2d_plan/test/controller/unit_detail_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): the service mode's session and the mode switch (2b S3)

PlanController gains mode and setMode. Entering service decodes a copy
of the design under runtime permissions into a ServiceSession with its
own parametric and unit label systems, a lock expander over the
design's lock set and a failure boundary whose freeze clears the
copy's history only, then retries once. The design's members stay on
the design; undo, redo, export, print, the unit API and the selection
act on the active document; execute and the design writes are refused
in service.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 12: Mutation check** (committed files only; after each: run `cd packages/jet_cad_2d_plan && flutter test test/service/service_session_test.dart`, see the named test red, quote the red line, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0):
  - M-SM1 `lib/src/controller/plan_controller.dart`: delete `execute`'s `if (_service != null) return false;` → SM-execute-false red (`execute` answers true).
  - M-SM2 `plan_controller.dart`: `_requireDesign`'s body emptied → SM-execute-false red (no `StateError`).
  - M-SM3 `plan_controller.dart`: `DraftDocument get document => _session.document;` → `DraftDocument get document => activeDocument;` → SM-members red.
  - M-SM4 `lib/src/service/service_session.dart`: `lockExpander = LockExpander(document, locks)..install();` → `lockExpander = LockExpander(document, locks);` (and the matching `lockExpander.dispose();` stays) → SM-copy-lock red (no `PlanLocked`).
  - M-SM5 `plan_controller.dart`: in `_lockFromCopy`, `s.document.commands.clearHistory();` → `document.commands.clearHistory();` → SM-copy-boundary red (the copy's depth 2, the design's `canUndo` false).
  - M-SM6 `plan_controller.dart`: delete `_lockFromCopy`'s `_session.locks.addBroken(document, objects);` → SM-copy-boundary red (`locked` empty).
  - M-SM7 `service_session.dart`: `isFrozen: frozen.contains` → `isFrozen: (_) => false` → SM-copy-boundary red (the retry fails again on the square: `KitHookFailure`).
  - M-SM8 `plan_controller.dart`: `bool get _inDesign => _service == null;` → `bool get _inDesign => true;` → SM-select red (in service the editor's labels are not emptied and the seat is skipped). The design's placed-only rule itself is Task 9's M-UA7.
  - M-SM9 `plan_controller.dart`: delete `setMode`'s `_select(labels);` → SM-select red (the copy's selection empty after the switch).
  - M-SM10 `plan_controller.dart`: in `_dropService`, `if (_droppedServices.remove(s)) s.dispose();` → `_droppedServices.remove(s);` → SM-lifetime red.
  - M-SM11 `plan_controller.dart`: in `undo`, `final commands = activeDocument.commands;` → `final commands = document.commands;` → SM-undo red.
  - M-SM12 `plan_controller.dart`: in `_refreshFlags`, `final active = activeDocument.commands;` → `final active = document.commands;` → SM-undo red.
  - M-SM13 `plan_controller.dart`: `document: () => activeDocument,` → `document: () => this.document,` → SM-export red.
  - M-SM14 `plan_controller.dart`: `deleteSelection`'s `if (_service != null || _midShape) return false;` → `if (_midShape) return false;` → SM-execute-false red (table 1 deleted from the design).
  - M-SM15 `plan_controller.dart`: `UnitIndexCache get _activeUnits => _service?.units ?? _session.units;` → `UnitIndexCache get _activeUnits => _session.units;` → the ported TA3 red (`test/controller/unit_detail_test.dart`).

#### Assumed from earlier tasks

Each name below is used as written; where an earlier task named it otherwise, the implementer uses that task's name and reports the difference.
- Task 6 (`lib/src/units/unit_index.dart`): `UnitIndexCache(DraftDocument, {required ParametricCatalog catalog, required LockSet locks, required ValueListenable<Set<Handle>> locked})` with `current` and `dispose`, rebuilding on the state id, the layers' revision and `locked`; `UnitIndex.units` ascending, `operator []`, `withLabel(String)` (trimmed labels); `UnitInfo.instance`, `text`, `visible`, `locked`, `generated`. The design's cache is a `DocumentSession` member named `units`, made in its constructor over `locks` and the controller's `locked`, disposed with the session; `_registerComponents` registers the unit components.
- Task 7: `UnitLabelSystem(DraftDocument)` with `install()` and `dispose()`; in `DocumentSession` it is installed after the parametric system and before the lock expander.
- Task 9 (`plan_controller.dart`): `units`, `unitDetails`, `unitAt` (through Task 8's `UnitPicker(document, units)`, `lib/src/service/unit_picker.dart`, made again when `_activeUnits` changes), `select`, `labelWarnings`, `fitToUnits`, `setUnitData`, `setUnitColour`, `setUnitLabel` (each calling `_requireDesign('<member>')` first), `editorSelectedUnits`, `revision` (a `ValueNotifier<int> _revision`), `@internal UnitIndex get unitIndex`; the private seams `UnitIndexCache get _activeUnits`, `DraftDocument get _activeDocument`, `SelectionController get _activeSelection`, `bool get _inDesign`, `void _requireDesign(String who)`, `Set<String> _expandLabels(Set<String>)`, and `_refreshSelected()`, `_select(Set<String>)`, `_selectedUnits` and `_editorSelected` (`ValueNotifier<Set<String>>`), a design-change subscription that bumps `_revision`, a design-selection listener.
- Task 5: `testKit()` unchanged and `unitKit()` (`test/support/test_kit.dart`: the test kit with its unit library and `test.row`); `serviceFixture()` (`test/support/service_fixture.dart`), a plan text over `unitKit()` with one placed table labelled `12` (turned, mirrored, off the origin) and two rows, A (six seats, turned) and B (five seats, curved), its record holding `json`, `table`, `rowA`, `seatsA`, `rowB`, `seatsB` (the seats ascending, labelled `A1…`, `B1…`). `hall()` (Step 1) is the one adapter.
- Task 3: `unitLabelAttrib`, `kUnitLabelTag` from `package:jet_cad_2d_kit/jet_cad_2d_kit.dart`.
- 2a (`test/support/`): `controllerFor`, `planText`, `addLine` (`harness.dart:65-134`); `Switches`, `boxKit`, `ringKit`, `addObject`, `atSquare`, `nearSquare`, `SquareParams`, `DiscParams` (`box_kit.dart`); `RecordingExporter` (`recording_exporters.dart:11-46`).

---

