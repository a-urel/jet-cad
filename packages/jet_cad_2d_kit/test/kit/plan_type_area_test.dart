// The area capability of PlanType: an object's closed outline in the world,
// read through a DocumentPlanObject whose world is the group's accumulated
// transform.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/code_fixtures.dart';
import '../support/plan_type_fixtures.dart';

final KitWords words = KitNamesWords(KitNames.empty, () => const Locale('en'));

final List<Vector2> unit = [
  Vector2(0, 0),
  Vector2(4000, 0),
  Vector2(4000, 3000),
  Vector2(0, 3000),
];

PlanType<Slab> areaSlab({bool nullArea = false}) => PlanType<Slab>(
      id: Slab.id,
      fromJson: Slab.fromJson,
      parametric: LoggingType<Slab>(),
      area: (s, o) =>
          nullArea ? null : [for (final p in unit) o.world.transformPoint(p)],
    );

void main() {
  test('AR1 a type without area: hasArea false, areaOf null', () {
    final type = slabType();
    final (:doc, catalog: _) = objectDocument([type, postType()]);
    addTearDown(doc.dispose);
    expect(type.hasArea, isFalse);
    expect(type.areaOf(doc, hSlab, words), isNull);
  });

  test('AR2 areaOf returns the outline of the group\'s value in the world', () {
    final type = areaSlab();
    final (:doc, catalog: _) = objectDocument([type, postType()]);
    addTearDown(doc.dispose);
    // Replace the slab's group transform: off the origin, rotated 30 degrees.
    final at = Transform2.translation(5000, -3000)
        .multiply(Transform2.rotation(math.pi / 6));
    doc.commands.execute(TransformNodeCommand(hSlab, at));
    expect(type.hasArea, isTrue);
    final ring = type.areaOf(doc, hSlab, words)!;
    expect(ring, hasLength(4));
    final c = math.cos(math.pi / 6), s = math.sin(math.pi / 6);
    for (var i = 0; i < 4; i++) {
      final x = unit[i].x, y = unit[i].y;
      expect(ring[i].x, closeTo(5000 + c * x - s * y, 1e-6));
      expect(ring[i].y, closeTo(-3000 + s * x + c * y, 1e-6));
    }
  });

  test('AR3 areaOf on a group without the type\'s component is null', () {
    final type = areaSlab();
    final (:doc, catalog: _) = objectDocument([type, postType()]);
    addTearDown(doc.dispose);
    expect(type.areaOf(doc, hBare, words), isNull);
    expect(type.areaOf(doc, hPost, words), isNull);
  });

  test('AR4 a capability returning null means no area now', () {
    final type = areaSlab(nullArea: true);
    final (:doc, catalog: _) = objectDocument([type, postType()]);
    addTearDown(doc.dispose);
    expect(type.hasArea, isTrue);
    expect(type.areaOf(doc, hSlab, words), isNull);
  });
}
