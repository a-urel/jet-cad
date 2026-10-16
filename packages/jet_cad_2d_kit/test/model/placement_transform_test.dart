// Spec 09 D6 and 09c D5, moved into the contract by 3a Task 1 (spec
// C1.4): placementTransform. The group is jet_cad_2d_plan's
// test/symbols/symbol_placer_test.dart group 'placementTransform' (P1-P4,
// P20-P23), assertions unchanged; the placer's own groups stay there.
// Fixtures: every base point and `at` off the origin, rotations of 30° and
// −112.5° (no 0 or ±1), mirrored or not.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/box_fixtures.dart';

SymbolLibrary library() => SymbolLibrary.decode(bytesOf(buildValidLibrary()));

SymbolEntry entryOf(String key) =>
    library().entries.firstWhere((e) => e.symbol.key == key);

SymbolEntry sofa() => entryOf('fixture.sofa.three');

/// World position of a local point under placement (q, mirrored), written
/// without [Transform2]: mirror the local x, rotate by q quarter turns, move
/// the base point to [at].
Vector2 expectedWorld(
    Vector2 local, Vector2 base, Vector2 at, int q, bool mirrored) {
  var x = local.x - base.x;
  final y = local.y - base.y;
  if (mirrored) x = -x;
  final (rx, ry) = switch (((q % 4) + 4) % 4) {
    0 => (x, y),
    1 => (-y, x),
    2 => (-x, -y),
    _ => (y, -x),
  };
  return Vector2(at.x + rx, at.y + ry);
}

final Vector2 at = Vector2(3333.5, -2222.25);

/// Far from the origin, as the wall fixtures are (plan P-2).
final Vector2 far = Vector2(100000.25, -70000.75);

/// A 30° and a −112.5° rotation vector: (name, cos, sin).
final List<(String, double, double)> rotations = [
  ('30°', math.sqrt(3) / 2, 0.5),
  (
    '−112.5°',
    math.cos(-112.5 * math.pi / 180),
    math.sin(-112.5 * math.pi / 180)
  ),
];
const Tolerance tol = Tolerance.standard;

void main() {
  group('placementTransform', () {
    test(
        'P1 the base point lands on at, and a leaf endpoint where the '
        'independent formula says, for every quarter turn, mirrored or not',
        () {
      final e = sofa();
      final base = e.definition.basePoint;
      expect(base.x, isNot(0));
      expect(base.y, isNot(0));
      final line =
          e.leaves.firstWhere((l) => l.record.handle.value == sofaLine);
      final p0 = line.payload.pointAt(0);
      final p1 = line.payload.pointAt(1);
      for (final mirrored in [false, true]) {
        for (var q = 0; q < 4; q++) {
          final t = placementTransform(
              at: at, basePoint: base, quarterTurns: q, mirrored: mirrored);
          expect(tol.eqPoint(t.transformPoint(base), at), isTrue,
              reason: 'q=$q mirrored=$mirrored base point');
          for (final p in [p0, p1]) {
            final want = expectedWorld(p, base, at, q, mirrored);
            expect(tol.eqPoint(t.transformPoint(p), want), isTrue,
                reason: 'q=$q mirrored=$mirrored $p -> '
                    '${t.transformPoint(p)}, want $want');
          }
        }
      }
    });

    test('P2 quarter turns are taken modulo 4, negative allowed', () {
      final base = Vector2(900, 400);
      List<double> t(int q) => placementTransform(
              at: at, basePoint: base, quarterTurns: q, mirrored: true)
          .toJson()
          .cast<double>();
      expect(t(-1), t(3));
      expect(t(4), t(0));
      expect(t(5), t(1));
      expect(t(-6), t(2));
      expect(t(1), isNot(t(3)));
    });

    test(
        'P3 the matrix is exactly 0 and ±1 in its linear part and never '
        '-0.0, for every quarter turn, mirrored or not', () {
      final base = Vector2(900, 400);
      for (final mirrored in [false, true]) {
        for (var q = -2; q < 6; q++) {
          final t = placementTransform(
              at: at, basePoint: base, quarterTurns: q, mirrored: mirrored);
          for (final v in [t.a, t.b, t.c, t.d]) {
            expect([0.0, 1.0, -1.0], contains(v),
                reason: 'q=$q mirrored=$mirrored ${t.toJson()}');
          }
          for (final v in [t.a, t.b, t.c, t.d, t.e, t.f]) {
            expect(v == 0 && v.isNegative, isFalse,
                reason: 'q=$q mirrored=$mirrored has -0.0: ${t.toJson()}');
          }
        }
      }
    });

    test(
        'P4 a mirror flips the local x axis whatever the turns (det < 0), '
        'and the turn order is rotate after mirror', () {
      final base = Vector2(900, 400);
      for (var q = 0; q < 4; q++) {
        expect(
            placementTransform(
                    at: at, basePoint: base, quarterTurns: q, mirrored: true)
                .determinant,
            -1.0);
        expect(
            placementTransform(at: at, basePoint: base, quarterTurns: q)
                .determinant,
            1.0);
      }
      // Local +x under q=1 mirrored: mirrored to -x, rotated to -y.
      final t = placementTransform(
          at: at, basePoint: base, quarterTurns: 1, mirrored: true);
      final d = t.transformDirection(Vector2(1, 0));
      expect(d.x, 0.0);
      expect(d.y, -1.0);
    });

    // Plan 09c-1 Task 5 (spec D5): the rotation as a unit vector. The
    // fixtures: a 30° and a −112.5° vector (no 0 or ±1 in either), `far` and
    // the sofa's base point off the origin and off each other.

    test(
        'P20 a rotation vector gives translate(at) · R · S · '
        'translate(−base), written out by hand, mirrored or not', () {
      final e = sofa();
      final base = e.definition.basePoint;
      final line =
          e.leaves.firstWhere((l) => l.record.handle.value == sofaLine);
      for (final (name, cos, sin) in rotations) {
        for (final mirrored in [false, true]) {
          final why = '$name mirrored=$mirrored';
          final s = mirrored ? -1.0 : 1.0;
          final t = placementTransform(
              at: far,
              basePoint: base,
              rotation: (cos, sin),
              mirrored: mirrored);
          // The local x is mirrored first, then turned: (s·cos, s·sin);
          // the local y turns alone: (−sin, cos). Exact doubles.
          expect(
              t.toJson(),
              [
                s * cos,
                s * sin,
                -sin,
                cos,
                far.x - (s * cos * base.x - sin * base.y),
                far.y - (s * sin * base.x + cos * base.y),
              ],
              reason: why);
          expect(tol.eqPoint(t.transformPoint(base), far), isTrue,
              reason: '$why base point');
          for (final p in [line.payload.pointAt(0), line.payload.pointAt(1)]) {
            final u = (p.x - base.x) * s, v = p.y - base.y;
            final want =
                Vector2(far.x + cos * u - sin * v, far.y + sin * u + cos * v);
            expect(tol.eqPoint(t.transformPoint(p), want), isTrue,
                reason: '$why $p -> ${t.transformPoint(p)}, want $want');
          }
          expect(t.determinant, closeTo(s, 1e-12), reason: why);
        }
      }
    });

    test(
        'P21 quarterTurns and rotation together are refused (an '
        'ArgumentError, not only an assert)', () {
      for (final q in [0, 1]) {
        expect(
            () => placementTransform(
                at: far,
                basePoint: Vector2(900, 400),
                quarterTurns: q,
                rotation: (rotations.first.$2, rotations.first.$3)),
            throwsArgumentError,
            reason: 'quarterTurns: $q');
      }
      // Neither: no turn.
      expect(
          placementTransform(at: far, basePoint: Vector2(900, 400)).toJson(),
          placementTransform(
              at: far,
              basePoint: Vector2(900, 400),
              rotation: (1.0, 0.0)).toJson());
    });

    test(
        'P22 the quarter-turn form is the rotation form at the exact table: '
        'the same bytes for every turn, mirrored or not', () {
      const table = [(1.0, 0.0), (0.0, 1.0), (-1.0, 0.0), (0.0, -1.0)];
      final base = Vector2(900, 400);
      for (final mirrored in [false, true]) {
        for (var q = -2; q < 6; q++) {
          expect(
              placementTransform(
                      at: far,
                      basePoint: base,
                      quarterTurns: q,
                      mirrored: mirrored)
                  .toJson(),
              placementTransform(
                      at: far,
                      basePoint: base,
                      rotation: table[((q % 4) + 4) % 4],
                      mirrored: mirrored)
                  .toJson(),
              reason: 'q=$q mirrored=$mirrored');
        }
      }
    });

    test(
        'P23 an axis-aligned rotation vector (cos or sin −0.0, as a face '
        'normal gives it) stores no −0.0, mirrored or not (M-09c-n: the '
        'named axis-aligned exception)', () {
      final base = Vector2(900, 400);
      for (final r in [
        (-0.0, 1.0),
        (0.0, 1.0),
        (-0.0, -1.0),
        (1.0, -0.0),
        (-1.0, -0.0),
      ]) {
        for (final mirrored in [false, true]) {
          final t = placementTransform(
              at: far, basePoint: base, rotation: r, mirrored: mirrored);
          for (final v in t.toJson()) {
            expect(v == 0 && v.isNegative, isFalse,
                reason: '$r mirrored=$mirrored has -0.0: ${t.toJson()}');
          }
        }
      }
    });
  });
}
