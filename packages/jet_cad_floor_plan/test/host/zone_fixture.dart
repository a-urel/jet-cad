// The zone spec's fixture (2026-10-08, Testing; 14c R-2): servable tables
// with an asymmetric top, turned 37 degrees, some mirrored, 40 m off the
// origin; a table on a hidden layer and one on a locked layer; a number used
// twice, `B4`, an unnumbered table; look-alikes far from table 7 -- a TEXT
// and a room named `7` -- and table 7 itself labelled ` 7 `. Expectations
// are computed from the symbols' own boxes by the forward transform.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform;
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';
import 'package:jet_cad_floor_plan/symbols.dart' show FurnitureSymbol;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/room_fixture.dart';
import '../tables/table_fixture.dart';

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

/// Adds a layer by command; returns its handle.
Handle addZoneLayer(DraftDocument doc, String name,
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

/// Places [s] with its base point at ([x], [y]), turned 37 degrees,
/// [mirrored], labelled [label] (unnumbered when null), on [layer] when
/// given. Returns the instance.
Handle placeZoneTable(
    DraftDocument doc, FurnitureSymbol s, double x, double y, String? label,
    {bool mirrored = false, Handle? layer}) {
  doc.commands.execute(placeSymbol(doc, entryOf(s),
      at: Vector2(x, y),
      transform: placementAt(x, y, kDeg37,
          mirrored: mirrored, baseX: s.baseX, baseY: s.baseY),
      numbered: label != null));
  final t = TableSurvey.of(doc).tables.last;
  if (label != null) {
    doc.commands.execute(SetEntityTextCommand(t.label!, label, kTableLabelTag));
  }
  if (layer != null) {
    doc.commands.execute(SetInstanceLayerCommand(t.instance, layer));
  }
  return t.instance;
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
String zonePlanJson() {
  final room = buildPlan(twoRoomWalls,
      place: const Placement('room 7', 66000, -21000, 23));
  final doc = room.doc;
  registerAppComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  addRoom(doc, room.at(1512.5, 1987.25), '7');
  room.system.dispose();

  final hidden = addZoneLayer(doc, 'Hidden', visible: false);
  final locked = addZoneLayer(doc, 'L', locked: true);
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

  // A TEXT `7` at the root, far from table 7.
  doc.commands.execute(AddEntityCommand(
      record: tableLabelRecord(
              handle: doc.handleSeed.next(),
              instance: doc.rootHandle,
              number: '7')
          .copyWith(kind: EntityKind.text, tag: ''),
      payload: tableLabelPayload(
          anchor: Vector2(60500, -41000),
          height: 300,
          placement: Transform2.identity())));
  final json = DraftDocumentCodec.encodeToString(doc);
  doc.dispose();
  return json;
}

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

/// The world bound of the tables of [doc] carrying one of [numbers]
/// (trimmed): each one's symbol box, its four corners through its
/// transform. Every layer counts: the caller names the tables it expects.
Aabb2 boundOf(DraftDocument doc, Set<String> numbers) {
  var box = Aabb2.empty();
  for (final t in TableSurvey.of(doc).tables) {
    if (!numbers.contains(t.number)) continue;
    final node = doc.tree[t.instance]! as InstanceNode;
    final b = zoneSymbolBoxes[t.symbolKey]!;
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
