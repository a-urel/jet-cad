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
