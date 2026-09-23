import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

GeometryPayload payload(List<double> coords, List<double> scalars) =>
    GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List.fromList(scalars));

/// translate(p) ∘ rotate(θ) ∘ translate(−p): a rotation about p.
Transform2 rotationAbout(double theta, double px, double py) =>
    Transform2.translation(px, py)
        .multiply(Transform2.rotation(theta))
        .multiply(Transform2.translation(-px, -py));

/// Every vertex, and the points a quarter, a half and three quarters along
/// every segment, of an interleaved coordinate list.
List<double> polySamples(Float64List c) {
  final out = <double>[...c];
  for (var i = 0; i + 3 < c.length; i += 2) {
    for (var k = 1; k <= 3; k++) {
      out
        ..add(c[i] + (c[i + 2] - c[i]) * k / 4)
        ..add(c[i + 1] + (c[i + 3] - c[i + 1]) * k / 4);
    }
  }
  return out;
}

void main() {
  test('a pure translation adds exactly, and every scalar is bit for bit', () {
    final t = Transform2.translation(123.25, -45.5);
    final cases = {
      EntityKind.point: payload([7250, 3300], []),
      EntityKind.line: payload([7010.1, 3020.3, 7130.7, 3060.9], []),
      EntityKind.polyline:
          payload([7200, 3000, 7400.5, 3000, 7400.5, 3150.25, 7200, 3000], []),
      EntityKind.circle: payload([7300.3, 3250.7], [25.5]),
      EntityKind.arc: payload([7050.1, 3200.9], [40, 0.3, 1.9]),
      EntityKind.text: payload([7020.2, 3300.4], [12, 0.2, 0.9, 0.1]),
    };
    for (final MapEntry(key: kind, value: p) in cases.entries) {
      final out = rigidTransformLeaf(kind, p, t);
      for (var i = 0; i < p.coords.length; i += 2) {
        expect(out.coords[i], p.coords[i] + 123.25, reason: '${kind.name} x');
        expect(out.coords[i + 1], p.coords[i + 1] + -45.5,
            reason: '${kind.name} y');
      }
      expect(out.scalars, p.scalars,
          reason: '${kind.name}: θ = 0 leaves every scalar unchanged');
    }
  });

  test('an arc rotates its start angle; radius and sweep are copied (M-03h)',
      () {
    final arc = payload([7050, 3200], [40, 0.3, 1.9]);
    final t = rotationAbout(0.7, 7100, 3100);
    final out = rigidTransformLeaf(EntityKind.arc, arc, t);
    final centre = t.transformPoint(Vector2(7050, 3200));
    expect(out.coords[0], closeTo(centre.x, 1e-9));
    expect(out.coords[1], closeTo(centre.y, 1e-9));
    expect(out.scalars[0], 40);
    expect(out.scalars[1], closeTo(1.0, 1e-12));
    expect(out.scalars[2], 1.9);
    final neg = rigidTransformLeaf(
        EntityKind.arc, payload([7150, 3250], [30, 2.2, -1.4]), t);
    expect(neg.scalars[1], closeTo(2.9, 1e-12));
    expect(neg.scalars[2], -1.4,
        reason: "a rigid transform keeps the sweep's sign");
  });

  test(
      'a text rotates its rotation scalar; a height-only text gains one '
      '(M-03m)', () {
    final t = rotationAbout(0.7, 7100, 3100);
    final full = rigidTransformLeaf(
        EntityKind.text, payload([7020, 3300], [12, 0.2, 0.9, 0.1]), t);
    expect(full.scalars[0], 12);
    expect(full.scalars[1], closeTo(0.9, 1e-12));
    expect(full.scalars.sublist(2), [0.9, 0.1]);
    final at = t.transformPoint(Vector2(7020, 3300));
    expect(full.coords[0], closeTo(at.x, 1e-9));
    expect(full.coords[1], closeTo(at.y, 1e-9));
    final schema3 =
        rigidTransformLeaf(EntityKind.text, payload([7020, 3300], [12]), t);
    expect(schema3.scalars, hasLength(2),
        reason: 'a real edit of that entity writes scalars[1] (spec D3)');
    expect(schema3.scalars[0], 12);
    expect(schema3.scalars[1], closeTo(0.7, 1e-12));
  });

  test('a circle moves its centre and keeps its scalars bit for bit', () {
    final t = rotationAbout(-1.1, 7000, 3000);
    final out =
        rigidTransformLeaf(EntityKind.circle, payload([7300, 3250], [25.5]), t);
    final centre = t.transformPoint(Vector2(7300, 3250));
    expect(out.coords[0], closeTo(centre.x, 1e-9));
    expect(out.coords[1], closeTo(centre.y, 1e-9));
    expect(out.scalars, [25.5]);
  });

  test('non-rigid transforms, fills and attribs are refused (M-03ax)', () {
    final line = payload([7010, 3020, 7130, 3060], []);
    for (final t in [
      Transform2.scale(2, 2),
      const Transform2(1, 0, 0.5, 1, 0, 0),
      Transform2.scale(1, -1),
    ]) {
      expect(() => rigidTransformLeaf(EntityKind.line, line, t),
          throwsArgumentError,
          reason: '$t');
    }
    final t = Transform2.translation(1, 2);
    expect(() => rigidTransformLeaf(EntityKind.fill, payload([], [17]), t),
        throwsArgumentError);
    expect(
        () => rigidTransformLeaf(
            EntityKind.attrib, payload([7020, 3300], [12]), t),
        throwsArgumentError);
    expect(isRigidTransform(rotationAbout(2.1, 7e5, -3e5)), isTrue);
  });

  test(
      'differential: 200 seeded rigid transforms agree with an independent '
      'oracle (M-03h, M-03m)', () {
    const seed = 0x5EED0003;
    const trials = 200;
    const ulp52 = 2.220446049250313e-16; // 2^-52
    // Ruling 03-16: the scale is the trial range the spec names, 2e6, so a
    // sample that lands near zero is judged by the magnitude it was
    // computed from. About 1.1e-7; an angle error moves a point by r·Δθ.
    const range = 2e6;
    final random = math.Random(seed);
    double coord() => (random.nextDouble() * 2 - 1) * 1e6;
    double angle() {
      while (true) {
        final a = (random.nextDouble() * 2 - 1) * 2 * math.pi;
        final q = a / (math.pi / 2);
        if ((q - q.roundToDouble()).abs() > 1e-3) return a;
      }
    }

    final worst = <String, double>{};
    void check(String kind, double a, double b) {
      final residual = (a - b).abs();
      final allowed = math.max(
          1e-12, 256 * ulp52 * math.max(range, math.max(a.abs(), b.abs())));
      expect(residual, lessThanOrEqualTo(allowed), reason: '$kind: $a vs $b');
      worst[kind] = math.max(worst[kind] ?? 0, residual);
    }

    for (var trial = 0; trial < trials; trial++) {
      final theta = angle();
      final tx = coord(), ty = coord();
      final t =
          Transform2.translation(tx, ty).multiply(Transform2.rotation(theta));
      // The oracle, written out here: rotate, then translate. It shares no
      // code with rigidTransformLeaf.
      final c = math.cos(theta), s = math.sin(theta);
      double ox(double x, double y) => c * x - s * y + tx;
      double oy(double x, double y) => s * x + c * y + ty;

      for (final (kind, n) in [
        (EntityKind.point, 1),
        (EntityKind.line, 2),
        (EntityKind.polyline, 5),
      ]) {
        final p = payload([for (var i = 0; i < 2 * n; i++) coord()], []);
        final out = rigidTransformLeaf(kind, p, t);
        final before = polySamples(p.coords);
        final after = polySamples(out.coords);
        for (var i = 0; i < before.length; i += 2) {
          check(kind.name, ox(before[i], before[i + 1]), after[i]);
          check(kind.name, oy(before[i], before[i + 1]), after[i + 1]);
        }
      }

      {
        final cx = coord(), cy = coord(), r = 1 + random.nextDouble() * 1e4;
        final out =
            rigidTransformLeaf(EntityKind.circle, payload([cx, cy], [r]), t);
        for (var k = 0; k < 8; k++) {
          final phi = k * math.pi / 4 + 0.1;
          final x = cx + r * math.cos(phi), y = cy + r * math.sin(phi);
          // The same rim point on the moved circle sits at φ + θ.
          check('circle', ox(x, y),
              out.coords[0] + out.scalars[0] * math.cos(phi + theta));
          check('circle', oy(x, y),
              out.coords[1] + out.scalars[0] * math.sin(phi + theta));
        }
      }

      {
        final cx = coord(), cy = coord(), r = 1 + random.nextDouble() * 1e4;
        final start = (random.nextDouble() * 2 - 1) * math.pi;
        var sweep = 0.0;
        while (sweep.abs() < 1e-3) {
          sweep = (random.nextDouble() * 2 - 1) * 2 * math.pi;
        }
        final out = rigidTransformLeaf(
            EntityKind.arc, payload([cx, cy], [r, start, sweep]), t);
        for (var k = 0; k <= 8; k++) {
          // Sampled from the stored values: centre + r·(cos, sin) over the
          // sweep, on both sides.
          final phi = start + sweep * k / 8;
          final psi = out.scalars[1] + out.scalars[2] * k / 8;
          final x = cx + r * math.cos(phi), y = cy + r * math.sin(phi);
          check(
              'arc', ox(x, y), out.coords[0] + out.scalars[0] * math.cos(psi));
          check(
              'arc', oy(x, y), out.coords[1] + out.scalars[0] * math.sin(psi));
        }
      }

      {
        final x = coord(), y = coord(), h = 1 + random.nextDouble() * 1e3;
        final heightOnly = trial % 4 == 0;
        final rot = heightOnly ? 0.0 : (random.nextDouble() * 2 - 1) * math.pi;
        final out = rigidTransformLeaf(EntityKind.text,
            payload([x, y], heightOnly ? [h] : [h, rot, 1.0, 0.0]), t);
        // The baseline direction, from the stored rotation (a height-only
        // text reads 0).
        final bx = x + h * math.cos(rot), by = y + h * math.sin(rot);
        final rot2 = out.scalars[1];
        check('text', ox(x, y), out.coords[0]);
        check('text', oy(x, y), out.coords[1]);
        check('text', ox(bx, by),
            out.coords[0] + out.scalars[0] * math.cos(rot2));
        check('text', oy(bx, by),
            out.coords[1] + out.scalars[0] * math.sin(rot2));
      }
    }
    // Pasted into the results note (spec, Differential check).
    print('03 differential: seed 0x5EED0003, $trials trials, '
        'worst residual per kind: $worst');
    expect(worst.keys,
        containsAll(['point', 'line', 'polyline', 'circle', 'arc', 'text']));
  });
}
