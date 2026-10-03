// Spec 14c S1, S2, S9: a point inside a table's top picks it, through the
// table's inverse transform; a chair, a wall, a hidden table do not; the
// highest handle wins; a locked table is picked and flagged. Tables are off
// the origin, turned 37 degrees and mirrored.
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
      'TP1 inside the top of a turned, mirrored table off the origin; not '
      'on a chair; not at the untransformed spot (M-14h, M-14c2-1)', () {
    final doc = plan();
    final t = placeTurned(doc, tableSymbol(), Vector2(41000, -27500));
    final picker = TablePicker(doc);
    expect(picker.pick(worldOf(t, 1450, 1050))?.table.instance, t.handle);
    expect(picker.pick(worldOf(t, 320, 320))?.table.instance, t.handle);
    expect(picker.pick(worldOf(t, 900, 100)), isNull,
        reason: 'a chair, outside the top');
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
      'and outside near its edges (R-2, M-14c2-11)', () {
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
    // Outside, just beyond them: where a mirrored-away top would be.
    for (final (x, y) in [(1400, 950), (420, 900), (1650, 400), (150, 350)]) {
      expect(picker.pick(worldOf(t, x.toDouble(), y.toDouble())), isNull,
          reason: 'outside at ($x, $y)');
    }
  });

  test('TP8 an open first leaf is no top: never picked (R-8, review F-7)', () {
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
    expect(picker.pick(worldOf(t, 900, 700)), isNull);
    expect(picker.candidates.map((c) => c.table.instance), [closed.handle]);
    final top = tableTopOf(doc, closed.definition)! as PolygonTop;
    expect(top.xy, [300, 300, 1500, 300, 1500, 1100, 300, 1100],
        reason: 'the closing vertex dropped');
  });
}
