import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

GeometryPayload payload(List<double> coords, List<double> scalars) =>
    GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List.fromList(scalars));

// The spec's fixture rules: off the origin, a closed room, arcs with a
// non-zero start and one negative sweep.
final GeometryPayload line = payload([7010, 3020, 7130, 3060], []);
final GeometryPayload open5 =
    payload([7010, 3100, 7040, 3130, 7070, 3100, 7100, 3130, 7130, 3100], []);
final GeometryPayload room =
    payload([7200, 3000, 7400, 3000, 7400, 3150, 7200, 3150, 7200, 3000], []);
final GeometryPayload circle = payload([7300, 3250], [25]);
final GeometryPayload arcPos = payload([7050, 3200], [40, 0.3, 1.9]);
final GeometryPayload arcNeg = payload([7150, 3250], [30, 2.2, -1.4]);

/// Ruling 03-1: two angles are the same angle when their unit vectors
/// agree; a derived angle may differ from a stored one by a whole turn.
void expectSameDirection(double actual, double expected) {
  expect(math.cos(actual),
      closeTo(math.cos(expected), Tolerance.standard.angular));
  expect(math.sin(actual),
      closeTo(math.sin(expected), Tolerance.standard.angular));
}

/// A point at [angle] and [radius] about [arc]'s centre.
Vector2 at(GeometryPayload arc, double angle, double radius) => Vector2(
    arc.coords[0] + radius * math.cos(angle),
    arc.coords[1] + radius * math.sin(angle));

void main() {
  group('leafGrips', () {
    test('the grip set per kind, in owner space (M-03y)', () {
      expect(leafGrips(EntityKind.line, line), const [
        Grip(GripRole.stretch, 0, 7010, 3020),
        Grip(GripRole.stretch, 1, 7130, 3060),
      ]);
      final open = leafGrips(EntityKind.polyline, open5);
      expect([for (final g in open) g.index], [0, 1, 2, 3, 4]);
      expect(open[2], const Grip(GripRole.stretch, 2, 7070, 3100));
      // Closed: vertex 0 stands for the repeated last vertex (spec D3).
      expect(leafGrips(EntityKind.polyline, room), const [
        Grip(GripRole.stretch, 0, 7200, 3000),
        Grip(GripRole.stretch, 1, 7400, 3000),
        Grip(GripRole.stretch, 2, 7400, 3150),
        Grip(GripRole.stretch, 3, 7200, 3150),
      ]);
      final c = leafGrips(EntityKind.circle, circle);
      expect(c, hasLength(5));
      expect(c[0], const Grip(GripRole.move, 0, 7300, 3250));
      const quadrants = [
        [7325.0, 3250.0],
        [7300.0, 3275.0],
        [7275.0, 3250.0],
        [7300.0, 3225.0],
      ];
      for (var q = 0; q < 4; q++) {
        expect(c[q + 1].role, GripRole.radius);
        expect(c[q + 1].index, q);
        expect(c[q + 1].x, closeTo(quadrants[q][0], 1e-9));
        expect(c[q + 1].y, closeTo(quadrants[q][1], 1e-9));
      }
      final a = leafGrips(EntityKind.arc, arcNeg);
      expect([
        for (final g in a) (g.role, g.index)
      ], [
        (GripRole.move, 0),
        (GripRole.stretch, 0),
        (GripRole.stretch, 1),
        (GripRole.radius, 0),
      ]);
      expect(a[0].x, 7150);
      expect(a[0].y, 3250);
      for (final (g, angle) in [
        (a[1], 2.2),
        (a[2], 2.2 - 1.4),
        (a[3], 2.2 - 0.7),
      ]) {
        final p = at(arcNeg, angle, 30);
        expect(g.x, closeTo(p.x, 1e-9));
        expect(g.y, closeTo(p.y, 1e-9));
      }
      for (final kind in [
        EntityKind.point,
        EntityKind.text,
        EntityKind.attrib,
        EntityKind.fill,
      ]) {
        expect(leafGrips(kind, payload([7250, 3300], [12])), isEmpty,
            reason: kind.name);
      }
    });

    test('isClosedPolyline is an exact stored-value test', () {
      expect(isClosedPolyline(room), isTrue);
      expect(isClosedPolyline(open5), isFalse);
      expect(
          isClosedPolyline(payload([7010, 3020, 7100, 3090, 7010, 3020], [])),
          isTrue);
      expect(isClosedPolyline(payload([7010, 3020, 7010, 3020], [])), isFalse,
          reason: 'two points are a segment, not a loop');
      final nudged = Float64List.fromList(room.coords)..[8] = 7200.000000000001;
      expect(nudged[8], isNot(7200.0));
      expect(
          isClosedPolyline(
              GeometryPayload(coords: nudged, scalars: Float64List(0))),
          isFalse,
          reason: 'closedness is ==, not Tolerance');
    });
  });

  group('reshapeLeaf', () {
    test('a line stretch writes the grabbed pair and copies the rest', () {
      final grips = leafGrips(EntityKind.line, line);
      final out = reshapeLeaf(
          EntityKind.line, line, grips[1], Vector2(7151.125, 3077.375))!;
      expect(out.coords, [7010, 3020, 7151.125, 3077.375]);
      expect(out.scalars, isEmpty);
      // A zero-length segment is legal geometry, never degenerate.
      expect(reshapeLeaf(EntityKind.line, line, grips[1], Vector2(7010, 3020)),
          isNotNull);
    });

    test(
        'a polyline middle-vertex stretch moves that vertex and nothing '
        'else (M-03o)', () {
      final grip = leafGrips(EntityKind.polyline, open5)[2];
      final out = reshapeLeaf(
          EntityKind.polyline, open5, grip, Vector2(7066.5, 3088.25))!;
      final expected = Float64List.fromList(open5.coords)
        ..[4] = 7066.5
        ..[5] = 3088.25;
      expect(out.coords, expected);
    });

    test(
        'a closed room corner moves as one: first and last pairs stay == '
        '(M-03r)', () {
      final grips = leafGrips(EntityKind.polyline, room);
      final out = reshapeLeaf(
          EntityKind.polyline, room, grips[0], Vector2(7188.5, 2990.25))!;
      expect(out.coords, [
        7188.5,
        2990.25,
        7400,
        3000,
        7400,
        3150,
        7200,
        3150,
        7188.5,
        2990.25
      ]);
      expect(isClosedPolyline(out), isTrue);
      final other = reshapeLeaf(
          EntityKind.polyline, room, grips[2], Vector2(7410, 3160))!;
      expect(other.coords,
          [7200, 3000, 7400, 3000, 7410, 3160, 7200, 3150, 7200, 3000]);
    });

    test(
        'a circle radius grip sets r = |target − centre|; degenerate is '
        'null', () {
      final q = leafGrips(EntityKind.circle, circle)[2];
      final out =
          reshapeLeaf(EntityKind.circle, circle, q, Vector2(7330, 3290))!;
      expect(out.coords, circle.coords);
      expect(out.scalars, [50]);
      expect(reshapeLeaf(EntityKind.circle, circle, q, Vector2(7300, 3250)),
          isNull);
      expect(
          reshapeLeaf(
              EntityKind.circle, circle, q, Vector2(7300 + 1e-10, 3250)),
          isNull);
    });

    test(
        'an arc start stretch keeps the sweep direction and the end, both '
        'signs (Ruling 03-1)', () {
      final start = leafGrips(EntityKind.arc, arcPos)[1];
      final out =
          reshapeLeaf(EntityKind.arc, arcPos, start, at(arcPos, 0.1, 55))!;
      expect(out.coords, arcPos.coords);
      expect(out.scalars[0], 40);
      expect(out.scalars[1], closeTo(0.1, 1e-12));
      expect(out.scalars[2], closeTo(2.1, 1e-12));
      expectSameDirection(out.scalars[1] + out.scalars[2], 0.3 + 1.9);

      final negStart = leafGrips(EntityKind.arc, arcNeg)[1];
      final neg =
          reshapeLeaf(EntityKind.arc, arcNeg, negStart, at(arcNeg, 2.5, 18))!;
      expect(neg.scalars[1], closeTo(2.5, 1e-12));
      expect(neg.scalars[2], closeTo(-1.7, 1e-12));
      expectSameDirection(neg.scalars[1] + neg.scalars[2], 2.2 - 1.4);

      // Ruling 03-1's witness: atan2 answers in (−π, π], so the derived end
      // differs from the stored 5.0 by a whole turn — and is the same angle.
      final wide = payload([7050, 3200], [40, 4.0, 1.0]);
      final w = reshapeLeaf(EntityKind.arc, wide,
          leafGrips(EntityKind.arc, wide)[1], at(wide, 4.1, 40))!;
      expect(w.scalars[1], closeTo(4.1 - 2 * math.pi, 1e-12));
      expect(w.scalars[2], closeTo(0.9, 1e-12));
      expect((w.scalars[1] + w.scalars[2] - 5.0).abs(),
          closeTo(2 * math.pi, 1e-9));
      expectSameDirection(w.scalars[1] + w.scalars[2], 5.0);
    });

    test('an arc end stretch on a negative sweep stays negative (M-03n)', () {
      final end = leafGrips(EntityKind.arc, arcNeg)[2];
      final out =
          reshapeLeaf(EntityKind.arc, arcNeg, end, at(arcNeg, 0.5, 30))!;
      expect(out.scalars[1], 2.2, reason: 'the start is copied bit for bit');
      expect(out.scalars[2], closeTo(-1.7, 1e-12));
      final past =
          reshapeLeaf(EntityKind.arc, arcNeg, end, at(arcNeg, 2.9, 30))!;
      expect(past.scalars[2], closeTo(0.7 - 2 * math.pi, 1e-12),
          reason: 'past the start the other way, still clockwise');
      final pos = reshapeLeaf(EntityKind.arc, arcPos,
          leafGrips(EntityKind.arc, arcPos)[2], at(arcPos, 2.6, 40))!;
      expect(pos.scalars[1], 0.3);
      expect(pos.scalars[2], closeTo(2.3, 1e-12));
    });

    test('an arc radius grip copies the angles', () {
      final mid = leafGrips(EntityKind.arc, arcPos)[3];
      final out = reshapeLeaf(
          EntityKind.arc, arcPos, mid, Vector2(7050 + 36, 3200 + 48))!;
      expect(out.scalars, [60, 0.3, 1.9]);
      expect(out.coords, arcPos.coords);
    });

    test('an arc stretch to a zero or a full sweep is null', () {
      final grips = leafGrips(EntityKind.arc, arcPos);
      expect(
          reshapeLeaf(
              EntityKind.arc, arcPos, grips[1], at(arcPos, 0.3 + 1.9, 40)),
          isNull,
          reason: 'the start dragged onto the end');
      expect(reshapeLeaf(EntityKind.arc, arcPos, grips[2], at(arcPos, 0.3, 40)),
          isNull,
          reason: 'the end dragged onto the start');
    });

    test(
        'an arc end stretch landing within tolerance of a full turn is '
        'degenerate (M-03ay)', () {
      final end = leafGrips(EntityKind.arc, arcPos)[2];
      // The end dragged to just short of the start the *positive* way
      // around: the resulting sweep is 2*pi - 1e-12, within
      // Tolerance.standard.angular of a full turn -- not within it of zero.
      final target = at(arcPos, 0.3 - 1e-12, 40);
      expect(reshapeLeaf(EntityKind.arc, arcPos, end, target), isNull,
          reason: 'a sweep within tolerance of 2*pi is as degenerate as one '
              'within tolerance of zero');
    });

    test('a move grip is not a reshape, and a kind without grips throws', () {
      expect(
          () => reshapeLeaf(EntityKind.circle, circle,
              leafGrips(EntityKind.circle, circle)[0], Vector2(7400, 3300)),
          throwsArgumentError);
      expect(
          () => reshapeLeaf(EntityKind.text, payload([7020, 3300], [12]),
              const Grip(GripRole.stretch, 0, 7020, 3300), Vector2(7030, 3300)),
          throwsArgumentError);
    });
  });
}
