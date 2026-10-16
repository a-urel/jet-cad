// The zone fixture (3a Task 28, R-16, ruling IA-R6): 2b's
// (jet_cad_2d_plan/test/support/unit_zone_fixture.dart, the parts CZ1
// reads) with today's walled room named `7` restored
// (jet_cad_floor_plan/test/host/zone_fixture.dart:81-90: `twoRoomWalls` at
// `Placement('room 7', 66000, -21000, 23)`, the room seeded at
// `room.at(1512.5, 1987.25)`), built over the public libraries through
// `planWith`, `plans.dart`'s `buildPlan`, `room_plans.dart`'s `addRoom` and
// `units.dart`'s placement and labels. The zone spec's fixture (2026-10-08,
// Testing; 14c R-2): servable units with an asymmetric top, turned 37
// degrees, some mirrored, 40 m off the origin; a unit on a hidden layer and
// one on a locked layer; a label used twice, `B4`, an unlabelled unit; two
// look-alikes far from unit 7 -- a TEXT `7` and the room named `7` -- and
// unit 7 itself labelled ` 7 `. Expectations are computed from the symbols'
// own boxes by the forward transform.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform;
import 'package:jet_cad_2d_kit/authoring.dart'
    show CatalogCircle, CatalogPolyline, CatalogSymbol, CatalogUnit;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'plans.dart' show Placement, addRoom, buildPlan, planWith, twoRoomWalls;
import 'units.dart';

/// A stool: a servable one-seat unit, two circles
/// (jet_cad_2d_plan/test/support/unit_fixtures.dart:70-78).
const CatalogSymbol stoolSymbol = CatalogSymbol(
  key: 'fx.stool.round',
  name: 'Test stool',
  category: 'Tests',
  tags: ['stool', 'test'],
  unit: CatalogUnit(kind: UnitKinds.table, capacity: 1),
  base: (400, 300),
  shapes: [CatalogCircle((400, 300), 190), CatalogCircle((400, 300), 150)],
);

/// A trapezoid top, its base point off its box's centre
/// (unit_fixtures.dart:109-120).
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

/// The symbols' boxes in definition space, by symbol key: what the test
/// knows of each symbol without asking the document.
final Map<String, Aabb2> zoneSymbolBoxes = {
  trapezoidTable.key: const Aabb2.raw(200, 300, 1600, 1000),
  tableSymbol().key: const Aabb2.raw(300, -50, 1500, 1450),
  stoolSymbol.key: const Aabb2.raw(210, 110, 590, 490),
};

/// A non-identity camera (panned, 0.37 px/mm), set before every call.
ViewportTransform zoneCamera() => ViewportTransform(
    worldToScreenMatrix: Transform2(0.37, 0, 0, -0.37, 311.5, -207.25));

/// Places [s] with its base point at ([x], [y]), turned 37 degrees,
/// [mirrored], labelled [label] (unlabelled when null), on [layer] when
/// given. Returns the instance.
Handle placeZoneTable(
    DraftDocument doc, CatalogSymbol s, double x, double y, String? label,
    {bool mirrored = false, Handle? layer}) {
  final h = placeUnit(doc, s,
      transform: placementAt(x, y, kDeg37,
          mirrored: mirrored, baseX: s.base.$1, baseY: s.base.$2),
      layer: layer);
  if (label != null) labelUnit(doc, h, label);
  return h;
}

/// The fixture plan, as a file. Tables, by the number a host asks for:
/// - `3`: the trapezoid, mirrored, at (40,000, -27,000);
/// - `7` (labelled ` 7 `): the trapezoid, 2.4 m above 3;
/// - `2`, twice: 6.5 m apart;
/// - `A1`, `A2`: the trapezoid, 10 m apart in x, at one height;
/// - `5`: on the hidden layer `Hidden`;
/// - `L`: the trapezoid, mirrored, on the locked layer `L`;
/// - `B4`: a stool; and an unnumbered table.
/// A TEXT `7` and a room named `7` stand 20 m and more from table 7.
String zonePlanJson() => planWith((doc) {
      final room = buildPlan(doc, twoRoomWalls,
          place: const Placement('room 7', 66000, -21000, 23));
      addRoom(doc, room.at(1512.5, 1987.25), '7');

      final hidden = addLayer(doc, 'Hidden', visible: false);
      final locked = addLayer(doc, 'L', locked: true);
      placeZoneTable(doc, trapezoidTable, 40000, -27000, '3', mirrored: true);
      placeZoneTable(doc, trapezoidTable, 40000, -24600, ' 7 ');
      placeZoneTable(doc, tableSymbol(), 52000, -27000, '2');
      placeZoneTable(doc, tableSymbol(), 52500, -20500, '2', mirrored: true);
      placeZoneTable(doc, trapezoidTable, 40000, -36000, 'A1', mirrored: true);
      placeZoneTable(doc, trapezoidTable, 50000, -36000, 'A2');
      placeZoneTable(doc, tableSymbol(), 46000, -27000, '5', layer: hidden);
      placeZoneTable(doc, trapezoidTable, 46000, -31000, 'L',
          mirrored: true, layer: locked);
      placeZoneTable(doc, stoolSymbol, 36000, -31000, 'B4');
      placeZoneTable(doc, tableSymbol(), 36000, -21000, null);

      // A TEXT `7` at the root, far from table 7: a UNIT label's record and
      // payload as a TEXT with no tag (unit_zone_fixture.dart:91-100).
      doc.commands.execute(AddEntityCommand(
          record: EntityRecord(
            handle: doc.handleSeed.next(),
            owner: doc.rootHandle,
            kind: EntityKind.text,
            layer: ReservedHandles.layerZero,
            linetype: ReservedHandles.byBlockLinetype,
            linetypeScale: 1.0,
            geomIndex: 0,
            color: const ByBlockColor(),
            lineweight: kByBlock,
            transparency: kByBlock,
            flags: 0,
            text: '7',
            tag: '',
            textStyle: ReservedHandles.standardTextStyle,
            textAttrs: kUnitLabelTextAttrs,
          ),
          payload: unitLabelPayload(
              anchor: Vector2(60500, -41000),
              height: 300,
              instanceToWorld: Transform2.identity())));
    }, kits: [architectureKit, fxKit()]);

/// The anchors of every TEXT reading `7` in [doc], world: the look-alikes.
List<Vector2> sevenTexts(DraftDocument doc) {
  final e = doc.entities;
  return [
    for (final slot in e.liveSlots)
      if (e.kindAt(slot) == EntityKind.text && e.textAt(slot).trim() == '7')
        _worldAnchor(doc, e.handleAt(slot)),
  ];
}

Vector2 _worldAnchor(DraftDocument doc, Handle text) {
  final slot = doc.entities.slotOf(text)!;
  final p = doc.geometry.read(doc.entities.geomIndexAt(slot)).coords;
  final owner = doc.entities.ownerAt(slot);
  return doc.tree
      .accumulatedTransform(owner)
      .transformPoint(Vector2(p[0], p[1]));
}

/// The world bound of the units of [doc] carrying one of [numbers]
/// (trimmed): each one's symbol box, its four corners through its
/// transform. Every layer counts: the caller names the units it expects.
/// (2b's reads the plan's unit index; here `units.dart`'s labels.)
Aabb2 boundOf(DraftDocument doc, Set<String> numbers) {
  var box = Aabb2.empty();
  for (final n in numbers) {
    for (final h in unitsLabelled(doc, n)) {
      final node = doc.tree[h]! as InstanceNode;
      final key = doc.components.get<SymbolComponent>(node.definition)!.key;
      final b = zoneSymbolBoxes[key]!;
      box = box.union(Aabb2.fromPoints([
        for (final (x, y) in [
          (b.minX, b.minY),
          (b.maxX, b.minY),
          (b.maxX, b.maxY),
          (b.minX, b.maxY),
        ])
          node.transform.transformPoint(Vector2(x, y)),
      ]));
    }
  }
  return box;
}

/// [got] equals [want], each coefficient within a relative 1e-12.
void expectCamera(ViewportTransform? got, ViewportTransform want,
    {String? reason}) {
  expect(got, isNotNull, reason: reason);
  final g = got!.worldToScreenMatrix, w = want.worldToScreenMatrix;
  final gs = [g.a, g.b, g.c, g.d, g.e, g.f];
  final ws = [w.a, w.b, w.c, w.d, w.e, w.f];
  for (var i = 0; i < 6; i++) {
    expect(gs[i], closeTo(ws[i], 1e-12 * ws[i].abs()),
        reason: '${reason ?? ''} [$i]');
  }
}
