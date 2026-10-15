// Spec 2b S2 "The label": a unit's label stamp, height and payload, and
// unitLabelAttrib, a generated unit's label (E5). TL1, TL2 and TL4 are
// ported from jet_cad_floor_plan's test/tables/table_label_test.dart (spec
// 14a T8, T10), assertions unchanged: table -> unit, the height read from
// the top's box. The stamp is checked the way it is drawn: the label's
// world linear map is the instance's linear part times the text's own,
// `R(rotation) · diag(widthFactor, 1)`, and must be the identity.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/placements.dart';

/// The label's world linear map under [placement], from [rotation] and
/// [widthFactor] (the stamp's, by default).
Transform2 worldLinear(Transform2 placement,
    {double? rotation, double? widthFactor}) {
  final s = unitLabelStamp(placement);
  final linear =
      Transform2(placement.a, placement.b, placement.c, placement.d, 0, 0);
  return linear
      .multiply(Transform2.rotation(rotation ?? s.rotation))
      .multiply(Transform2.scale(widthFactor ?? s.widthFactor, 1));
}

void expectIdentity(Transform2 w) {
  expect(w.a, closeTo(1, 1e-12));
  expect(w.b, closeTo(0, 1e-12));
  expect(w.c, closeTo(0, 1e-12));
  expect(w.d, closeTo(1, 1e-12));
}

void main() {
  group('unitLabelStamp (T10)', () {
    const degrees = [0.0, 37.0, 90.0, 180.0, -123.0, 270.0, 179.0];
    for (final mirrored in [false, true]) {
      for (final deg in degrees) {
        test(
            'TL1 ${mirrored ? 'mirrored, ' : ''}$deg°: the label reads '
            'upright in world (M-14a-7, M-14a-8)', () {
          final p =
              placementAt(-4321, 2468, deg * math.pi / 180, mirrored: mirrored);
          final w = worldLinear(p);
          expect(w.a, closeTo(1, 1e-12));
          expect(w.b, closeTo(0, 1e-12));
          expect(w.c, closeTo(0, 1e-12));
          expect(w.d, closeTo(1, 1e-12));
          final s = unitLabelStamp(p);
          expect(s.rotation, greaterThan(-math.pi));
          expect(s.rotation, lessThanOrEqualTo(math.pi));
          expect(s.widthFactor, mirrored ? -1.0 : 1.0);
        });
      }
    }

    test('TL2 placements store clean values: no −0.0, exact quarter turns', () {
      final bp = Vector2(900, 700);
      final plain = unitLabelStamp(
          placementTransform(at: Vector2(3000, -1200), basePoint: bp));
      expect((plain.rotation, plain.widthFactor), (0.0, 1.0));
      expect(plain.rotation.isNegative, isFalse);

      final mirrored = unitLabelStamp(placementTransform(
          at: Vector2(3000, -1200), basePoint: bp, mirrored: true));
      expect((mirrored.rotation, mirrored.widthFactor), (0.0, -1.0));
      expect(mirrored.rotation.isNegative, isFalse);

      final quarter = unitLabelStamp(placementTransform(
          at: Vector2(3000, -1200), basePoint: bp, quarterTurns: 1));
      expect((quarter.rotation, quarter.widthFactor), (-math.pi / 2, 1.0));

      final half = unitLabelStamp(placementTransform(
          at: Vector2(3000, -1200), basePoint: bp, quarterTurns: 2));
      expect((half.rotation, half.widthFactor), (math.pi, 1.0));

      final threeMirrored = unitLabelStamp(placementTransform(
          at: Vector2(3000, -1200),
          basePoint: bp,
          quarterTurns: 3,
          mirrored: true));
      expect((threeMirrored.rotation, threeMirrored.widthFactor),
          (-math.pi / 2, -1.0));
    });
  });

  group('unitLabelHeight (T8, M-14a-14)', () {
    // The boxes of today's circle (centre (400, 300)) and box payloads.
    Aabb2 circle(double r) => Aabb2.raw(400 - r, 300 - r, 400 + r, 300 + r);
    Aabb2 box(double w, double h) => Aabb2.raw(100, 200, 100 + w, 200 + h);

    test('TL4 written out by hand', () {
      expect(unitLabelHeight(circle(190)), 152);
      expect(unitLabelHeight(circle(300)), 200);
      expect(unitLabelHeight(box(2000, 400)), 160);
      expect(unitLabelHeight(box(1200, 750)), 200);
      expect(unitLabelHeight(box(450, 600)), 180);
      expect(unitLabelHeight(Aabb2.empty()), 200);
    });
  });

  group('the generated label (spec 2b S2)', () {
    // A seat turned three quarters and mirrored, in a row turned 37° far
    // off the origin: the instance-to-world map is neither the identity,
    // nor a rotation, nor the seat's own transform.
    final row = Transform2.translation(-41250.5, 17320.25)
        .multiply(Transform2.rotation(37 * math.pi / 180));
    final seat = placementTransform(
        at: Vector2(1200.5, -350.25),
        basePoint: Vector2(225, 190),
        quarterTurns: 3,
        mirrored: true);
    final toWorld = row.multiply(seat);
    final anchor = Vector2(225, 190);
    // The served top: 380 × 450, so 0.4 × 380 = 152.
    const top = Aabb2.raw(35, 0, 415, 450);

    test(
        'K2B-payload the payload holds the anchor as given and [height, '
        'rotation, widthFactor] stamped for the instance-to-world map', () {
      final p = unitLabelPayload(
          anchor: anchor, height: 152, instanceToWorld: toWorld);
      final s = unitLabelStamp(toWorld);
      expect(s.widthFactor, -1.0, reason: 'premise: the map mirrors');
      // M-K2B-1: unitLabelPayload stamping the identity instead.
      expect(p.coords, [225, 190]);
      expect(p.scalars, [152, s.rotation, s.widthFactor]);
    });

    test(
        'K2B-attrib unitLabelAttrib: tag UNIT, the text, centred with its '
        'own width factor, the payload in definition space, upright and '
        'unmirrored in the world', () {
      final a = unitLabelAttrib('B12',
          instanceToWorld: toWorld, anchor: anchor, top: top);
      expect(kUnitLabelTag, 'UNIT');
      // M-K2B-2: the attribute tagged '' (or 'TABLE').
      expect(a.tag, 'UNIT');
      expect(a.text, 'B12');
      // M-K2B-3: `textAttrs:` left out (0).
      expect(a.textAttrs, kUnitLabelTextAttrs);
      expect(a.textAttrs & 0xF, TextJustifyH.centre.index);
      expect((a.textAttrs >> 4) & 0xF, TextJustifyV.middle.index);
      expect(a.textAttrs & (1 << 8), isNot(0),
          reason: 'the width factor is read only with bit 8');
      // M-K2B-4: the anchor mapped into the world before it is stored.
      expect(a.payload.coords, [225, 190], reason: 'definition space');
      expect(a.payload.scalars[0], 152);
      // M-K2B-5: the stamp taken for another map: no longer upright.
      expectIdentity(worldLinear(toWorld,
          rotation: a.payload.scalars[1], widthFactor: a.payload.scalars[2]));
    });

    test('K2B-attrib-empty a definition with no served top: the full height',
        () {
      // M-K2B-6: unitLabelHeight without its empty-box check (an inverted
      // box gives -infinity).
      final a = unitLabelAttrib('7',
          instanceToWorld: toWorld, anchor: anchor, top: Aabb2.empty());
      expect(a.payload.scalars[0], kUnitLabelMaxHeight);
      expect(kUnitLabelMaxHeight, 200);
      expect(kUnitLabelTopShare, 0.4);
    });
  });
}
