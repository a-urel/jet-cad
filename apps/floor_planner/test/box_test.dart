import 'dart:math' as math;

import 'package:floor_planner/parametric/box.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

final Transform2 atA = Transform2.translation(7010, 3020)
    .multiply(Transform2.rotation(math.pi / 6));
Transform2 onA(double x, double y, double turn) => atA
    .multiply(Transform2.translation(x, y))
    .multiply(Transform2.rotation(turn));

DraftCommand box(
        DraftDocument doc, Handle h, Transform2 at, double w, double hh) =>
    CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h,
          parent: doc.rootHandle,
          transform: at,
          children: const [])),
      SetComponentCommand<BoxParams>(h, BoxParams(w, hh)),
    ], label: 'Add box');

List<Handle> kids(DraftDocument doc, Handle g) => [
      for (final s in doc.entities.liveSlots)
        if (doc.entities.ownerAt(s) == g) doc.entities.handleAt(s),
    ];

void main() {
  const a = Handle(1000), b = Handle(2000);

  test('BT1 BoxParams: value equality, key order, round trip', () {
    const p = BoxParams(1200, 800);
    expect(p.toJson().keys.toList(), ['width', 'height']);
    expect(BoxParams.fromJson(p.toJson()), p);
    expect(p.copyWith(height: 5), const BoxParams(1200, 5));
    expect(p.typeId, 'floor_planner.box');
  });

  test('BT2 an isolated box is four lines at its corners', () {
    final doc = DraftDocument.empty();
    installBoxes(doc);
    doc.commands.execute(box(doc, a, atA, 1200, 800));
    expect(kids(doc, a), hasLength(4));
  });

  test(
      'BT3 a rotated overlapping pair clips each other: A 5, B 3 '
      '(M-06g app, M-06o)', () {
    final doc = DraftDocument.empty();
    installBoxes(doc);
    doc.commands.execute(box(doc, a, atA, 2000, 1000));
    doc.commands.execute(box(doc, b, onA(800, 700, 0.3), 400, 900));
    expect(kids(doc, a), hasLength(5));
    expect(kids(doc, b), hasLength(3));
    expect(ParametricSystem(doc, boxCatalog).drift(), isEmpty);
  });

  test(
      'BT4 two boxes sharing an edge exactly are not neighbours '
      '(Review Focus 5)', () {
    final doc = DraftDocument.empty();
    installBoxes(doc);
    doc.commands.execute(box(doc, a, atA, 1000, 1000));
    doc.commands.execute(box(doc, b, onA(1000, 0, 0), 1000, 1000));
    expect(kids(doc, a), hasLength(4));
    expect(kids(doc, b), hasLength(4));
  });

  test('BT5 editCapability is geometry', () {
    expect(const BoxType().editCapability, Capability.geometry);
  });

  test('BT6 a box reaches exactly its transformed corners', () {
    final r = const BoxType().reach(const BoxParams(2000, 1000), atA);
    final c = [
      Vector2(0, 0),
      Vector2(2000, 0),
      Vector2(2000, 1000),
      Vector2(0, 1000)
    ].map(atA.transformPoint);
    expect(r.minX, c.map((v) => v.x).reduce(math.min));
    expect(r.maxY, c.map((v) => v.y).reduce(math.max));
  });
}
