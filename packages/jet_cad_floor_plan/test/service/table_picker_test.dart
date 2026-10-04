// Spec 14c S1, S2, S9: a point inside a table's top picks it, through the
// table's inverse transform; failing a top, a point inside the symbol's
// bounding box does (a chair, the space between the chairs: the human,
// 2026-10-04); a wall, a hidden table do not; a top beats a neighbour's
// box; the highest handle wins; a locked table is picked and flagged.
// Tables are off the origin, turned 37 degrees and mirrored.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/src/service/table_picker.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';
import 'package:jet_cad_floor_plan/symbols.dart'
    show FurnitureSymbol, PolylineShape;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tables/table_fixture.dart';

/// Places [s] turned [quarterTurns] and mirrored at [at]; then turns it by
/// 37 degrees about [at]. Returns the instance.
InstanceNode placeTurned(DraftDocument doc, FurnitureSymbol s, Vector2 at,
    {bool mirrored = true}) {
  doc.commands
      .execute(placeSymbol(doc, entryOf(s), at: at, mirrored: mirrored));
  final node = doc.tree.nodes
      .whereType<InstanceNode>()
      .reduce((a, b) => a.handle.value > b.handle.value ? a : b);
  final turn = Transform2.translation(at.x, at.y)
      .multiply(Transform2.rotation(kDeg37))
      .multiply(Transform2.translation(-at.x, -at.y));
  doc.commands.execute(
      TransformNodeCommand(node.handle, turn.multiply(node.transform)));
  return doc.tree[node.handle]! as InstanceNode;
}

Vector2 worldOf(InstanceNode n, double x, double y) =>
    n.transform.transformPoint(Vector2(x, y));

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

void main() {
  // tableSymbol's top is 300..1500 x 300..1100; its chairs reach y -50 and
  // y 1450, tucked 100 under the top.
  test(
      'TP1 inside the top of a turned, mirrored table off the origin; on a '
      'chair and off every line inside its box; not at the untransformed '
      'spot (M-14h, M-14c2-1)', () {
    final doc = plan();
    final t = placeTurned(doc, tableSymbol(), Vector2(41000, -27500));
    final picker = TablePicker(doc);
    expect(picker.pick(worldOf(t, 1450, 1050))?.table.instance, t.handle);
    expect(picker.pick(worldOf(t, 320, 320))?.table.instance, t.handle);
    expect(picker.pick(worldOf(t, 900, 100))?.table.instance, t.handle,
        reason: 'a chair, outside the top, inside the box');
    expect(picker.pick(worldOf(t, 400, 1300))?.table.instance, t.handle,
        reason: 'beside the far chair: no shape, inside the box');
    expect(picker.pick(worldOf(t, 400, 1500)), isNull,
        reason: 'beyond the far chair: outside the box');
    expect(picker.pick(worldOf(t, 1600, 700)), isNull);
    expect(picker.pick(worldOf(t, 1500, 700))?.table.instance, t.handle,
        reason: 'on the right edge, within the tolerance');
    expect(picker.pick(worldOf(t, 900, 1100))?.table.instance, t.handle,
        reason: 'on the far edge');
    expect(picker.pick(Vector2(900, 700)), isNull,
        reason: 'where the top would be without the transform');
  });

  test('TP2 a wall over the top does not hide the table (M-14c)', () {
    final doc = plan();
    final t = placeTurned(doc, tableSymbol(), Vector2(-3200, 1800));
    final a = worldOf(t, 300, 700), b = worldOf(t, 1500, 700);
    final wall = tableLabelRecord(
            handle: doc.handleSeed.next(), instance: doc.rootHandle, number: '')
        .copyWith(kind: EntityKind.line, tag: '');
    doc.commands.execute(AddEntityCommand(
        record: wall,
        payload: GeometryPayload(
            coords: Float64List.fromList([a.x, a.y, b.x, b.y]),
            scalars: Float64List(0))));
    expect(
        TablePicker(doc).pick(worldOf(t, 900, 700))?.table.instance, t.handle);
  });

  test('TP3 overlapping tables: the higher handle wins (M-14c2-2)', () {
    final doc = plan();
    final low = placeTurned(doc, tableSymbol(), Vector2(500, 500));
    final high =
        placeTurned(doc, stoolSymbol, Vector2(500, 500), mirrored: false);
    expect(high.handle.value, greaterThan(low.handle.value));
    // The stool's seat is centred on (500, 500), inside the table's top.
    expect(
        TablePicker(doc).pick(Vector2(500, 500))?.table.instance, high.handle);
    expect(TablePicker(doc).pick(worldOf(low, 1450, 350))?.table.instance,
        low.handle);
  });

  test('TP4 a round top: inside, on the edge, outside', () {
    final doc = plan();
    final s = placeTurned(doc, stoolSymbol, Vector2(-9000, 7000));
    final picker = TablePicker(doc);
    expect(picker.pick(worldOf(s, 400 + 180, 300))?.table.instance, s.handle);
    expect(picker.pick(worldOf(s, 400, 300 + 190))?.table.instance, s.handle,
        reason: 'on the edge, within the tolerance');
    expect(picker.pick(worldOf(s, 400 + 195, 300)), isNull);
    expect(
        picker.pick(worldOf(s, 400 + 170, 300 - 170))?.table.instance, s.handle,
        reason: 'off the seat, in the box\'s corner');
  });

  test(
      'TP5 a hidden table is not picked; a locked one is, flagged '
      '(S9, M-14c2-10)', () {
    final doc = plan();
    final hidden = addLayer(doc, 'Hidden', visible: false);
    final locked = addLayer(doc, 'Locked', locked: true);
    final a = placeTurned(doc, tableSymbol(), Vector2(0, 0));
    final b = placeTurned(doc, tableSymbol(), Vector2(6000, 0));
    doc.commands.execute(SetInstanceLayerCommand(a.handle, hidden));
    doc.commands.execute(SetInstanceLayerCommand(b.handle, locked));
    final picker = TablePicker(doc);
    expect(picker.pick(worldOf(a, 900, 700)), isNull);
    final hit = picker.pick(worldOf(b, 900, 700))!;
    expect(hit.table.instance, b.handle);
    expect(hit.locked, isTrue);
  });

  test('TP6 a move is followed: the cache is keyed by the state id', () {
    final doc = plan();
    final t = placeTurned(doc, tableSymbol(), Vector2(2000, 2000));
    final picker = TablePicker(doc);
    final inside = worldOf(t, 900, 700);
    expect(picker.pick(inside)?.table.instance, t.handle);
    doc.commands.execute(TransformNodeCommand(
        t.handle, Transform2.translation(5000, 0).multiply(t.transform)));
    expect(picker.pick(inside), isNull);
    expect(picker.pick(inside + Vector2(5000, 0))?.table.instance, t.handle);
  });

  test(
      'TP7 an asymmetric top, mirrored, turned, 40 m off the origin: inside '
      'near its edges (R-2, M-14c2-11)', () {
    final doc = plan();
    final t = placeTurned(doc, trapezoidTable, Vector2(40000, -27000));
    final picker = TablePicker(doc);
    // Inside, near the short slanted edges.
    for (final (x, y) in [(1250, 950), (560, 880), (260, 330), (1560, 320)]) {
      expect(
          picker.pick(worldOf(t, x.toDouble(), y.toDouble()))?.table.instance,
          t.handle,
          reason: 'inside at ($x, $y)');
    }
    // Outside the box, just beyond its edges.
    for (final (x, y) in [(900, 1050), (150, 650), (1650, 650), (900, 250)]) {
      expect(picker.pick(worldOf(t, x.toDouble(), y.toDouble())), isNull,
          reason: 'outside at ($x, $y)');
    }
  });

  test(
      'TP7b a box asymmetric about the base point, mirrored and turned: '
      'the box turns with the table; its world bounds do not pick', () {
    // One chair, right of the top: the box spans x 300..1850, so a
    // mirror about x 900 puts the chair at x -50..400.
    const sideChair = FurnitureSymbol(
      key: 'test.table.side',
      name: 'Side chair table',
      category: 'Tests',
      tags: ['table', 'test'],
      seats: 1,
      baseX: 900,
      baseY: 700,
      shapes: [
        PolylineShape([(300, 300), (1500, 300), (1500, 1100), (300, 1100)],
            closed: true),
        PolylineShape([(1400, 475), (1850, 475), (1850, 925), (1400, 925)],
            closed: true),
      ],
    );
    final doc = plan();
    final t = placeTurned(doc, sideChair, Vector2(-38000, 26000));
    final picker = TablePicker(doc);
    expect(picker.pick(worldOf(t, 1800, 400))?.table.instance, t.handle,
        reason: 'below the chair, inside the box');
    expect(picker.pick(worldOf(t, 0, 700)), isNull,
        reason: 'where the chair would be without the mirror');
    expect(picker.pick(worldOf(t, 1900, 700)), isNull);
    // The box's world bounds, turned 37 degrees, hold their corners; the
    // box itself does not.
    final world = Aabb2.raw(300, 300, 1850, 1100).transformedBy(t.transform);
    final corner = Vector2(world.minX + 20, world.minY + 20);
    expect(picker.pick(corner), isNull, reason: 'a world-bounds corner');
  });

  test(
      'TP10 a top beats a neighbour\'s box; between two boxes, off both '
      'tops, the higher handle wins', () {
    final doc = plan();
    // A's top spans world y -12,400..-11,600, its box -12,750..-11,250;
    // B's box reaches down to y -11,650 (its lower chair), its top to
    // -11,300. The pair is then turned 37 degrees about A.
    doc.commands.execute(
        placeSymbol(doc, entryOf(tableSymbol()), at: Vector2(30000, -12000)));
    doc.commands.execute(
        placeSymbol(doc, entryOf(tableSymbol()), at: Vector2(30000, -10900)));
    final pivot = Vector2(30000, -12000);
    final turn = Transform2.translation(pivot.x, pivot.y)
        .multiply(Transform2.rotation(kDeg37))
        .multiply(Transform2.translation(-pivot.x, -pivot.y));
    final nodes = doc.tree.nodes.whereType<InstanceNode>().toList()
      ..sort((x, y) => x.handle.value.compareTo(y.handle.value));
    for (final n in nodes) {
      doc.commands
          .execute(TransformNodeCommand(n.handle, turn.multiply(n.transform)));
    }
    final a = nodes[0].handle, b = nodes[1].handle;
    Vector2 world(double x, double y) => turn.transformPoint(Vector2(x, y));
    final picker = TablePicker(doc);
    expect(picker.pick(world(29500, -11620))?.table.instance, a,
        reason: 'A\'s top, B\'s box: A, though B is drawn later');
    expect(picker.pick(world(29500, -11500))?.table.instance, b,
        reason: 'both boxes, neither top: B, drawn later');
    expect(picker.pick(world(29500, -11200))?.table.instance, b,
        reason: 'B\'s top');
  });

  test(
      'TP11 one leaf map shared by a build: a definition whose lowest-handle '
      'leaf is not in its lowest slot keeps its top; its box holds every '
      'leaf', () {
    final doc = plan();
    EntityRecord line(Handle h, Handle owner) => EntityRecord(
          handle: h,
          owner: owner,
          kind: EntityKind.line,
          layer: ReservedHandles.layerZero,
          linetype: ReservedHandles.byLayerLinetype,
          linetypeScale: 1.0,
          geomIndex: 0,
          color: const ByLayerColor(),
          lineweight: kByLayer,
          transparency: kByLayer,
          flags: 0,
        );
    GeometryPayload segment(double x0, double y0, double x1, double y1) =>
        GeometryPayload(
            coords: Float64List.fromList([x0, y0, x1, y1]),
            scalars: Float64List(0));
    // A stray line takes slot 0; removed once the tables are placed, it
    // leaves that slot to the next leaf, whose handle is the highest.
    final stray = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
        record: line(stray, doc.rootHandle), payload: segment(0, 0, 10, 10)));
    final a = placeTurned(doc, tableSymbol(), Vector2(41000, -27500));
    final b = placeTurned(doc, trapezoidTable, Vector2(-38000, 26000));
    doc.commands.execute(RemoveEntityCommand(stray));
    // B's definition gains an open leaf right of its top, past its box.
    final added = doc.handleSeed.next();
    doc.commands.execute(AddEntityCommand(
        record: line(added, b.definition),
        payload: segment(1600, 300, 2400, 300)));
    final leaves = doc.leavesByOwner()[b.definition]!;
    expect(doc.entities.handleAt(leaves.first), added,
        reason: 'premise: the added leaf is in the definition\'s lowest slot');

    final picker = TablePicker(doc);
    expect(
        picker.candidates.map((c) => c.table.instance), [a.handle, b.handle]);
    final top = picker.candidates[1].top! as PolygonTop;
    expect(top.xy, [200, 300, 1600, 300, 1300, 1000, 500, 900],
        reason: 'the lowest handle, not the lowest slot');
    for (final d in [a.definition, b.definition]) {
      expect((tableTopOf(doc, d, doc.leavesByOwner())! as PolygonTop).xy,
          (tableTopOf(doc, d)! as PolygonTop).xy,
          reason: 'the shared map and the scan agree');
    }
    expect(picker.pick(worldOf(b, 2350, 310))?.table.instance, b.handle,
        reason: 'inside the box only through the added leaf');
    expect(picker.pick(worldOf(b, 2450, 310)), isNull);
    expect(picker.pick(worldOf(a, 900, 100))?.table.instance, a.handle);
  });

  test('TP8 an open first leaf is no top: picked by its box (R-8, F-7)', () {
    const open = FurnitureSymbol(
      key: 'test.table.open',
      name: 'Open table',
      category: 'Tests',
      tags: ['table', 'test'],
      seats: 2,
      baseX: 900,
      baseY: 700,
      shapes: [
        PolylineShape([(300, 300), (1500, 300), (1500, 1100), (300, 1100)]),
        PolylineShape([(675, -50), (1125, -50), (1125, 400), (675, 400)],
            closed: true),
      ],
    );
    final doc = plan();
    final t = placeTurned(doc, open, Vector2(-4000, 2500));
    final closed = placeTurned(doc, tableSymbol(), Vector2(4000, 2500));
    final picker = TablePicker(doc);
    expect(tableTopOf(doc, t.definition), isNull);
    expect(picker.pick(worldOf(t, 900, 700))?.table.instance, t.handle);
    expect(picker.pick(worldOf(t, 900, 1200)), isNull);
    expect(picker.candidates.map((c) => c.table.instance),
        [t.handle, closed.handle]);
    expect(picker.candidates.first.top, isNull);
    final top = tableTopOf(doc, closed.definition)! as PolygonTop;
    expect(top.xy, [300, 300, 1500, 300, 1500, 1100, 300, 1100],
        reason: 'the closing vertex dropped');
  });

  test(
      'TP9 a reach picks the nearest box on a miss, not the later-drawn; '
      'nothing beyond it (spec 14t R-11, M-14t-26)', () {
    final doc = plan();
    // A (mirrored) and B face each other across a 100 mm gap: A's top
    // spans world x 29,400..30,600, B's 30,700..31,900. Then the pair is
    // turned 37 degrees about the gap, rigidly: distances are kept.
    doc.commands.execute(placeSymbol(doc, entryOf(tableSymbol()),
        at: Vector2(30000, -12000), mirrored: true));
    doc.commands.execute(
        placeSymbol(doc, entryOf(tableSymbol()), at: Vector2(31300, -12000)));
    final pivot = Vector2(30650, -12000);
    final turn = Transform2.translation(pivot.x, pivot.y)
        .multiply(Transform2.rotation(kDeg37))
        .multiply(Transform2.translation(-pivot.x, -pivot.y));
    final nodes = doc.tree.nodes.whereType<InstanceNode>().toList()
      ..sort((x, y) => x.handle.value.compareTo(y.handle.value));
    for (final n in nodes) {
      doc.commands
          .execute(TransformNodeCommand(n.handle, turn.multiply(n.transform)));
    }
    final a = nodes[0].handle, b = nodes[1].handle;
    Vector2 world(double x) => turn.transformPoint(Vector2(x, -12000));
    final picker = TablePicker(doc);
    expect(picker.pick(world(30640)), isNull, reason: 'in the gap: a miss');
    expect(picker.pick(world(30640), reach: 240)?.table.instance, a,
        reason: '40 mm from A, 60 from B: A, though B is drawn later');
    expect(picker.pick(world(30665), reach: 240)?.table.instance, b,
        reason: '65 mm from A, 35 from B');
    expect(picker.pick(world(29100), reach: 240), isNull,
        reason: '300 mm from A');
    expect(picker.pick(world(29200), reach: 240)?.table.instance, a,
        reason: '200 mm from A: within the reach');

    // A table scaled by 2 by hand, far off: its local units are 2 mm.
    final c = placeTurned(doc, tableSymbol(), Vector2(45000, -20000));
    final at = Vector2(45000, -20000);
    doc.commands.execute(TransformNodeCommand(
        c.handle,
        Transform2.translation(at.x, at.y)
            .multiply(Transform2.scale(2, 2))
            .multiply(Transform2.translation(-at.x, -at.y))
            .multiply(c.transform)));
    final scaled = doc.tree[c.handle]! as InstanceNode;
    Vector2 off(double x) => scaled.transform.transformPoint(Vector2(x, 700));
    expect(picker.pick(off(1600), reach: 240)?.table.instance, c.handle,
        reason: '100 local, 200 mm in the world');
    expect(picker.pick(off(1650), reach: 240), isNull,
        reason: '150 local, 300 mm in the world (review F-5)');
  });
}
