// The units' fixture (2b Task 6; Task 8 adds the picker's helpers, two
// more tables, `rowOfTables` and `CountingTransform`, and Tasks 7, 9, 10,
// 14 and 15 reuse it), ported from
// jet_cad_floor_plan's test/tables/table_fixture.dart: a servable table
// symbol, a stool, a planter, a table with one chair and a trapezoid, and a
// plan to place them in. A symbol is a CatalogSymbol; its SymbolEntry is
// built by hand, never through a library, so a unit that breaks the
// library's outline rule (Task 8's open table) can still be placed. The
// keys are under the fixture kit `fx` with two segments (K2's key rule,
// `isSymbolKey`; controller rulings R-10 P-1 and R-19). Base points and
// placements are off the origin (the degenerate-fixture rule).
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
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
import 'package:jet_cad_2d_plan/src/service/unit_picker.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart'
    show definitionForEntry, placementTransform;
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
      CatalogCircle(center: (final x, final y), :final radius) => (
          EntityKind.circle,
          circlePayload(Vector2(x, y), radius)
        ),
      CatalogLine(from: (final ax, final ay), to: (final bx, final by)) => (
          EntityKind.line,
          linePayload(Vector2(ax, ay), Vector2(bx, by))
        ),
      _ => throw UnsupportedError('no arc in the unit fixtures'),
    };
    leaves
        .add((record: leafRecord(next++, definition, kind), payload: payload));
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

/// One chair right of the top: the box spans x 300..1850.
const CatalogSymbol sideChairTable = CatalogSymbol(
  key: 'fx.table.side',
  name: 'Side chair table',
  category: 'Tests',
  tags: ['table', 'test'],
  unit: CatalogUnit(kind: UnitKinds.table, capacity: 1),
  base: (900, 700),
  shapes: [
    CatalogPolyline([(300, 300), (1500, 300), (1500, 1100), (300, 1100)],
        closed: true),
    CatalogPolyline([(1400, 475), (1850, 475), (1850, 925), (1400, 925)],
        closed: true),
  ],
);

/// A unit whose first leaf is an open polyline: no top (R-8). A library
/// refuses it (K3 rule 11); a plan file may hold it.
const CatalogSymbol openTable = CatalogSymbol(
  key: 'fx.table.open',
  name: 'Open table',
  category: 'Tests',
  tags: ['table', 'test'],
  unit: CatalogUnit(kind: UnitKinds.table, capacity: 2),
  base: (900, 700),
  shapes: [
    CatalogPolyline([(300, 300), (1500, 300), (1500, 1100), (300, 1100)]),
    CatalogPolyline([(675, -50), (1125, -50), (1125, 400), (675, 400)],
        closed: true),
  ],
);

/// An empty plan over [fxKit] (the page, the contract's components), in
/// millimetres, no system installed.
DraftDocument unitPlan() => planDocument([fxKit()]);

/// Places [s] by [transform] on [layer] (layer 0 by default): its
/// definition copied on first use (definitionForEntry), one instance, one
/// step, **no label** (a test adds one with [addUnitLabel]). Returns the
/// instance.
Handle placeUnit(DraftDocument doc, CatalogSymbol s,
    {required Transform2 transform, Handle? layer}) {
  final made = definitionForEntry(doc, entryOf(s));
  final h = doc.handleSeed.next();
  doc.commands.execute(CompoundCommand([
    ...made.commands,
    AddNodeCommand(InstanceNode(
        handle: h,
        parent: doc.rootHandle,
        definition: made.definition,
        layer: layer ?? ReservedHandles.layerZero,
        transform: transform)),
  ], label: 'Place ${s.name}'));
  return h;
}

/// [s] placed with its base point at [at], [quarterTurns] counter-clockwise
/// and [mirrored] (the placer's transform, symbol_placer.dart:48).
Handle placeAt(DraftDocument doc, CatalogSymbol s, Vector2 at,
        {int quarterTurns = 0, bool mirrored = false}) =>
    placeUnit(doc, s,
        transform: placementTransform(
            at: at,
            basePoint: Vector2(s.base.$1, s.base.$2),
            quarterTurns: quarterTurns,
            mirrored: mirrored));

/// Places [s] mirrored (by default) at [at], then turns it by 37 degrees
/// about [at]. Returns the instance node.
InstanceNode placeTurned(DraftDocument doc, CatalogSymbol s, Vector2 at,
    {bool mirrored = true}) {
  final h = placeAt(doc, s, at, mirrored: mirrored);
  final node = doc.tree[h]! as InstanceNode;
  final turn = Transform2.translation(at.x, at.y)
      .multiply(Transform2.rotation(kDeg37))
      .multiply(Transform2.translation(-at.x, -at.y));
  doc.commands.execute(TransformNodeCommand(h, turn.multiply(node.transform)));
  return doc.tree[h]! as InstanceNode;
}

Vector2 worldOf(InstanceNode n, double x, double y) =>
    n.transform.transformPoint(Vector2(x, y));

/// A layer [name] beside layer 0.
Handle addLayer(DraftDocument doc, String name,
    {bool visible = true, bool locked = false}) {
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  final h = doc.handleSeed.next();
  doc.commands.execute(AddLayerCommand(LayerRecord(
      handle: h,
      name: name,
      color: const IndexedColor(4),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: visible,
      locked: locked)));
  return h;
}

/// Adds [text] as [instance]'s UNIT label, stamped as a placed unit's
/// (spec S2): Task 6's [labelUnit] (`addUnitLabelCommand`: owned by the
/// instance, layer 0, BYBLOCK, the standard text style, anchored at the
/// definition's base point, upright in the world, today's height rule,
/// controller ruling R-21). One step. Returns the label's handle.
Handle addUnitLabel(DraftDocument doc, Handle instance, String text) =>
    labelUnit(doc, doc.tree[instance]! as InstanceNode, text);

/// A unit index cache over [doc] with nothing locked and no type,
/// disposed at tear-down. Call inside a test.
UnitIndexCache unitsOf(DraftDocument doc, {ParametricCatalog? catalog}) {
  final locked = ValueNotifier<Set<Handle>>(const {});
  final cache = UnitIndexCache(doc,
      catalog: catalog ?? ParametricCatalog(),
      locks: LockSet.scan(doc, (_) => true),
      locked: locked);
  addTearDown(() {
    cache.dispose();
    locked.dispose();
  });
  return cache;
}

/// A picker over [doc] ([unitsOf]); the options and seams as UnitPicker's.
UnitPicker pickerOf(DraftDocument doc,
        {bool skipLocked = false,
        bool placedOnly = false,
        Map<Handle, List<int>> Function()? leavesByOwner,
        Transform2 Function(Transform2 transform)? invert}) =>
    UnitPicker(doc, unitsOf(doc),
        skipLocked: skipLocked,
        placedOnly: placedOnly,
        leavesByOwner: leavesByOwner,
        invert: invert);

/// [n] trapezoid tables 40 m off the origin, ten to a row 2.5 m apart,
/// each mirrored and turned 37 degrees about its base point.
DraftDocument rowOfTables(int n) {
  final doc = unitPlan();
  for (var i = 0; i < n; i++) {
    final at = Vector2(40000.0 + 2500 * (i % 10), -27000.0 - 2500 * (i ~/ 10));
    placeTurned(doc, trapezoidTable, at);
  }
  return doc;
}

final class Tally {
  int count = 0;
}

/// A candidate's inverse that counts every new object it is asked for: a
/// point or a direction mapped, a product, an inverse, a list, a string.
/// The coefficients are read as fields, which build nothing.
final class CountingTransform extends Transform2 {
  CountingTransform(Transform2 m, this.made)
      : super(m.a, m.b, m.c, m.d, m.e, m.f);

  final Tally made;

  @override
  Vector2 transformPoint(Vector2 p) {
    made.count++;
    return super.transformPoint(p);
  }

  @override
  Vector2 transformDirection(Vector2 v) {
    made.count++;
    return super.transformDirection(v);
  }

  @override
  Transform2 multiply(Transform2 other) {
    made.count++;
    return super.multiply(other);
  }

  @override
  Transform2 invert() {
    made.count++;
    return super.invert();
  }

  @override
  List<double> toJson() {
    made.count++;
    return super.toJson();
  }

  @override
  String toString() {
    made.count++;
    return super.toString();
  }
}

/// [values] as a Float64List (the tops' expectations).
Float64List f64(List<double> values) => Float64List.fromList(values);
