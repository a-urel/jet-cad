// SPIKE 07 — throwaway. Q6: a mitred pair through the real ParametricSystem,
// at the far origin, each wall in its own rotated group, joined only within
// the wall tolerance.
import 'dart:convert';
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'wall.dart';

const Handle hA = Handle(1000), hB = Handle(2000);
final Transform2 tA = Transform2.translation(4500000.0, 1200000.0)
    .multiply(Transform2.rotation(0.37));
final Transform2 tB = Transform2.translation(4500123.0, 1199877.0)
    .multiply(Transform2.rotation(-1.1));

DraftCommand create(DraftDocument doc, Handle h, Transform2 at, WallParams p) =>
    CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h, parent: doc.rootHandle, transform: at, children: const [])),
      SetComponentCommand<WallParams>(h, p),
    ], label: 'Add wall');

List<Handle> kids(DraftDocument doc, Handle g) => [
      for (final s in doc.entities.liveSlots)
        if (doc.entities.ownerAt(s) == g) doc.entities.handleAt(s),
    ]..sort((a, b) => a.value.compareTo(b.value));

String kindsOf(DraftDocument doc, Handle g) => [
      for (final k in kids(doc, g))
        doc.entities.kindAt(doc.entities.slotOf(k)!).name,
    ].join(',');

/// The boundary of [g]'s one region, in world coordinates.
List<Vector2> worldOutline(DraftDocument doc, Handle g) {
  final fill = kids(doc, g).firstWhere(
      (k) => doc.entities.kindAt(doc.entities.slotOf(k)!) == EntityKind.fill);
  final b = Handle(doc.geometry
      .read(doc.entities.geomIndexAt(doc.entities.slotOf(fill)!))
      .scalars[0]
      .toInt());
  final c =
      doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(b)!)).coords;
  final m = doc.tree.accumulatedTransform(g);
  return [
    for (var i = 0; i < c.length ~/ 2 - 1; i++)
      m.transformPoint(Vector2(c[i * 2], c[i * 2 + 1])),
  ];
}

String canon(DraftDocument d) {
  final j = DraftDocumentCodec.encode(d);
  j['entities'] = List<Map<String, Object?>>.from(j['entities']! as List)
    ..sort((a, b) => ((a['record']! as Map)['handle']! as int)
        .compareTo((b['record']! as Map)['handle']! as int));
  return jsonEncode(j);
}

void main() {
  test('Q6 a mitred pair end to end', () {
    final doc = DraftDocument.empty();
    final sys = ParametricSystem(doc, wallCatalog)..install();

    // World geometry: A runs to the hub, B leaves it at 67° interior angle.
    final hub = Vector2(4500500.0, 1200300.0);
    final aStart = hub + Vector2(-3000, 0);
    final r = (180 - 67) * math.pi / 180;
    final bEnd = hub + Vector2(math.cos(r), math.sin(r)) * 2500;
    // Local params through each group's inverse: the endpoints then meet in
    // world only within rounding, not bit for bit.
    final iA = tA.invert(), iB = tB.invert();
    final a0 = iA.transformPoint(aStart), a1 = iA.transformPoint(hub);
    final b0 = iB.transformPoint(hub), b1 = iB.transformPoint(bEnd);
    doc.commands
        .execute(create(doc, hA, tA, WallParams(a0.x, a0.y, a1.x, a1.y, 200)));
    doc.commands.execute(create(doc, hB, tB,
        WallParams(b0.x, b0.y, b1.x, b1.y, 115, Justification.left)));
    final wA = tA.transformPoint(a1), wB = tB.transformPoint(b0);
    print('Q6 world joint gap after transforms: ${(wA - wB).length} '
        '(dx ${wA.x - wB.x}, dy ${wA.y - wB.y})');

    print('Q6 A children: ${kindsOf(doc, hA)}; B children: ${kindsOf(doc, hB)}');
    expect(kids(doc, hA).length, 3);
    expect(kids(doc, hB).length, 3);
    final oa = worldOutline(doc, hA), ob = worldOutline(doc, hB);
    print('Q6 A outline ${oa.length} pts, B outline ${ob.length} pts');
    expect(oa.length, 4);
    expect(ob.length, 4);
    // The two shared corners, read back through each group's transform.
    var worst = 0.0, shared = 0;
    for (final p in oa) {
      final d = ob.map((q) => (q - p).length).reduce(math.min);
      if (d < 1) {
        shared++;
        worst = math.max(worst, d);
      }
    }
    print('Q6 shared corners $shared agree in world within $worst');
    expect(shared, 2, reason: 'the mitre: two corners shared');
    expect(sys.drift(), isEmpty);
    final handlesBefore = [...kids(doc, hA), ...kids(doc, hB)];
    final mitred = canon(doc);

    // One edit: move B away. A must regrow a square end in the same step.
    final depth = doc.commands.undoDepth;
    doc.commands.execute(TransformNodeCommand(
        hB, Transform2.translation(0, 4000).multiply(tB)));
    expect(doc.commands.undoDepth, depth + 1);
    print('Q6 after move: A outline ${worldOutline(doc, hA).length} pts');
    expect(sys.drift(), isEmpty);
    final moved = canon(doc);
    expect(moved, isNot(mitred));

    doc.commands.undo();
    expect(canon(doc), mitred, reason: 'undo restores the mitre exactly');
    doc.commands.redo();
    expect(canon(doc), moved, reason: 'redo restores the move exactly');
    doc.commands.undo();
    expect([...kids(doc, hA), ...kids(doc, hB)], handlesBefore);

    // Load -> save is byte-identical; drift stays empty after load.
    final bytes = DraftDocumentCodec.encodeToString(doc);
    final back = DraftDocumentCodec.decode(
        jsonDecode(bytes) as Map<String, Object?>,
        registerComponents: wallCatalog.registerComponents);
    final sys2 = ParametricSystem(back, wallCatalog)..install();
    expect(DraftDocumentCodec.encodeToString(back), bytes);
    expect(sys2.drift(), isEmpty);
    expect(back.components.get<WallParams>(hB),
        doc.components.get<WallParams>(hB));

    // D6 still holds for a region's boundary.
    final boundary = kids(doc, hA).firstWhere((k) =>
        doc.entities.kindAt(doc.entities.slotOf(k)!) == EntityKind.polyline &&
        doc.geometry
                .read(doc.entities.geomIndexAt(doc.entities.slotOf(k)!))
                .pointCount >
            2);
    expect(
        () => doc.commands.execute(SetEntityGeometryCommand(
            boundary,
            polylinePayload(
                [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)],
                closed: true))),
        throwsA(isA<GeneratedGeometryError>()));

    // Delete B the way the select tool does: children (fills skipped when
    // their boundary goes), then the node. A regrows square, one step.
    final skip = <Handle>{
      for (final k in kids(doc, hB))
        if (doc.entities.kindAt(doc.entities.slotOf(k)!) != EntityKind.fill)
          ...doc.fills.fillsOf(k),
    };
    doc.commands.execute(CompoundCommand([
      for (final k in kids(doc, hB))
        if (!skip.contains(k)) RemoveEntityCommand(k),
      RemoveNodeCommand(hB),
    ], label: 'Delete'));
    expect(doc.components.get<WallParams>(hB), isNull);
    print('Q6 after delete: A outline ${worldOutline(doc, hA).length} pts');
    expect(sys.drift(), isEmpty);
    doc.commands.undo();
    expect(kids(doc, hB).length, 3);
    expect(sys.drift(), isEmpty);
    print('Q6 ok');
  });
}
