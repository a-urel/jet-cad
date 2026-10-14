### Task 6: Units core: `UnitIndex`, labels, numbering, per-unit data, locks (spec S2 "A unit", "A held object stays held", "Locked units", "`UnitIndex`", "The label" text rule, "Diagnostics", "Unlabelled, duplicate and bad labels", "Per-unit data", "R1 closes")

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/units/unit_label.dart`, `unit_problems.dart`, `unit_numbers.dart`, `unit_components.dart`, `unit_locks.dart`, `unit_index.dart` (all under `lib/src/units/`)
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` (`_register` registers the unit components; `@internal UnitIndex get unitIndex`), `packages/jet_cad_2d_plan/lib/src/controller/session.dart` (`units`, its disposal), `packages/jet_cad_2d_plan/lib/src/export/page_flows.dart` (the export copy registers the unit components)
- Modify (test support): `packages/jet_cad_2d_plan/test/support/harness.dart` (`registerPlanComponents` registers the unit components)
- Create (test support): `packages/jet_cad_2d_plan/test/support/unit_fixtures.dart`
- Test: `packages/jet_cad_2d_plan/test/units/unit_index_test.dart`, `unit_numbers_test.dart`, `unit_components_test.dart`, `unit_label_test.dart` (ported), `units_test.dart` (new)

(Paths below are under `packages/jet_cad_2d_plan/`.)

**Interfaces:**
- Consumes:
  - Engine: `CommandTarget` (`jet_cad_2d/lib/src/document/command.dart:88-109`), `DocumentTree.root`, `operator []`, `definition`, `nodes` (ascending by handle; `tree.dart:65-73`), `EntityStore.liveSlots`, `kindAt`, `ownerAt`, `handleAt`, `tagAt`, `textAt`, `geomIndexAt` (`entity_store.dart:341-355`), `DocumentTables.layers`, `mutationRevision` (`tables.dart:594`), `CommandDispatcher.stateId` (`undo.dart:185`), `ParametricCatalog.typeIdOf` (`parametric_system.dart:586`), `ComponentRegistry.unknownOf` (`component.dart:248`), `isClosedPolyline` (`grips.dart:50`), `Diagnostic`, `DiagnosticSeverity`.
  - Kit (Task 3): `kUnitLabelTag`, `kUnitLabelTextAttrs`, `unitLabelHeight(Aabb2 top)`, `unitLabelPayload({anchor, height, instanceToWorld})`; `UnitComponent`, `UnitLabelling`, `SymbolComponent`, `PlanSwatch`, `planSwatchNamed`, `isKitId`.
  - 2a: `LockSet` (`isLockedObject`, `covers`; `lib/src/kits/locks.dart:28-159`), `boxOfLeaves` (`lib/src/symbols/symbol_box.dart:68`), `DocumentSession` (`lib/src/controller/session.dart:29-89`), `PlanController.locked`, `lockBroken`, `execute`, `lockHint`, `missingKits`, `save`.
  - Task 5: `unitKit()`, `RowComponent`, `placeRowCommand`, `entryTop`, `rowSeatKey`, `tableSymbolId`, `boothSymbolId`; `serviceFixture()`, `testEntry`, `addRow`, `seatsOf`, `labelPlacedUnit` (`test/support/service_fixture.dart`).
- Produces (Shared interfaces, Task 6; internal, not exported from the barrel here: Task 9 exports the host-facing ones with `labelWarnings`):
  - `lib/src/units/unit_index.dart`: `final class UnitInfo` (the fields of Shared interfaces, a `const` named constructor, `bool get generated`); `final class UnitIndex` (`factory UnitIndex.of(CommandTarget document, {required ParametricCatalog catalog, required LockSet locks})`, `units`, `operator []`, `withLabel`, `nested`, `diagnostics()`, `warnings()`); `final class UnitIndexCache` (`UnitIndexCache(DraftDocument document, {required ParametricCatalog catalog, required LockSet locks, required ValueListenable<Set<Handle>> locked})`, `current`, `dispose()`).
  - `lib/src/units/unit_label.dart`: `const int kUnitLabelMaxLength = 8`; `enum UnitLabelProblem { length, control }`; `UnitLabelProblem? unitLabelProblem(String raw)`; plus, for Tasks 7 and 9: `bool isControlCodeUnit(int u)`, `String? unitLabelError(String raw)` (English), `EntityRecord unitLabelRecord({required Handle handle, required Handle instance, required String text})`, `({EntityKind kind, GeometryPayload payload})? firstLeafOf(CommandTarget target, Handle owner, [Map<Handle, List<int>>? leavesByOwner])` (Task 8's picker imports it), `Aabb2 unitTopOfLeaves(List<(EntityKind, GeometryPayload)> leaves)`, `Aabb2 placedLabelTop(List<(EntityKind, GeometryPayload)> leaves)` and `Aabb2 placedLabelTopOf(CommandTarget target, Handle definition)` (the placed label's box, today's rule; controller ruling R-21: Tasks 7, 8 and 9 read it), `AddEntityCommand addUnitLabelCommand(DraftDocument doc, {required Handle instance, required Handle definition, required Transform2 placement, required String text})`, `Handle? unitLabelOf(CommandTarget target, Handle instance)`.
  - `lib/src/units/unit_numbers.dart`: `String nextUnitNumber(UnitIndex index)`; plus `int? countedUnitNumber(String label)`, `String nextUnitNumberOf(Iterable<String> numbers, [Set<String> labels = const {}])`.
  - `lib/src/units/unit_problems.dart`: `abstract final class UnitProblem` (the seven codes); `sealed class UnitLabelWarning`, `DuplicateLabel({required String label, required int count})`, `Unlabelled({required String kind, required int capacity, required String? symbolKey})`, `BadLabel({required String label, required UnitLabelProblem problem})`, each `const`, value-equal, with `toString`.
  - `lib/src/units/unit_components.dart`: `UnitData` (`jetcad.unit_data`), `UnitColour` (`jetcad.unit_colour`, `name`, `swatch`), `void registerUnitComponents(ComponentRegistry registry)`; plus `kUnitDataMaxKeys`, `kUnitDataMaxKeyLength`, `kUnitDataMaxValueLength`, `String? unitDataProblem(Map<String, String> data)`.
  - `lib/src/units/unit_locks.dart`: `bool isLockedUnit(CommandTarget document, LockSet locks, Handle instance)`; plus `String? heldTypeOf(CommandTarget document, Handle group)`.
  - `DocumentSession.units` (`UnitIndexCache`); `PlanController.unitIndex` (`@internal`, the design session's; Shared interfaces lists it under Task 9, which consumes it as landed here; Task 11 re-points it at the active document).
  - Test support: `test/support/unit_fixtures.dart` (below), and `registerPlanComponents` registering the unit components.

Plan decision (`UnitIndex.diagnostics()` returns the engine's `Diagnostic`, not `KitDiagnostic`): controller ruling R-8 (`KitDiagnosticCode` is an enum with no `unit.*` value, `jet_cad_2d_kit/lib/src/kit/kit_diagnostic.dart:9-44`; today's `TableSurvey.diagnostics()` returns `Diagnostic`, `table_index.dart:159-225`). The task is written with `List<Diagnostic> diagnostics()`.

Plan decision (the unit predicate, spec S2 "A unit"): a live `InstanceNode` whose definition is live and carries `UnitComponent`, and whose parent is the root (placed) or a root-level `GroupNode` that is a registered type's object (`catalog.typeIdOf != null`) or a lock-set object (`locks.isLockedObject`) (generated, `owner` that group). Any other such instance is `nested`. `ownerType` is the type id, or for a held object of a missing kit the first unknown kit-namespaced component's type id on the group (`heldTypeOf`, the rule `LockSet._unknownKit` reads, `locks.dart:67-77`).

Plan decision (`locked` and `visible`): `locked` is `isLockedUnit`: the instance's layer locked, or `locks.covers(document, instance)`. `visible` is the instance's layer shown (a missing layer counts as shown, `service_layout.dart:155-157`). A generated instance carries its object's layer (E5, spec S1), so both read the instance's own layer.

Plan decision (`top` and `box`): `box` is the definition's leaves' box (`boxOfLeaves`, 2a's rule, true arc extents). `top` is the lowest-handle leaf's box when it is a closed polyline or a circle, else `box`: the rule of `SymbolDefinitionRef.top` (spec S2) and of today's served top (`table_picker.dart:92-110`). Both are computed once per definition per build, from one bucketing pass over the entities.

Plan decision (`UnitIndexCache`'s key): it rebuilds when `document.commands.stateId` or `document.tables.mutationRevision` moves (today's picker key, `table_picker.dart:230-239`), or when `locked` has notified since the last build. A freeze moves no state id (`undo.dart:179-185`), and `lockBroken` always assigns a new set (`plan_controller.dart:533-541`), so a listener sets a stale flag.

Plan decision (`nextUnitNumber`, spec S2 "Placed, numbered"): `max + 1` over the counted labels (1 to 8 ASCII digits) of placed `numbered` units, then up by one while that text is any unit's label. When that would pass `99999999`, it is the smallest positive integer that is neither a counted placed number nor any unit's label. The pure core `nextUnitNumberOf(numbers, labels)` equals today's `nextTableNumber` when `labels` is empty, so TN1-TN5 port with their assertions.

Plan decision (the order of `diagnostics()`): today's. Duplicates by first appearance, then per unit ascending: `unit.unlabelled` or `unit.bad_label`, `unit.extra_label`, `unit.invalid_data`, `unit.invalid_colour`. Then `unit.nested`, ascending. Severity is `warning` for all but `unit.nested` (`info`), as `table_index.dart:159-225`. `warnings()` gives `DuplicateLabel` (first appearance), then `Unlabelled` (ascending), then `BadLabel` (ascending).

- [ ] **Step 1: The test fixture.** Create `test/support/unit_fixtures.dart`, a port of `jet_cad_floor_plan/test/tables/table_fixture.dart:1-113` in the kit's catalog language. This task owns the file (controller ruling R-19): Task 8 appends the picker's and the editor's helpers to it, and no other task creates it.

```dart
// The units' fixture (2b Task 6; Task 8 adds the picker's and the
// editor's helpers, and Tasks 7, 9, 10, 14 and 15 reuse it), ported from
// jet_cad_floor_plan's test/tables/table_fixture.dart: a servable table
// symbol, a stool, a planter, a table with one chair and a trapezoid, and a
// plan to place them in. A symbol is a CatalogSymbol; its SymbolEntry is
// built by hand, never through a library, so a unit that breaks the
// library's outline rule (Task 8's open table) can still be placed. The
// keys are under the fixture kit `fx` with two segments (K2's key rule,
// `isSymbolKey`; controller rulings R-10 P-1 and R-19). Base points and
// placements are off the origin (the degenerate-fixture rule).
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/authoring.dart'
    show
        CatalogCircle,
        CatalogLine,
        CatalogPolyline,
        CatalogSymbol,
        CatalogUnit;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/kits/locks.dart';
import 'package:jet_cad_2d_plan/src/units/unit_index.dart';
import 'package:jet_cad_2d_plan/src/units/unit_label.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'harness.dart';
import 'symbol_fixtures.dart' show leafRecord;

/// The fixtures' kit: no type, no tool, no library. Its symbols are placed
/// by hand; a controller loads it so that LockSet leaves them unlocked.
const String fxKitId = 'fx';

PlanKit fxKit() => PlanKit(id: fxKitId, version: '1.0.0');

/// A served unit of kind `table` seating [seats], the default labelling.
CatalogUnit tableUnit(int seats) =>
    CatalogUnit(kind: UnitKinds.table, capacity: seats);

/// A 1200 x 800 top with two 450 x 450 chairs below and above it; the base
/// point is the top's centre, (900, 700).
CatalogSymbol tableSymbol({String key = 'fx.table.two', int seats = 2}) =>
    CatalogSymbol(
      key: key,
      name: 'Test table',
      category: 'Tests',
      tags: const ['table', 'test'],
      unit: tableUnit(seats),
      base: (900, 700),
      shapes: const [
        CatalogPolyline([(300, 300), (1500, 300), (1500, 1100), (300, 1100)],
            closed: true),
        CatalogPolyline([(675, -50), (1125, -50), (1125, 400), (675, 400)],
            closed: true),
        CatalogPolyline([(675, 1000), (1125, 1000), (1125, 1450), (675, 1450)],
            closed: true),
      ],
    );

/// A Ø 380 stool, its seat first; base point at its centre.
const CatalogSymbol stoolSymbol = CatalogSymbol(
  key: 'fx.stool.round',
  name: 'Test stool',
  category: 'Tests',
  tags: ['stool', 'test'],
  unit: CatalogUnit(kind: UnitKinds.table, capacity: 1),
  base: (400, 300),
  shapes: [CatalogCircle((400, 300), 190), CatalogCircle((400, 300), 150)],
);

/// No unit.
const CatalogSymbol planterSymbol = CatalogSymbol(
  key: 'fx.planter.round',
  name: 'Test planter',
  category: 'Tests',
  tags: ['planter', 'test'],
  base: (250, 250),
  shapes: [CatalogCircle((250, 250), 250)],
);

/// [tableSymbol]'s top with one chair, below it: the symbol's box centre,
/// (900, 525), is not its base point, (900, 700).
const CatalogSymbol oneChairTable = CatalogSymbol(
  key: 'fx.table.one',
  name: 'Test table, one chair',
  category: 'Tests',
  tags: ['table', 'test'],
  unit: CatalogUnit(kind: UnitKinds.table, capacity: 1),
  base: (900, 700),
  shapes: [
    CatalogPolyline([(300, 300), (1500, 300), (1500, 1100), (300, 1100)],
        closed: true),
    CatalogPolyline([(675, -50), (1125, -50), (1125, 400), (675, 400)],
        closed: true),
  ],
);

/// A unit whose top is an asymmetric trapezoid: a mirror about the base
/// point changes where the top is.
const CatalogSymbol trapezoidTable = CatalogSymbol(
  key: 'fx.trapezoid.two',
  name: 'Test trapezoid',
  category: 'Tests',
  tags: ['table', 'test'],
  unit: CatalogUnit(kind: UnitKinds.table, capacity: 2),
  base: (900, 650),
  shapes: [
    CatalogPolyline([(200, 300), (1600, 300), (1300, 1000), (500, 900)],
        closed: true),
  ],
);

/// [s] as a library entry, built by hand (no library rule is checked): its
/// leaves ascending by handle in shape order, each a BYBLOCK leaf on layer
/// 0; its unit when [CatalogSymbol.unit] is set.
SymbolEntry entryOf(CatalogSymbol s) {
  const definition = Handle(0x0F0);
  final leaves = <SymbolLeaf>[];
  var next = 0x100;
  for (final shape in s.shapes) {
    final (EntityKind kind, GeometryPayload payload) = switch (shape) {
      CatalogPolyline(:final points, :final closed) => (
          EntityKind.polyline,
          polylinePayload([for (final (x, y) in points) Vector2(x, y)],
              closed: closed)
        ),
      CatalogCircle(center: (final x, final y), :final radius) =>
        (EntityKind.circle, circlePayload(Vector2(x, y), radius)),
      CatalogLine(from: (final ax, final ay), to: (final bx, final by)) => (
          EntityKind.line,
          linePayload(Vector2(ax, ay), Vector2(bx, by))
        ),
      _ => throw UnsupportedError('no arc in the unit fixtures'),
    };
    leaves.add((record: leafRecord(next++, definition, kind), payload: payload));
  }
  final unit = s.unit;
  return SymbolEntry(
    symbol: SymbolComponent(
        key: s.key,
        version: s.version,
        name: s.name,
        category: s.category,
        tags: s.tags),
    unit: unit == null
        ? null
        : UnitComponent(
            kind: unit.kind,
            capacity: unit.capacity,
            labelling: unit.labelling),
    definition: Definition(
        handle: definition,
        name: s.id,
        basePoint: Vector2(s.base.$1, s.base.$2),
        children: const []),
    leaves: leaves,
  );
}


/// An empty plan with the plan's components (the unit components among
/// them) and [catalog]'s, in millimetres.
DraftDocument plan({ParametricCatalog? catalog}) {
  final doc = DraftDocument.empty();
  registerPlanComponents(doc.components, catalog ?? ParametricCatalog());
  doc.header.units = DrawingUnits.millimeters;
  return doc;
}

const double kDeg37 = 37 * math.pi / 180;

/// `translate(at) · R(theta) · (mirror x) · translate(-base)`.
Transform2 placementAt(double x, double y, double theta,
        {bool mirrored = false, double baseX = 900, double baseY = 700}) =>
    Transform2.translation(x, y)
        .multiply(Transform2.rotation(theta))
        .multiply(Transform2.scale(mirrored ? -1 : 1, 1))
        .multiply(Transform2.translation(-baseX, -baseY));

/// [doc]'s units, every kit [loaded] unless told otherwise.
UnitIndex unitIndexOf(DraftDocument doc,
        {ParametricCatalog? catalog, bool Function(String kitId)? loaded}) =>
    UnitIndex.of(doc,
        catalog: catalog ?? ParametricCatalog(),
        locks: LockSet.scan(doc, loaded ?? (_) => true));

/// Adds [text] as the label of [i] (today's `addTableLabelCommand`),
/// executed; the label's handle.
Handle labelUnit(DraftDocument doc, InstanceNode i, String text) {
  final command = addUnitLabelCommand(doc,
      instance: i.handle,
      definition: i.definition,
      placement: i.transform,
      text: text);
  doc.commands.execute(command);
  return command.record.handle;
}

/// The labels of [index]'s labelled units, one per unit (today's
/// `TableSurvey.numbers`).
List<String> labelsOf(UnitIndex index) => [
      for (final u in index.units)
        if (u.text != null) u.text!,
    ];
```

- [ ] **Step 2: The new failing tests.** Create `test/units/units_test.dart`:

```dart
// Spec 2b S2: placed and generated units in one index, locks (a frozen
// row, a missing kit's rows, a seat of a missing kit's definition), a held
// object's units, duplicate, unlabelled and bad labels, the next number,
// and the unit components' registration. On the service fixture: a
// mirrored, turned table; a turned row and a curved one, off the origin.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart' show PlanController;
import 'package:jet_cad_2d_plan/src/kits/locks.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart'
    show definitionForEntry, placeSymbol;
import 'package:jet_cad_2d_plan/src/units/unit_components.dart';
import 'package:jet_cad_2d_plan/src/units/unit_index.dart';
import 'package:jet_cad_2d_plan/src/units/unit_label.dart';
import 'package:jet_cad_2d_plan/src/units/unit_numbers.dart';
import 'package:jet_cad_2d_plan/src/units/unit_problems.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/service_fixture.dart';
import '../support/symbol_fixtures.dart' show symbolKit;
import '../support/test_kit.dart';
import '../support/unit_fixtures.dart';

const Tolerance exact = Tolerance(linear: 0, angular: 0);

List<double> boxOf(Aabb2 b) => [b.minX, b.minY, b.maxX, b.maxY];

List<Handle> ascending(Iterable<Handle> hs) =>
    hs.toList()..sort((a, b) => a.value.compareTo(b.value));

/// A row of the fixture's seat: [prefix], [count] seats, at [at] turned
/// [angle]; executed through [c]; its handle.
Handle addSeatRow(PlanController c, ServiceFixture f, String prefix, int count,
    {required Vector2 at, double angle = 0, double curve = 0}) {
  final seat = testEntry(rowSeatKey);
  final h = c.document.handleSeed.next();
  expect(
      c.execute(placeRowCommand(
          c.document,
          RowComponent(
              prefix: prefix,
              count: count,
              spacing: 500,
              curve: curve,
              seat: f.seatDefinition,
              base: seat.definition.basePoint,
              top: entryTop(seat)),
          at: at,
          angle: angle,
          handle: h)),
      isTrue);
  return h;
}

/// A plan text whose root holds a group G turned 0.4 rad at (3100.5,
/// -1700.25), carrying a slab (the test kit's type) unless [plain], with
/// one stool (a unit) under it, turned 37°.
({String text, Handle group, Handle seat}) heldPlan({bool plain = false}) {
  final d = plan(catalog: catalogOf([testKit()]));
  final group = d.handleSeed.next();
  d.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: group,
        parent: d.rootHandle,
        transform: Transform2.translation(3100.5, -1700.25)
            .multiply(Transform2.rotation(0.4)),
        children: const [])),
    if (!plain)
      SetComponentCommand<SlabComponent>(
          group, SlabComponent(width: 1800, height: 900, angle: 0.4)),
  ], label: 'Holder'));
  final made = definitionForEntry(d, entryOf(stoolSymbol));
  d.commands.execute(CompoundCommand(made.commands, label: 'Stool'));
  final seat = d.handleSeed.next();
  d.commands.execute(AddNodeCommand(InstanceNode(
      handle: seat,
      parent: group,
      transform: placementAt(120, -80, kDeg37, baseX: 400, baseY: 300),
      definition: made.definition,
      layer: ReservedHandles.layerZero)));
  final text = DraftDocumentCodec.encodeToString(d);
  d.dispose();
  return (text: text, group: group, seat: seat);
}

DraftDocument decodeWith(String text, ParametricCatalog catalog) {
  final d = DraftDocumentCodec.decodeString(text,
      registerComponents: (r) => registerPlanComponents(r, catalog));
  addTearDown(d.dispose);
  return d;
}

/// A plan over unitKit() whose row A (four seats, turned 0.5 rad, off the
/// origin) seats a definition keyed under the kit `gone`.
({String json, Handle row, List<Handle> seats}) goneSeatPlan() {
  late Handle row;
  late List<Handle> seats;
  final json = planText([unitKit(), symbolKit('gone', const [])], (d) {
    final def = d.handleSeed.next();
    final leaf = d.handleSeed.next();
    d.commands.execute(CompoundCommand([
      AddDefinitionCommand(Definition(
          handle: def,
          name: 'gone.seat.basic.one@1',
          basePoint: Vector2(250, 265),
          children: const [])),
      SetComponentCommand<SymbolComponent>(
          def,
          SymbolComponent(
              key: 'gone.seat.basic.one',
              version: 1,
              name: 'Gone seat',
              category: 'Gone',
              tags: const ['seat'])),
      SetComponentCommand<UnitComponent>(
          def,
          UnitComponent(
              kind: UnitKinds.seat,
              capacity: 1,
              labelling: UnitLabelling.assigned)),
      AddEntityCommand(
          record: EntityRecord(
            handle: leaf,
            owner: def,
            kind: EntityKind.polyline,
            layer: ReservedHandles.layerZero,
            linetype: ReservedHandles.byBlockLinetype,
            linetypeScale: 1.0,
            geomIndex: 0,
            color: const ByBlockColor(),
            lineweight: kByBlock,
            transparency: kByBlock,
            flags: 0,
          ),
          payload: polylinePayload([
            Vector2(25, 40),
            Vector2(475, 40),
            Vector2(475, 490),
            Vector2(25, 490),
          ], closed: true)),
    ], label: 'Gone seat'));
    row = addRow(
        d,
        RowComponent(
            prefix: 'A',
            count: 4,
            spacing: 600,
            seat: def,
            base: Vector2(250, 265),
            top: const Aabb2.raw(25, 40, 475, 490)),
        at: Vector2(-3900.25, 2700.5),
        angle: 0.5);
    seats = seatsOf(d, row);
  });
  return (json: json, row: row, seats: seats);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'UI-generated placed and generated units in one index, ascending: the '
      'table placed; each seat generated by its row, labelled, with its '
      'world transform, its top and its box (M-UI-generated)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    final d = c.document;
    final index = c.unitIndex;
    expect([for (final u in index.units) u.instance],
        ascending([f.table, ...f.seatsA, ...f.seatsB]));
    final table = index[f.table]!;
    expect((table.owner, table.ownerType, table.generated), (null, null, false));
    expect(
        (
          table.label,
          table.text,
          table.kind,
          table.capacity,
          table.labelling,
          table.symbolKey
        ),
        (
          f.tableLabel,
          '12',
          UnitKinds.table,
          4,
          UnitLabelling.numbered,
          'test.table.square.four'
        ));
    expect(
        table.toWorld
            .equals((d.tree[f.table]! as InstanceNode).transform, exact),
        isTrue);
    expect(boxOf(table.top), [150, 150, 1050, 1050]);
    expect(boxOf(table.box), [-150, -150, 1350, 1350]);
    final groupA = (d.tree[f.rowA]! as GroupNode).transform;
    for (final (i, s) in f.seatsA.indexed) {
      final u = index[s]!;
      expect(
          (u.owner, u.ownerType, u.generated, u.text, u.kind, u.capacity),
          (f.rowA, rowTypeId, true, 'A${i + 1}', UnitKinds.seat, 1));
      expect(u.labelling, UnitLabelling.assigned);
      expect(
          u.toWorld.equals(
              groupA.multiply((d.tree[s]! as InstanceNode).transform), exact),
          isTrue,
          reason: 'seat $i: group × instance');
      expect((u.locked, u.visible), (false, true));
      expect(boxOf(u.top), [25, 40, 475, 490]);
    }
    expect([for (final s in f.seatsB) index[s]!.text],
        ['B1', 'B2', 'B3', 'B4', 'B5']);
    expect([for (final u in index.withLabel(' A3 ')) u.instance],
        [f.seatsA[2]]);
    expect(index.nested, isEmpty);
    expect(index.diagnostics(), isEmpty);
    expect(index.warnings(), isEmpty);
  });

  test(
      'UI-missing-kit Review Focus 4: rows whose kit is missing: each seat a '
      'unit of its row, served and locked; the table of the missing kit\'s '
      'symbol locked; none nested (M-UI-held)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [discKit()], json: f.json);
    expect(c.missingKits, {'test'});
    final index = c.unitIndex;
    expect([for (final u in index.units) u.instance],
        ascending([f.table, ...f.seatsA, ...f.seatsB]));
    for (final (row, seats) in [(f.rowA, f.seatsA), (f.rowB, f.seatsB)]) {
      for (final s in seats) {
        final u = index[s]!;
        expect((u.owner, u.ownerType, u.locked, u.visible),
            (row, rowTypeId, true, true),
            reason: 'seat ${s.toHex()}');
      }
    }
    expect(index[f.seatsA.first]!.text, 'A1');
    expect(index[f.table]!.locked, isTrue);
    expect(index.nested, isEmpty);
  });

  test(
      'UI-frozen-no-edit a row frozen with no edit after it: its seats read '
      'locked at once, the state id unmoved; the other row\'s and the table '
      'do not (M-UI-locked-key)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    final first = c.unitIndex;
    expect(identical(c.unitIndex, first), isTrue,
        reason: 'no change, no rebuild');
    expect(first[f.seatsA.first]!.locked, isFalse);
    final state = c.document.commands.stateId;
    c.lockBroken({f.rowA});
    expect(c.document.commands.stateId, state,
        reason: 'premise: a freeze moves no state id');
    final after = c.unitIndex;
    for (final s in f.seatsA) {
      expect(after[s]!.locked, isTrue, reason: 'seat ${s.toHex()}');
    }
    for (final s in f.seatsB) {
      expect(after[s]!.locked, isFalse);
    }
    expect(after[f.table]!.locked, isFalse);
  });

  test(
      'UI-flip a group the lock set holds for an unknown component stays '
      'held: its unit served and locked, its kit missing or loaded; a plain '
      'group: unit.nested (M-UI-held, M-UI-object)', () {
    final held = heldPlan();
    final missing = decodeWith(held.text, ParametricCatalog());
    final locks = LockSet.scan(missing, (kit) => kit != 'test');
    expect(locks.isLockedObject(held.group), isTrue, reason: 'premise');
    final a = UnitIndex.of(missing, catalog: ParametricCatalog(), locks: locks)
        [held.seat]!;
    expect((a.owner, a.ownerType, a.locked), (held.group, 'test.slab', true));

    // Spec S2 "A held object stays held" (controller ruling R-9): with its
    // kit loaded, a group holding a component no loaded code knows keeps
    // its lock (2a's rule, locks.dart:33-44).
    final catalog = catalogOf([testKit()]);
    final ghost = held.text.replaceAll('"$slabTypeId"', '"test.ghost"');
    expect(ghost, isNot(held.text), reason: 'premise');
    final loaded = decodeWith(ghost, catalog);
    final loadedLocks = LockSet.scan(loaded, (_) => true);
    expect(loadedLocks.isLockedObject(held.group), isTrue, reason: 'premise');
    final b =
        UnitIndex.of(loaded, catalog: catalog, locks: loadedLocks)[held.seat]!;
    expect((b.owner, b.ownerType, b.locked), (held.group, 'test.ghost', true));

    final plain = heldPlan(plain: true);
    final c = unitIndexOf(decodeWith(plain.text, catalog), catalog: catalog);
    expect(c[plain.seat], isNull);
    expect(c.nested, [plain.seat]);
    expect([for (final x in c.diagnostics()) x.code], [UnitProblem.nested]);
  });

  test(
      'UI-def-kit-missing a seat whose definition\'s kit is missing, in a '
      'loaded kit\'s row: covered and locked; the row is no locked object '
      '(M-UI-covers)', () {
    final g = goneSeatPlan();
    final c = controllerFor(kits: [unitKit()], json: g.json);
    expect(c.missingKits, {'gone'});
    final index = c.unitIndex;
    for (final s in g.seats) {
      final u = index[s]!;
      expect((u.owner, u.ownerType, u.locked), (g.row, rowTypeId, true));
    }
    expect(c.locked.value.contains(g.row), isFalse);
    expect(c.isLocked(g.row), isFalse);
  });

  test(
      'UI-held-seat-row-locked the row of such a seat is effectively locked: '
      'an edit regenerating it is refused with PlanLocked, nothing changed '
      '(M-UI-scan)', () {
    final g = goneSeatPlan();
    final c = controllerFor(kits: [unitKit()], json: g.json);
    final d = c.document;
    final params = d.components.get<RowComponent>(g.row)!;
    final before = [
      for (final s in g.seats) (d.tree[s]! as InstanceNode).transform,
    ];
    expect(
        c.execute(SetComponentCommand<RowComponent>(
            g.row, params.copyWith(spacing: 700))),
        isFalse);
    expect(c.lockHint.value, isTrue);
    expect(d.components.get<RowComponent>(g.row), params);
    for (final (i, s) in g.seats.indexed) {
      expect(
          (d.tree[s]! as InstanceNode).transform.equals(before[i], exact),
          isTrue);
    }
  });

  test(
      'UI-dup a label a table and a seat share stays label-keyed: both carry '
      'it, one DuplicateLabel, one duplicate diagnostic naming both '
      '(M-UI-dup)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    final row = addSeatRow(c, f, '', 13,
        at: Vector2(1200.5, 5600.25), angle: -0.2, curve: -0.05);
    final twelfth = seatsOf(c.document, row)[11];
    final index = c.unitIndex;
    expect([for (final u in index.withLabel('12')) u.instance],
        [f.table, twelfth]);
    expect(index.warnings(), [const DuplicateLabel(label: '12', count: 2)]);
    final dup = index
        .diagnostics()
        .where((x) => x.code == UnitProblem.duplicateLabel)
        .single;
    expect(dup.handles, [f.table, twelfth]);
    expect(dup.severity, DiagnosticSeverity.warning);
  });

  test(
      'UI-unlabelled a placed unit with no label, or an empty one, is '
      'unlabelled: Unlabelled with its kind, capacity and symbol, and '
      'unit.unlabelled (M-UI-unlabelled)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    final d = c.document;
    InstanceNode place(String id, Vector2 at, int turns) {
      final before = {for (final n in d.tree.nodes) n.handle};
      expect(
          c.execute(
              placeSymbol(d, testEntry(id), at: at, quarterTurns: turns)),
          isTrue);
      return d.tree.nodes
          .whereType<InstanceNode>()
          .singleWhere((n) => !before.contains(n.handle));
    }

    final table = place(tableSymbolId, Vector2(7100.25, 2300.5), 3);
    labelPlacedUnit(d, table.handle, testEntry(tableSymbolId), '  ');
    final booth = place(boothSymbolId, Vector2(-6400.5, 5100.75), 2);
    final index = c.unitIndex;
    expect(index[table.handle]!.label, isNotNull,
        reason: 'premise: the table carries an empty label');
    expect(index[table.handle]!.text, isNull);
    expect(index.warnings(), const [
      Unlabelled(kind: 'table', capacity: 4, symbolKey: 'test.table.square.four'),
      Unlabelled(kind: 'booth', capacity: 6, symbolKey: 'test.booth.corner.six'),
    ]);
    final unlabelled = index
        .diagnostics()
        .where((x) => x.code == UnitProblem.unlabelled)
        .toList();
    expect([for (final x in unlabelled) x.handles],
        [[table.handle], [booth.handle]]);
  });

  test(
      'UI-bad a label outside the text rule is still a label, served by its '
      'text: BadLabel and unit.bad_label, a generated one included '
      '(M-UI-bad)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    final row = addSeatRow(c, f, 'ABCDEFGH', 2,
        at: Vector2(-1500.75, -6200.5), angle: 1.1);
    expect(
        c.execute(SetEntityTextCommand(f.tableLabel, 'a\u0085b', 'UNIT')),
        isTrue);
    final seats = seatsOf(c.document, row);
    final index = c.unitIndex;
    expect(index[seats.first]!.text, 'ABCDEFGH1');
    expect([for (final u in index.withLabel('ABCDEFGH2')) u.instance],
        [seats.last]);
    expect(index.warnings(), const [
      BadLabel(label: 'a\u0085b', problem: UnitLabelProblem.control),
      BadLabel(label: 'ABCDEFGH1', problem: UnitLabelProblem.length),
      BadLabel(label: 'ABCDEFGH2', problem: UnitLabelProblem.length),
    ]);
    final bad = index
        .diagnostics()
        .where((x) => x.code == UnitProblem.badLabel)
        .toList();
    expect([for (final x in bad) x.handles], [
      [f.table],
      [seats.first],
      [seats.last],
    ]);
  });

  test(
      'UI-next the next number skips any unit\'s label, a seat\'s included; '
      'past 99999999 it is the smallest number no unit holds '
      '(M-UI-next-skip, M-UI-next-fallback)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    expect(nextUnitNumber(c.unitIndex), '13');
    addSeatRow(c, f, '', 14, at: Vector2(2100.25, 6300.5), angle: 0.25);
    expect(nextUnitNumber(c.unitIndex), '15',
        reason: '13 and 14 are seats\' labels');
    expect(
        c.execute(SetEntityTextCommand(f.tableLabel, '99999999', 'UNIT')),
        isTrue);
    expect(nextUnitNumber(c.unitIndex), '15',
        reason: '1 to 14 are seats\' labels, 99999999 the table\'s');
  });

  test(
      'UI-registered the plan registers the unit components: data on the '
      'table and a colour on a seat survive a save and a load, typed '
      '(M-UI-registered)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    expect(
        c.execute(SetComponentCommand<UnitData>(
            f.table, UnitData({'id': 'T-12', 'zone': 'Bahçe'}))),
        isTrue);
    expect(
        c.execute(SetComponentCommand<UnitColour>(
            f.seatsB[2], UnitColour(PlanSwatch.teal))),
        isTrue);
    final back = controllerFor(kits: [unitKit()], json: c.save());
    expect(back.document.components.get<UnitData>(f.table)!.data,
        {'id': 'T-12', 'zone': 'Bahçe'});
    expect(back.document.components.get<UnitColour>(f.seatsB[2])!.swatch,
        PlanSwatch.teal);
    expect(back.unitIndex.diagnostics(), isEmpty);
  });
}
```

- [ ] **Step 3: Run the new tests to see them fail.** Run: `cd packages/jet_cad_2d_plan && flutter test test/units/units_test.dart`. Expected: compilation errors (`Target of URI doesn't exist: 'package:jet_cad_2d_plan/src/units/unit_index.dart'`, `The getter 'unitIndex' isn't defined for the type 'PlanController'`).

- [ ] **Step 4: `unit_label.dart`.** Create `lib/src/units/unit_label.dart`:

```dart
// A unit's label (spec 2b S2 "The label"): the text rule (today's table
// number rule, jet_cad_floor_plan/lib/src/tables/table_numbers.dart:5-46,
// renamed), the label record and command of a placed unit
// (table_label.dart:106-179), and how a unit's label and top are read. The
// stamp, the height and the payload are the kit's (Task 3).
//
// No Flutter import: Dart over package:jet_cad_2d and the kit's model.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show kUnitLabelTag, kUnitLabelTextAttrs, unitLabelHeight, unitLabelPayload;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../symbols/symbol_box.dart' show boxOfLeaves;

/// A label's longest length, in UTF-16 code units.
const int kUnitLabelMaxLength = 8;

/// Why a text is not a unit label, as a value a UI words.
enum UnitLabelProblem {
  /// Empty, or longer than [kUnitLabelMaxLength] code units, trimmed.
  length,

  /// A control character, a line break among them.
  control,
}

/// Whether the UTF-16 code unit [u] is a control character: below U+0020
/// (C0, a line break among them) or U+007F to U+009F (DEL and C1). The one
/// rule [unitLabelProblem] and the unit data limits share.
bool isControlCodeUnit(int u) => u < 0x20 || (u >= 0x7F && u <= 0x9F);

/// Why [raw], trimmed, is not a unit label, or null when it is one:
/// non-empty, at most [kUnitLabelMaxLength] code units, no control
/// character.
UnitLabelProblem? unitLabelProblem(String raw) {
  final n = raw.trim();
  if (n.isEmpty || n.length > kUnitLabelMaxLength) {
    return UnitLabelProblem.length;
  }
  if (n.codeUnits.any(isControlCodeUnit)) return UnitLabelProblem.control;
  return null;
}

/// [unitLabelProblem] in English, or null (diagnostic messages; the UI's
/// words are `PlanStrings.labelProblem`).
String? unitLabelError(String raw) => switch (unitLabelProblem(raw)) {
      null => null,
      UnitLabelProblem.length => '1 to $kUnitLabelMaxLength characters',
      UnitLabelProblem.control => 'No line breaks or control characters',
    };

/// The label record of a placed unit: owned by [instance], on layer 0 (so
/// it follows the instance's layer, spec 12b S-2), BYBLOCK style, the
/// standard text style, tag `UNIT`, text [text].
EntityRecord unitLabelRecord(
        {required Handle handle,
        required Handle instance,
        required String text}) =>
    EntityRecord(
      handle: handle,
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
    );

/// The lowest-handle leaf [owner] owns, or null. O(entities): at command
/// or document-change rate, never per frame. With [leavesByOwner]
/// ([DraftDocument.leavesByOwner], shared by a caller asking for many
/// owners in one pass), only [owner]'s own leaves are visited.
/// (`tables/table_label.dart:155-181`, `CommandTarget` for `DraftDocument`.)
({EntityKind kind, GeometryPayload payload})? firstLeafOf(
    CommandTarget target, Handle owner,
    [Map<Handle, List<int>>? leavesByOwner]) {
  final entities = target.entities;
  int? best;
  final slots = leavesByOwner == null
      ? entities.liveSlots
      : leavesByOwner[owner] ?? const <int>[];
  for (final slot in slots) {
    if (entities.ownerAt(slot) != owner) continue;
    if (best == null ||
        entities.handleAt(slot).value < entities.handleAt(best).value) {
      best = slot;
    }
  }
  if (best == null) return null;
  return (
    kind: entities.kindAt(best),
    payload: target.geometry.read(entities.geomIndexAt(best)),
  );
}

/// The top of a definition whose [leaves] are given ascending by handle
/// (spec S2, `SymbolDefinitionRef.top`): the first leaf's box when it is a
/// closed polyline or a circle, else the leaves' box (`boxOfLeaves`);
/// empty for none.
Aabb2 unitTopOfLeaves(List<(EntityKind, GeometryPayload)> leaves) {
  if (leaves.isNotEmpty) {
    final (kind, p) = leaves.first;
    if (kind == EntityKind.circle) {
      final r = p.scalars[0];
      return Aabb2.raw(
          p.coords[0] - r, p.coords[1] - r, p.coords[0] + r, p.coords[1] + r);
    }
    if (kind == EntityKind.polyline && isClosedPolyline(p)) {
      final b = boxOfLeaves([leaves.first]);
      if (b != null) return Aabb2.raw(b.left, b.front, b.right, b.back);
    }
  }
  final b = boxOfLeaves(leaves);
  return b == null ? Aabb2.empty() : Aabb2.raw(b.left, b.front, b.right, b.back);
}

/// The box a placed unit's label height reads (spec S2: today's stamp,
/// `tables/table_label.dart:22-44`): the first leaf's box when it is a
/// circle or a polyline, open or closed; else empty, which gives the full
/// height. Not the unit's top ([unitTopOfLeaves], spec S2's rule for
/// `SymbolDefinitionRef.top` and `UnitInfo.top`): today's label reads an
/// open polyline's box and never the other leaves (controller ruling
/// R-21; the placer, the unit API's new label and the fixtures read this).
Aabb2 placedLabelTop(List<(EntityKind, GeometryPayload)> leaves) {
  if (leaves.isEmpty) return Aabb2.empty();
  final (kind, p) = leaves.first;
  switch (kind) {
    case EntityKind.circle:
      final r = p.scalars[0];
      return Aabb2.raw(
          p.coords[0] - r, p.coords[1] - r, p.coords[0] + r, p.coords[1] + r);
    case EntityKind.polyline:
      final c = p.coords;
      var minX = c[0], maxX = c[0], minY = c[1], maxY = c[1];
      for (var i = 2; i + 1 < c.length; i += 2) {
        if (c[i] < minX) minX = c[i];
        if (c[i] > maxX) maxX = c[i];
        if (c[i + 1] < minY) minY = c[i + 1];
        if (c[i + 1] > maxY) maxY = c[i + 1];
      }
      return Aabb2.raw(minX, minY, maxX, maxY);
    default:
      return Aabb2.empty();
  }
}

/// [placedLabelTop] of [definition]'s first leaf in [target].
/// O(entities), at command rate.
Aabb2 placedLabelTopOf(CommandTarget target, Handle definition) {
  final leaf = firstLeafOf(target, definition);
  return leaf == null
      ? Aabb2.empty()
      : placedLabelTop([(leaf.kind, leaf.payload)]);
}

/// The command that adds [text] as the label of [instance], an instance of
/// [definition] placed by [placement]: anchored at the definition's base
/// point, the height of its top, stamped upright. Allocates one handle.
AddEntityCommand addUnitLabelCommand(
  DraftDocument doc, {
  required Handle instance,
  required Handle definition,
  required Transform2 placement,
  required String text,
}) {
  final def = doc.tree.definition(definition);
  return AddEntityCommand(
    record: unitLabelRecord(
        handle: doc.handleSeed.next(), instance: instance, text: text),
    payload: unitLabelPayload(
      anchor: def?.basePoint ?? Vector2.zero(),
      height: unitLabelHeight(placedLabelTopOf(doc, definition)),
      instanceToWorld: placement,
    ),
  );
}

/// The lowest-handle `UNIT` ATTRIB [instance] owns, or null. O(entities),
/// at command rate.
Handle? unitLabelOf(CommandTarget target, Handle instance) {
  final e = target.entities;
  Handle? best;
  for (final slot in e.liveSlots) {
    if (e.ownerAt(slot) != instance ||
        e.kindAt(slot) != EntityKind.attrib ||
        e.tagAt(slot) != kUnitLabelTag) {
      continue;
    }
    final h = e.handleAt(slot);
    if (best == null || h.value < best.value) best = h;
  }
  return best;
}
```

  `unitLabelHeight` of a definition whose first leaf is no top reads the leaves' box, where today's `tableLabelHeight` gave 200 (`table_label.dart:25-44`). K3 rule 11 makes a unit draw its top first, so no library unit takes that branch.

- [ ] **Step 5: `unit_problems.dart`.** Create `lib/src/units/unit_problems.dart`:

```dart
// The units' diagnostics and label warnings (spec 2b S2 "Diagnostics",
// "Unlabelled, duplicate and bad labels"): today's table codes and
// NumberingWarning (jet_cad_floor_plan/lib/src/tables/table_index.dart:
// 228-243; host/floor_plan_types.dart:197-243), renamed, plus the bad label.
import 'unit_label.dart' show UnitLabelProblem;

/// The codes `UnitIndex.diagnostics` raises.
abstract final class UnitProblem {
  static const String duplicateLabel = 'unit.duplicate_label';
  static const String unlabelled = 'unit.unlabelled';
  static const String badLabel = 'unit.bad_label';
  static const String extraLabel = 'unit.extra_label';
  static const String nested = 'unit.nested';

  /// Host data outside the limits: kept as read, reads as none.
  static const String invalidData = 'unit.invalid_data';

  /// A colour of another shape, or a swatch this release does not know:
  /// kept as read, drawn as none.
  static const String invalidColour = 'unit.invalid_colour';
}

/// A problem with the plan's unit labels, as a value the host words, or
/// asks `PlanStrings.labelWarning` to. Never a handle.
sealed class UnitLabelWarning {
  const UnitLabelWarning();
}

/// [count] live units carry [label].
final class DuplicateLabel extends UnitLabelWarning {
  const DuplicateLabel({required this.label, required this.count});

  final String label;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is DuplicateLabel && other.label == label && other.count == count;

  @override
  int get hashCode => Object.hash(label, count);

  @override
  String toString() => 'DuplicateLabel($label, $count)';
}

/// A live unit carries no label. Two of one symbol read alike: the host
/// sees how many there are.
final class Unlabelled extends UnitLabelWarning {
  const Unlabelled(
      {required this.kind, required this.capacity, required this.symbolKey});

  final String kind;
  final int capacity;
  final String? symbolKey;

  @override
  bool operator ==(Object other) =>
      other is Unlabelled &&
      other.kind == kind &&
      other.capacity == capacity &&
      other.symbolKey == symbolKey;

  @override
  int get hashCode => Object.hash(kind, capacity, symbolKey);

  @override
  String toString() => 'Unlabelled($kind, $capacity, $symbolKey)';
}

/// A live unit's [label] breaks the text rule ([problem]); it is still its
/// label, served by its text.
final class BadLabel extends UnitLabelWarning {
  const BadLabel({required this.label, required this.problem});

  final String label;
  final UnitLabelProblem problem;

  @override
  bool operator ==(Object other) =>
      other is BadLabel && other.label == label && other.problem == problem;

  @override
  int get hashCode => Object.hash(label, problem);

  @override
  String toString() => 'BadLabel($label, ${problem.name})';
}
```

- [ ] **Step 6: `unit_numbers.dart`.** Create `lib/src/units/unit_numbers.dart`:

```dart
// The next number of a placed numbered unit (spec 2b S2 "Placed,
// numbered"), today's nextTableNumber (jet_cad_floor_plan/lib/src/tables/
// table_numbers.dart:48-73), skipping any unit's label.
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show UnitLabelling;

import 'unit_index.dart';

final RegExp _counted = RegExp(r'^[0-9]{1,8}$');

/// The largest number written: eight digits.
const int _kLargestCounted = 99999999;

/// The value of [label] when it counts: 1 to 8 ASCII digits, leading zeros
/// allowed (`"07"` is 7). Null otherwise.
int? countedUnitNumber(String label) =>
    _counted.hasMatch(label) ? int.parse(label) : null;

/// `max + 1` over the counted [numbers] (trimmed), written without leading
/// zeros, then up by one while that text is in [labels]; `"1"` when none
/// counts. When that would take nine digits, the smallest positive integer
/// that is neither a counted number nor in [labels]. With [labels] empty,
/// today's nextTableNumber.
String nextUnitNumberOf(Iterable<String> numbers,
    [Set<String> labels = const {}]) {
  final used = <int>{};
  var max = 0;
  for (final n in numbers) {
    final v = countedUnitNumber(n.trim());
    if (v == null) continue;
    used.add(v);
    if (v > max) max = v;
  }
  var candidate = max + 1;
  while (candidate <= _kLargestCounted && labels.contains('$candidate')) {
    candidate++;
  }
  if (candidate <= _kLargestCounted) return '$candidate';
  candidate = 1;
  while (used.contains(candidate) || labels.contains('$candidate')) {
    candidate++;
  }
  return '$candidate';
}

/// The next number for a placed `numbered` unit of [index]: over the
/// placed numbered units' labels, skipping every unit's label.
String nextUnitNumber(UnitIndex index) => nextUnitNumberOf([
      for (final u in index.units)
        if (!u.generated &&
            u.labelling == UnitLabelling.numbered &&
            u.text != null)
          u.text!,
    ], {
      for (final u in index.units)
        if (u.text != null) u.text!,
    });
```

- [ ] **Step 7: `unit_components.dart`.** Create `lib/src/units/unit_components.dart`, ported from `jet_cad_floor_plan/lib/src/tables/table_data_component.dart:1-177` and `table_color_component.dart:1-101`. Adaptations, each exact:
  - Header comment: "A host's data and colour on a unit (spec 2b S2 \"Per-unit data\"), on the unit's **instance** node, placed or generated: ported from jet_cad_floor_plan's table_data_component.dart and table_color_component.dart. A generated unit keeps both while it keeps its handle (E5) and loses them when its row drops it."
  - Imports: `dart:convert` show `jsonEncode`; `package:jet_cad_2d/jet_cad_2d.dart`; `package:jet_cad_2d_kit/jet_cad_2d_kit.dart` show `PlanSwatch, planSwatchNamed`; `unit_label.dart` show `isControlCodeUnit`.
  - Renames: `kTableDataMaxKeys` → `kUnitDataMaxKeys`, `kTableDataMaxKeyLength` → `kUnitDataMaxKeyLength`, `kTableDataMaxValueLength` → `kUnitDataMaxValueLength`, `tableDataProblem` → `unitDataProblem`, `FloorPlanTableData` → `UnitData` (`componentTypeId = 'jetcad.unit_data'`), `FloorPlanTableColor` → `UnitColour` (`componentTypeId = 'jetcad.unit_colour'`), `FloorPlanColor` → `PlanSwatch`, `floorPlanColorNamed` → `planSwatchNamed`, `colorValue` → `swatch`; in doc comments "table" → "unit" and `TableSurvey.diagnostics` → `UnitIndex.diagnostics` (`unit.invalid_data`, `unit.invalid_colour`).
  - The two classes' `static void register(...)` are dropped; in their place, at the end of the file:

```dart
/// Registers [UnitData] and [UnitColour]. **Once per registry**: a second
/// registration replaces the stores and drops every unit's data and
/// colour.
void registerUnitComponents(ComponentRegistry registry) {
  registry.register<UnitData>(UnitData.componentTypeId, UnitData.fromJson);
  registry.register<UnitColour>(
      UnitColour.componentTypeId, UnitColour.fromJson);
}
```

  - `UnitColour`'s public constructor is `UnitColour(PlanSwatch swatch) : this._(swatch.name, null);` and its getter `PlanSwatch? get swatch => planSwatchNamed(name);`. Every other line (the limits, the lenient `fromJson`, `kept`, `isKept`, `_frozen`, `==`, `hashCode`, `toString` with the new class names) is copied unchanged.

- [ ] **Step 8: `unit_locks.dart`.** Create `lib/src/units/unit_locks.dart`:

```dart
// The one lock predicate of a unit (spec 2b S2 "Locked units"): its layer
// is locked (today's locked table), or 2a's lock set covers it (a placed
// unit of a missing kit's symbol, a frozen object's or a missing kit's
// object's seat, a seat of a missing kit's definition). Used by the service
// tool, unitDetails.locked, the record's strict match and the design writes.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show isKitId;

import '../kits/locks.dart';

/// Whether the unit [instance] of [document] is locked.
bool isLockedUnit(CommandTarget document, LockSet locks, Handle instance) {
  final node = document.tree[instance];
  if (node is InstanceNode &&
      (document.tables.layers[node.layer]?.locked ?? false)) {
    return true;
  }
  return locks.covers(document, instance);
}

/// The type id of the first unknown kit-namespaced component on [group] (a
/// kit id, then a dot; not `jetcad`, not `plan`): what a group the lock set
/// holds for a missing kit was, by the rule `LockSet` reads
/// (`locks.dart:67-77`). Null when it carries none.
String? heldTypeOf(CommandTarget document, Handle group) {
  for (final payload in document.components.unknownOf(group)) {
    final typeId = payload['typeId'];
    if (typeId is! String) continue;
    final dot = typeId.indexOf('.');
    if (dot <= 0) continue;
    final kit = typeId.substring(0, dot);
    if (isKitId(kit) && kit != 'jetcad' && kit != 'plan') return typeId;
  }
  return null;
}
```

- [ ] **Step 9: `unit_index.dart`.** Create `lib/src/units/unit_index.dart`:

```dart
// The units of a plan (spec 2b S2 "A unit", "UnitIndex", "Diagnostics",
// "Unlabelled, duplicate and bad labels"): every live symbol instance whose
// definition carries `jetcad.unit`, placed at the root or generated by an
// object, in one pass, with its label, its lock, its world transform and
// its definition-space top and box. Replaces jet_cad_floor_plan's
// TableSurvey (tables/table_index.dart:61-226); the top and box follow
// service/table_picker.dart:92-110, :259-299.
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show SymbolComponent, UnitComponent, UnitLabelling, kUnitLabelTag;

import '../kits/locks.dart';
import '../symbols/symbol_box.dart' show boxOfLeaves;
import 'unit_components.dart';
import 'unit_label.dart';
import 'unit_locks.dart';
import 'unit_problems.dart';

/// One unit.
final class UnitInfo {
  const UnitInfo({
    required this.instance,
    required this.definition,
    this.owner,
    this.ownerType,
    this.label,
    this.text,
    required this.kind,
    required this.capacity,
    required this.labelling,
    this.symbolKey,
    required this.locked,
    required this.visible,
    required this.toWorld,
    required this.top,
    required this.box,
  });

  final Handle instance;
  final Handle definition;

  /// The generating object (a root-level group); null when placed.
  final Handle? owner;

  /// The owner's type id, or the missing kit's component type id of a held
  /// group; null when placed.
  final String? ownerType;

  /// The lowest-handle `UNIT` ATTRIB; null when there is none.
  final Handle? label;

  /// [label]'s text, trimmed; null when unlabelled (no label, or an empty
  /// one).
  final String? text;

  final String kind;
  final int capacity;
  final UnitLabelling labelling;

  /// The definition's `jetcad.symbol` key; null for a hand-made one.
  final String? symbolKey;

  /// [isLockedUnit].
  final bool locked;

  /// The instance's layer is shown (a missing layer counts as shown).
  final bool visible;

  /// Definition space to world: the instance's transform, after its root
  /// group's for a generated unit.
  final Transform2 toWorld;

  /// Definition space: the served top (the first leaf, a closed polyline or
  /// a circle), else [box].
  final Aabb2 top;

  /// Definition space: the symbol's box.
  final Aabb2 box;

  bool get generated => owner != null;

  @override
  String toString() => 'UnitInfo(${instance.toHex()}, $text, $kind)';
}

/// The units of one document, and what their labels and data raise.
final class UnitIndex {
  UnitIndex._(this.units, this.nested, this._byInstance, this._extraLabels,
      this._keptData, this._invalidColour);

  /// One pass, O(nodes + entities): at document-change rate (through
  /// [UnitIndexCache]), never per frame.
  factory UnitIndex.of(CommandTarget document,
      {required ParametricCatalog catalog, required LockSet locks}) {
    final entities = document.entities;
    final tree = document.tree;
    final root = tree.root;
    // One bucketing pass: the UNIT labels by owner, every other leaf by
    // owner (a definition's leaves among them).
    final labels = <Handle, List<(Handle, String)>>{};
    final leaves = <Handle, List<int>>{};
    for (final slot in entities.liveSlots) {
      final owner = entities.ownerAt(slot);
      if (entities.kindAt(slot) == EntityKind.attrib) {
        if (entities.tagAt(slot) == kUnitLabelTag) {
          (labels[owner] ??= [])
              .add((entities.handleAt(slot), entities.textAt(slot)));
        }
        continue;
      }
      (leaves[owner] ??= []).add(slot);
    }
    final shapes = <Handle, (Aabb2, Aabb2)>{};
    (Aabb2, Aabb2) shapeOf(Handle definition) =>
        shapes.putIfAbsent(definition, () {
          final slots = [...?leaves[definition]]..sort((a, b) => entities
              .handleAt(a)
              .value
              .compareTo(entities.handleAt(b).value));
          final list = [
            for (final s in slots)
              (
                entities.kindAt(s),
                document.geometry.read(entities.geomIndexAt(s))
              ),
          ];
          final b = boxOfLeaves(list);
          return (
            unitTopOfLeaves(list),
            b == null
                ? Aabb2.empty()
                : Aabb2.raw(b.left, b.front, b.right, b.back),
          );
        });

    final units = <UnitInfo>[];
    final nested = <Handle>[];
    final extra = <Handle, List<Handle>>{};
    final kept = <Handle>{};
    final invalidColour = <Handle>{};
    // `tree.nodes` is ascending by handle (its contract), so both lists are
    // too.
    for (final node in tree.nodes) {
      if (node is! InstanceNode) continue;
      if (tree.definition(node.definition) == null) continue;
      final unit = document.components.get<UnitComponent>(node.definition);
      if (unit == null) continue;
      Handle? owner;
      String? ownerType;
      var toWorld = node.transform;
      if (node.parent != root) {
        final parent = tree[node.parent];
        if (parent is! GroupNode || parent.parent != root) {
          nested.add(node.handle);
          continue;
        }
        final typeId = catalog.typeIdOf(document, parent.handle);
        if (typeId == null && !locks.isLockedObject(parent.handle)) {
          nested.add(node.handle);
          continue;
        }
        owner = parent.handle;
        ownerType = typeId ?? heldTypeOf(document, parent.handle);
        toWorld = parent.transform.multiply(node.transform);
      }
      final own = labels[node.handle]
        ?..sort((a, b) => a.$1.value.compareTo(b.$1.value));
      if (own != null && own.length > 1) {
        extra[node.handle] = [for (final l in own.skip(1)) l.$1];
      }
      final layer = document.tables.layers[node.layer];
      final (top, box) = shapeOf(node.definition);
      units.add(UnitInfo(
        instance: node.handle,
        definition: node.definition,
        owner: owner,
        ownerType: ownerType,
        label: own?.first.$1,
        // An empty label is no label (today's demo review F-7).
        text: switch (own?.first.$2.trim()) {
          null || '' => null,
          final t => t,
        },
        kind: unit.kind,
        capacity: unit.capacity,
        labelling: unit.labelling,
        symbolKey:
            document.components.get<SymbolComponent>(node.definition)?.key,
        locked: isLockedUnit(document, locks, node.handle),
        visible: layer?.visible ?? true,
        toWorld: toWorld,
        top: top,
        box: box,
      ));
      if (document.components.get<UnitData>(node.handle)?.isKept ?? false) {
        kept.add(node.handle);
      }
      final colour = document.components.get<UnitColour>(node.handle);
      if (colour != null && colour.swatch == null) {
        invalidColour.add(node.handle);
      }
    }
    return UnitIndex._(
        List.unmodifiable(units),
        List.unmodifiable(nested),
        {for (final u in units) u.instance: u},
        Map.unmodifiable(extra),
        kept,
        invalidColour);
  }

  /// Every unit, served or not, ascending by instance handle.
  final List<UnitInfo> units;

  /// Unit instances that are neither placed nor generated (`unit.nested`),
  /// ascending.
  final List<Handle> nested;

  final Map<Handle, UnitInfo> _byInstance;
  final Map<Handle, List<Handle>> _extraLabels;
  final Set<Handle> _keptData;
  final Set<Handle> _invalidColour;

  UnitInfo? operator [](Handle instance) => _byInstance[instance];

  /// The units labelled [label] (trimmed, exact `==`), ascending.
  List<UnitInfo> withLabel(String label) {
    final l = label.trim();
    return [
      for (final u in units)
        if (u.text == l) u,
    ];
  }

  /// The units' diagnostics (spec S2), in a stable order: duplicates by
  /// first appearance; then per unit ascending: unlabelled or a bad label,
  /// extra labels, invalid data, an invalid colour; then the nested ones.
  List<Diagnostic> diagnostics() {
    final out = <Diagnostic>[];
    final byLabel = <String, List<Handle>>{};
    for (final u in units) {
      if (u.text case final t?) (byLabel[t] ??= []).add(u.instance);
    }
    for (final MapEntry(key: label, value: handles) in byLabel.entries) {
      if (handles.length < 2) continue;
      out.add(Diagnostic(
        severity: DiagnosticSeverity.warning,
        code: UnitProblem.duplicateLabel,
        message: 'Label $label is used by ${handles.length} units',
        handles: handles,
      ));
    }
    for (final u in units) {
      final h = u.instance;
      final text = u.text;
      if (text == null) {
        out.add(Diagnostic(
          severity: DiagnosticSeverity.warning,
          code: UnitProblem.unlabelled,
          message: 'Unit ${h.toHex()} has no label',
          handles: [h],
        ));
      } else if (unitLabelError(text) case final error?) {
        out.add(Diagnostic(
          severity: DiagnosticSeverity.warning,
          code: UnitProblem.badLabel,
          message: 'Unit ${h.toHex()} is labelled "$text" ($error); it is '
              'served by its text',
          handles: [h],
        ));
      }
      final more = _extraLabels[h];
      if (more != null) {
        out.add(Diagnostic(
          severity: DiagnosticSeverity.warning,
          code: UnitProblem.extraLabel,
          message: 'Unit ${h.toHex()} has ${more.length + 1} labels; the '
              'first is used',
          handles: [h, ...more],
        ));
      }
      if (_keptData.contains(h)) {
        out.add(Diagnostic(
          severity: DiagnosticSeverity.warning,
          code: UnitProblem.invalidData,
          message: 'Unit ${h.toHex()} carries host data outside the limits; '
              'it is kept as read and reads as none',
          handles: [h],
        ));
      }
      if (_invalidColour.contains(h)) {
        out.add(Diagnostic(
          severity: DiagnosticSeverity.warning,
          code: UnitProblem.invalidColour,
          message: 'Unit ${h.toHex()} carries a colour this release cannot '
              'read; it is kept as read and drawn as none',
          handles: [h],
        ));
      }
    }
    for (final h in nested) {
      out.add(Diagnostic(
        severity: DiagnosticSeverity.info,
        code: UnitProblem.nested,
        message: '${h.toHex()} is neither at the root nor an object\'s and '
            'is not a unit',
        handles: [h],
      ));
    }
    return out;
  }

  /// The label warnings a host sees (`labelWarnings`): [DuplicateLabel] in
  /// first-appearance order, then [Unlabelled], then [BadLabel], ascending.
  List<UnitLabelWarning> warnings() {
    final counts = <String, int>{};
    for (final u in units) {
      if (u.text case final t?) counts[t] = (counts[t] ?? 0) + 1;
    }
    return List.unmodifiable(<UnitLabelWarning>[
      for (final MapEntry(key: label, value: count) in counts.entries)
        if (count > 1) DuplicateLabel(label: label, count: count),
      for (final u in units)
        if (u.text == null)
          Unlabelled(
              kind: u.kind, capacity: u.capacity, symbolKey: u.symbolKey),
      for (final u in units)
        if (u.text case final t?)
          if (unitLabelProblem(t) case final p?)
            BadLabel(label: t, problem: p),
    ]);
  }
}

/// One session's [UnitIndex], rebuilt when the document's state id or its
/// tables' revision moves, or when [locked] has notified (a freeze moves no
/// state id, spec S2). A read with none of them moved returns the same
/// index.
final class UnitIndexCache {
  UnitIndexCache(this.document,
      {required this.catalog,
      required this.locks,
      required ValueListenable<Set<Handle>> locked})
      : _locked = locked {
    _locked.addListener(_lockedChanged);
  }

  final DraftDocument document;
  final ParametricCatalog catalog;
  final LockSet locks;
  final ValueListenable<Set<Handle>> _locked;

  UnitIndex? _index;
  int? _state;
  int? _revision;
  bool _stale = true;

  UnitIndex get current {
    final state = document.commands.stateId;
    final revision = document.tables.mutationRevision;
    final index = _index;
    if (index != null &&
        !_stale &&
        state == _state &&
        revision == _revision) {
      return index;
    }
    _state = state;
    _revision = revision;
    _stale = false;
    return _index = UnitIndex.of(document, catalog: catalog, locks: locks);
  }

  void _lockedChanged() => _stale = true;

  void dispose() => _locked.removeListener(_lockedChanged);
}
```

- [ ] **Step 10: Wire the session, the controller and the export copy.**
  1. `lib/src/controller/session.dart`: import `'../units/unit_index.dart'`. After `locks = LockSet.scan(document, kitLoaded);` (`:48`) add:

```dart
    // Spec 2b S2: the document's units, rebuilt on its state id, its
    // layers' revision and the controller's locked set.
    units = UnitIndexCache(document,
        catalog: catalog, locks: locks, locked: locked);
```

     After `late final LockExpander lockExpander;` (`:119`) add:

```dart
  /// The document's units (spec 2b S2, `UnitIndex`).
  late final UnitIndexCache units;
```

     In `dispose()` (`:267-283`), before `lockExpander.dispose();`, add `units.dispose();`.
  2. `lib/src/controller/plan_controller.dart`: import `'../units/unit_components.dart'` and `'../units/unit_index.dart'`. In `_register` (`:211-215`), after `registerKitComponents(r);` add `registerUnitComponents(r);`. After `isLocked` (`:527`) add:

```dart
  /// The design document's units (spec 2b S2). Task 11 re-points it at the
  /// active document.
  @internal
  UnitIndex get unitIndex => _session.units.current;
```

  3. `lib/src/export/page_flows.dart`: import `'../units/unit_components.dart' show registerUnitComponents;`. In `_copyOf`'s `registerComponents` (`:148-152`), after `registerKitComponents(r);` add `registerUnitComponents(r);` (the export copy reads unit colours typed; Task 15's fills read them).
  4. `test/support/harness.dart`: import `package:jet_cad_2d_plan/src/units/unit_components.dart` show `registerUnitComponents`; in `registerPlanComponents` (`:32-37`), after `registerKitComponents(registry);` add `registerUnitComponents(registry);`, and its doc becomes "The page, the contract's four components, the unit components and [catalog]'s: what a plan document registers."

- [ ] **Step 11: Run the new tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/units/units_test.dart`. Expected: `All tests passed!` (eleven tests).

- [ ] **Step 11b: UI-def-missing (ruling R-24).** Add to `test/units/units_test.dart` a test `UI-def-missing`: build `serviceFixture()`'s plan, then make a copy of its text in which the first row's component names a definition handle that no definition carries (edit the JSON: replace that handle's hex in the row component's definition field with an unused handle's hex, `doc.handleSeed.next()` of a scratch decode). Load the copy into a `PlanController(kits: [unitKit()])`. Expect: the row is in `controller.frozen` (2a's boundary probed it after the load: `probe` returns `GeneratedDefinitionError`), its seats are still units of `controller.unitIndex` and read `locked`, its seats' handles and labels are those of the original plan (no regeneration ran), and `controller.diagnostics.value` holds one entry naming the row. Mutation M-UI-def: in Task 1's `_plan`, skip the live-definition check (the planner then adds an `InstanceNode` with a dead definition and the load throws or the row is not frozen) → `UI-def-missing` red. Run: `cd packages/jet_cad_2d_plan && flutter test test/units/units_test.dart --plain-name UI-def-missing`; expected `+1: All tests passed!`.

- [ ] **Step 12: Port the units' tests.** Assertions unchanged in every ported test; only the fixture, the subjects named below, the imports and the names change. Each file starts with `// Ported from jet_cad_floor_plan/test/<file>; assertions unchanged.` and imports `package:jet_cad_2d_plan/src/units/…` and `../support/unit_fixtures.dart` in place of the `jet_cad_floor_plan` imports. Not ported here: `TL1`, `TL2`, `TL4` (the kit's stamp, height and payload: Task 3), `TL3` (the restamp: Task 7), `TD7`-`TD10` (they need the placed number and the label system: Task 7).
  1. **`test/units/unit_index_test.dart`** from `floor_plan/test/tables/table_index_test.dart`: `TI1` (`:37-67`), `TI2` (`:69-82`), `TI3` (`:84-94`), `TI4` (`:96-173`), `TI4b` (`:175-192`), `TI5` (`:194-211`), `TI6` (`:213-224`), with the helpers `place` (`:17-24`) and `label` (`:26-34`). Adaptations:
     - `place`: `placeSymbol(doc, entry, at: at, quarterTurns: quarterTurns, mirrored: mirrored, numbered: false)` → `placeSymbol(doc, entry, at: at, quarterTurns: quarterTurns, mirrored: mirrored)` (2a's placer writes no label: `numbered: false`'s behaviour).
     - `label(doc, i, number)` → `labelUnit(doc, i, number)`; `addTableLabelCommand(doc, …, number: n)` → `addUnitLabelCommand(doc, …, text: n)`.
     - `tablesOf(doc)` → `unitIndexOf(doc).units`; `TableSurvey.of(doc)` → `unitIndexOf(doc)`; `survey.tables` → `.units`; `survey.numbers` → `labelsOf(survey)`; `withNumber` → `withLabel`; `t.number` → `t.text`; `t.seats` → `t.capacity`; `tableDiagnostics(doc)` → `unitIndexOf(doc).diagnostics()`.
     - The codes: `'table.duplicate_number'` → `UnitProblem.duplicateLabel`, `'table.unnumbered'` → `UnitProblem.unlabelled`, `'table.extra_label'` → `UnitProblem.extraLabel`, `'table.nested'` → `UnitProblem.nested` (their values `'unit.…'`, spec S2).
     - `TI4b`: `SetComponentCommand<SeatingComponent>(def, SeatingComponent(seats: 3))` → `SetComponentCommand<UnitComponent>(def, UnitComponent(kind: UnitKinds.table, capacity: 3))`.
     - `TI5`: `command.record.copyWith(tag: 'REF')` stays; the second ATTRIB's `kind: EntityKind.text` stays.
     - **Finding P-1 (fixture keys), for the ledger:** `TI1`'s `symbolKey` list `['test.stool', 'test.table', 'test.stool', 'test.table']` names the fixture's keys. K2's key rule refuses `test.stool` (`isSymbolKey`: a kit id, then two or more segments; `symbol_component.dart:36-42`), so the fixture's keys are `fx.stool.round` and `fx.table.two` (R-19). The asserted list becomes `['fx.stool.round', 'fx.table.two', 'fx.stool.round', 'fx.table.two']`: the same values, the fixture's keys (controller ruling R-19: one fixture file, its keys under the fixture kit `fx`). This follows 2a's precedent (2a results note, "three fixture keys", Task 14 deviation 9). Accepted by controller ruling R-10 (P-1); the implementer records it in the ledger.
  2. **`test/units/unit_numbers_test.dart`** from `floor_plan/test/tables/table_numbers_test.dart`: `TN1`-`TN6` (`:7-46`), `TN7`, `TN8` (`:48-78`). Adaptations: `nextTableNumber(x)` → `nextUnitNumberOf(x)`; `countedTableNumber` → `countedUnitNumber`; `tableNumberError` → `unitLabelError`; the groups are named `nextUnitNumberOf (S2)` and `unitLabelError (S2)`.
  3. **`test/units/unit_components_test.dart`** from `floor_plan/test/tables/table_data_test.dart` `TD1`-`TD6` (`:85-248`) with the helpers `hostData`, `key64`, `value1024`, `astral1024`, `astral1025`, `placeTable`, `dataOf` (`:22-41`, `:57-73`), and from `floor_plan/test/host/table_color_test.dart` `TC1` (`:123-175`). Adaptations:
     - `FloorPlanTableData` → `UnitData`; `tableDataProblem` → `unitDataProblem`; `'jetcad.table_data'` → `'jetcad.unit_data'` (`TD3`'s `typeId`, `TD6`'s JSON key); `TableDiagnosticCodes.invalidData` → `UnitProblem.invalidData` and `'table.invalid_data'` → `'unit.invalid_data'` (`TD6`).
     - `placeTable(doc, at, …)` places `entryOf(tableSymbol())` with 2a's `placeSymbol` and returns `unitIndexOf(doc).units.reduce((a, b) => a.instance.value > b.instance.value ? a : b)` (a `UnitInfo`; `.instance` as before). `TD1`-`TD6` read no label.
     - `TD6`: `registerAppComponents` → `(r) => registerPlanComponents(r, ParametricCatalog())`; `tableDiagnostics(back)` → `unitIndexOf(back).diagnostics()`.
     - `TC1`: `FloorPlanTableColor` → `UnitColour`; `teal`, `purple` → `PlanSwatch.teal`, `PlanSwatch.purple`; `colorValue` → `swatch`.
  4. **`test/units/unit_label_test.dart`** from `floor_plan/test/tables/table_label_test.dart`: `TL5` (`:114-130`), `TL6` (`:132-159`), `TL7` (`:161-179`). Adaptations: `tableLabelRecord(…, number: x)` → `unitLabelRecord(…, text: x)`; `TL5`'s `expect(r.tag, 'TABLE')` → `expect(r.tag, 'UNIT')` (the tag renamed, spec S2: "today's TABLE, renamed"); `TL6`: `placeSymbol(…, numbered: false)` → `placeSymbol(…)`, `addTableLabelCommand(…, number: '7')` → `addUnitLabelCommand(…, text: '7')`; `TL7`: `firstLeafOf` is this task's (`CommandTarget` for `DraftDocument`).

- [ ] **Step 13: Run the ported tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/units`. Expected: `All tests passed!`. A ported test that fails on an assertion is a finding: stop and report it; never change the assertion.

- [ ] **Step 14: Format and the gate.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`. Each exits 0. `git status --short` lists only this task's files.

- [ ] **Step 15: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/units/unit_label.dart packages/jet_cad_2d_plan/lib/src/units/unit_problems.dart packages/jet_cad_2d_plan/lib/src/units/unit_numbers.dart packages/jet_cad_2d_plan/lib/src/units/unit_components.dart packages/jet_cad_2d_plan/lib/src/units/unit_locks.dart packages/jet_cad_2d_plan/lib/src/units/unit_index.dart packages/jet_cad_2d_plan/lib/src/controller/session.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/lib/src/export/page_flows.dart packages/jet_cad_2d_plan/test/support/harness.dart packages/jet_cad_2d_plan/test/support/unit_fixtures.dart packages/jet_cad_2d_plan/test/units/units_test.dart packages/jet_cad_2d_plan/test/units/unit_index_test.dart packages/jet_cad_2d_plan/test/units/unit_numbers_test.dart packages/jet_cad_2d_plan/test/units/unit_components_test.dart packages/jet_cad_2d_plan/test/units/unit_label_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): units: the index, labels, numbering, data, locks (2b S2)

UnitIndex reads every unit in one pass: placed at the root, or
generated by a registered type's object or a held one, with its
lowest-handle UNIT label, its lock (a locked layer or 2a's lock set),
its world transform and its top and box. Its diagnostics and label
warnings keep today's table rules, plus the bad label. A session's
cache rebuilds on the state id, the layers and the locked set.
nextUnitNumber skips any unit's label. jetcad.unit_data and
jetcad.unit_colour sit on the instance, placed or generated.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 16: Mutation check** (on the committed files; after each: run the named test, quote its red line, `git checkout -- <file>`, `git diff --quiet -- <file>` exits 0):
  - M-UI-generated `lib/src/units/unit_index.dart`: `final typeId = catalog.typeIdOf(document, parent.handle);` → `final String? typeId = null;` → `UI-generated` red (the seats are nested).
  - M-UI-held `unit_index.dart`: `if (typeId == null && !locks.isLockedObject(parent.handle)) {` → `if (typeId == null) {` → `UI-missing-kit` and `UI-flip` red.
  - M-UI-object `unit_index.dart`: the same line → `if (false) {` → `UI-flip` red (the plain group's unit is generated).
  - M-UI-locked-key `unit_index.dart`: delete `_locked.addListener(_lockedChanged);` → `UI-frozen-no-edit` red (the seats read unlocked).
  - M-UI-covers `lib/src/units/unit_locks.dart`: `return locks.covers(document, instance);` → `return false;` → `UI-def-kit-missing` red.
  - M-UI-scan `lib/src/kits/locks.dart`: in `LockSet.scan`, `(node is InstanceNode && definitions.contains(node.definition))` → `false` → `UI-held-seat-row-locked` red (the edit applies).
  - M-UI-dup `unit_index.dart`: in `diagnostics()`, `if (handles.length < 2) continue;` → `if (handles.length < 3) continue;` → `UI-dup` red.
  - M-UI-unlabelled `unit_index.dart`: `null || '' => null,` → `null => null,` → `UI-unlabelled` red.
  - M-UI-bad `unit_index.dart`: delete the `else if (unitLabelError(text) case final error?) { … }` branch → `UI-bad` red.
  - M-UI-next-skip `lib/src/units/unit_numbers.dart`: `while (candidate <= _kLargestCounted && labels.contains('$candidate')) {` → `while (false) {` → `UI-next` red (`13`).
  - M-UI-next-fallback `unit_numbers.dart`: `while (used.contains(candidate) || labels.contains('$candidate')) {` → `while (used.contains(candidate)) {` → `UI-next` red (`1`).
  - M-UI-registered `lib/src/controller/plan_controller.dart`: delete `registerUnitComponents(r);` from `_register` → `UI-registered` red.
  - M-TN-max (the ported `TN2`'s, M-14a-1) `unit_numbers.dart`: `if (v > max) max = v;` → `max++;` → `TN2` red.
  - M-TI-label (the ported `TI4`'s) `unit_index.dart`: `?..sort((a, b) => a.$1.value.compareTo(b.$1.value));` → `;` (unsorted) → `TI4` red (`earlyLabel` is not the label).

#### Assumed from earlier tasks

Each name below is used as written; where the earlier task named it otherwise, the implementer uses that task's name and reports the difference.
- Task 2: a components-only write on a generated instance passes the guard (`UI-registered` colours a seat).
- Task 3: `kUnitLabelTag`, `kUnitLabelTextAttrs`, `unitLabelHeight(Aabb2 top)` (`min(200, 0.4 × min side)`, 200 for an empty box), `unitLabelPayload({anchor, height, instanceToWorld})` (coords `[anchor]`, scalars `[height, rotation, widthFactor]`), exported from the kit's barrel.
- Task 5: the names in its Produces.
- 2a: `PlanController.missingKits`, `lockBroken`, `lockHint`, `execute`, `save`, `isLocked`, `locked`; `planText`, `controllerFor`, `catalogOf` (`test/support/harness.dart`); `symbolKit` (`test/support/symbol_fixtures.dart:229-232`).

#### Interface problem

1. Resolved by R-8 (`List<Diagnostic> diagnostics()`; the Shared interfaces say so).
2. Resolved by R-9 (spec S2 amended on the branch, "A held object stays held"; `UI-flip` pins served and locked, the kit missing or loaded).
3. Resolved by R-10 (`PlanController.unitIndex` lands here).

---

