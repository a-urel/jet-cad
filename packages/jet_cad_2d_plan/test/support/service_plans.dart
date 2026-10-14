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
import 'unit_fixtures.dart' show kDeg37;

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
        handle: def, name: '$key@1', basePoint: base, children: const [])),
    SetComponentCommand<SymbolComponent>(
        def,
        SymbolComponent(
            key: key,
            version: 1,
            name: name,
            category: 'Service',
            tags: const ['service'])),
    if (unit)
      SetComponentCommand<UnitComponent>(def,
          UnitComponent(kind: kind, capacity: capacity, labelling: labelling)),
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
          key: 'test.stool.round.one', name: 'Stool', capacity: 1, round: true);
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
              at: Vector2(300, -2100), basePoint: stool.base, quarterTurns: 2),
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
      placeDef(
          d, table, turned(table, -2600.25, 1400.5, kDeg37, mirrored: true),
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
