import 'package:floor_planner/parametric/wall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

void main() {
  // Far-origin, non-round values: a key-order or field swap cannot hide.
  const p = WallParams(
      4500123.25, 1200456.5, 4503789.125, 1201011.75, 115, Justification.left);

  test('WP1 toJson: key order start, end, thickness, justification', () {
    final j = p.toJson();
    expect(j.keys.toList(), ['start', 'end', 'thickness', 'justification']);
    expect(j['start'], [4500123.25, 1200456.5]);
    expect(j['end'], [4503789.125, 1201011.75]);
    expect(j['thickness'], 115);
    expect(j['justification'], 'left');
    expect(p.typeId, 'floor_planner.wall');
    expect(WallParams.componentTypeId, 'floor_planner.wall');
    expect(p.start, Vector2(4500123.25, 1200456.5));
    expect(p.end, Vector2(4503789.125, 1201011.75));
  });

  test('WP2 round trip is exact, for every justification', () {
    for (final j in Justification.values) {
      // 0.1 and 1/3 are not dyadic: a lossy codec shows.
      final q = WallParams(4500000.1, 1200000.0 / 3, -0.3, 7e-7, 200.1, j);
      final back = WallParams.fromJson(q.toJson());
      expect(back, q);
      expect(back.sx, q.sx);
      expect(back.sy, q.sy);
      expect(back.ex, q.ex);
      expect(back.ey, q.ey);
      expect(back.thickness, q.thickness);
      expect(back.justification, j);
    }
    // Integer JSON numbers decode as doubles.
    expect(
        WallParams.fromJson({
          'start': [1, 2],
          'end': [3, 4],
          'thickness': 200,
          'justification': 'centre',
        }),
        const WallParams(1, 2, 3, 4, 200, Justification.centre));
    expect(p.copyWith(), p);
    expect(p.copyWith(end: Vector2(9, 8)),
        const WallParams(4500123.25, 1200456.5, 9, 8, 115, Justification.left));
    expect(
        p.copyWith(
            start: Vector2(1, 2),
            thickness: 300,
            justification: Justification.right),
        const WallParams(
            1, 2, 4503789.125, 1201011.75, 300, Justification.right));
  });

  test('WP3 == differs on each field alone; equal values hash alike', () {
    const q = WallParams(4500123.25, 1200456.5, 4503789.125, 1201011.75, 115,
        Justification.left);
    expect(q, p);
    expect(q.hashCode, p.hashCode);
    final ulp = [
      const WallParams(4500123.250000001, 1200456.5, 4503789.125, 1201011.75,
          115, Justification.left),
      const WallParams(4500123.25, 1200456.5000000002, 4503789.125, 1201011.75,
          115, Justification.left),
      const WallParams(4500123.25, 1200456.5, 4503789.125000001, 1201011.75,
          115, Justification.left),
      const WallParams(4500123.25, 1200456.5, 4503789.125, 1201011.7500000002,
          115, Justification.left),
      const WallParams(4500123.25, 1200456.5, 4503789.125, 1201011.75,
          115.00000000000001, Justification.left),
      const WallParams(4500123.25, 1200456.5, 4503789.125, 1201011.75, 115,
          Justification.right),
    ];
    for (final (i, r) in ulp.indexed) {
      expect(r == p, isFalse, reason: 'field $i');
      expect(p == r, isFalse, reason: 'field $i');
    }
  });

  test('WP4 fromJson of an unknown justification throws', () {
    final j = p.toJson()..['justification'] = 'center';
    expect(() => WallParams.fromJson(j), throwsArgumentError);
  });
}
