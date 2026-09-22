import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('pick', () {
    test('metric: the smallest ladder step at or above 64 px', () {
      // At 0.137 px/mm: 100 mm → 13.7 px, 200 → 27.4, 500 → 68.5. Major is
      // 500 mm; minor 100 mm → 13.7 px ≥ 8, drawn. M-04c (continuous) would
      // answer 64 / 0.137 = 467.15 mm.
      final s = GridScale.pick(DisplayUnit.meters, 0.137)!;
      expect(s.majorMm, 500);
      expect(s.minorMm, 100);
      expect(s.divisor, 5);
    });

    test('a mantissa-2 major divides by 4', () {
      // At 0.35 px/mm: 100 → 35 px, 200 → 70 px. Major 200, minor 50 → 17.5 px.
      final s = GridScale.pick(DisplayUnit.centimeters, 0.35)!;
      expect(s.majorMm, 200);
      expect(s.minorMm, 50);
      expect(s.divisor, 4);
    });

    test('minor is null under the minor threshold', () {
      // M-04g's engine half, with the threshold passed explicitly because
      // the shipped 64/8 pair cannot reach the branch on its own (Ruling 04-7).
      final s = GridScale.pick(DisplayUnit.meters, 0.137, minorMinPixels: 20)!;
      expect(s.majorMm, 500);
      expect(s.minorMm, isNull);
    });

    test('imperial ladder in inches and feet', () {
      // At 0.137 px/mm: 6" = 152.4 mm → 20.9 px; 1' = 304.8 → 41.8; 2' →
      // 83.5 px. Major 2', minor 6" (divisor 4) → 20.9 px.
      final s = GridScale.pick(DisplayUnit.feetInches, 0.137)!;
      expect(s.majorMm, closeTo(609.6, 1e-9));
      expect(s.minorMm, closeTo(152.4, 1e-9));
      // Ruling 04-11: the minor must be the same double as the ladder's own
      // 6" rung, not merely close to it — a foot-based major divided by 4
      // has to coincide bit for bit with a rung built as a foot fraction.
      expect(GridScale.ladderFor(DisplayUnit.feetInches).contains(s.minorMm),
          isTrue,
          reason: "the 2 ft major's minor is the 6 in rung, bit for bit");
    });

    test('imperial divisor is 4 even with a floor', () {
      // Ruling 04-12: every imperial step divides by 4, floor or not.
      final s = GridScale.pick(DisplayUnit.feetInches, 0.25, floorMm: 304.8)!;
      expect(s.majorMm, 304.8);
      expect(s.minorMm, 76.2);
      expect(s.divisor, 4);
    });

    test('null past the top of the ladder, and for a bad scale', () {
      expect(GridScale.pick(DisplayUnit.meters, 1e-9), isNull);
      expect(GridScale.pick(DisplayUnit.meters, 0), isNull);
      expect(GridScale.pick(DisplayUnit.meters, double.nan), isNull);
    });

    test('a floor is exact when it fits and the ladder climbs from it', () {
      // M-04q. At 0.3 px/mm the metric ladder says 500 (150 px) … no: 200
      // → 60 px < 64, 500 → 150 px. Floor 250 → 75 px: exact.
      final s = GridScale.pick(DisplayUnit.meters, 0.3, floorMm: 250)!;
      expect(s.majorMm, 250);
      // At 0.1 px/mm: 250 → 25 px, 500 → 50, 1250 → 125. Climbs to 1250.
      expect(
          GridScale.pick(DisplayUnit.meters, 0.1, floorMm: 250)!.majorMm, 1250);
    });

    test('the ladders are ascending and the metric one is 1-2-5', () {
      final metric = GridScale.ladderFor(DisplayUnit.meters);
      for (var i = 1; i < metric.length; i++) {
        expect(metric[i], greaterThan(metric[i - 1]));
      }
      expect(metric.first, closeTo(0.1, 1e-12));
      expect(metric.last, 5e7);
      expect(metric.sublist(3, 6), [1, 2, 5]);
      final imperial = GridScale.ladderFor(DisplayUnit.inches);
      expect(imperial.first, closeTo(25.4 / 16, 1e-12));
      expect(imperial.contains(304.8), isTrue);
      for (var i = 1; i < imperial.length; i++) {
        expect(imperial[i], greaterThan(imperial[i - 1]));
      }
    });
  });

  group('formatLength', () {
    test('per unit', () {
      // M-04i.
      expect(formatLength(1500, DisplayUnit.millimeters), '1500 mm');
      expect(formatLength(1500, DisplayUnit.centimeters), '150 cm');
      expect(formatLength(1500, DisplayUnit.meters), '1.5 m');
      expect(formatLength(311.15, DisplayUnit.inches), '12.25 in');
      expect(formatLength(1066.8, DisplayUnit.feetInches), '3\'-6"');
      expect(formatLength(1079.5, DisplayUnit.feetInches), '3\'-6 1/2"');
      expect(formatLength(152.4, DisplayUnit.feetInches), '0\'-6"');
      expect(formatLength(-2000, DisplayUnit.meters), '-2 m');
      expect(formatLength(0, DisplayUnit.meters), '0 m');
      expect(formatLength(0, DisplayUnit.feetInches), '0\'-0"');
      expect(formatLength(-0.5, DisplayUnit.feetInches), '0\'-0"');
    });
  });

  group('snapToGrid', () {
    final page = PageComponent(originX: 7350, originY: -1230);

    test('nearest, anchored at the sheet origin, negative side too', () {
      // M-04h (truncate) and M-04f (world anchor).
      final p =
          snapToGrid(Vector2(7350 + 0.7 * 500, -1230 - 0.7 * 500), 500, page);
      expect(p.x, 7350 + 500);
      expect(p.y, -1230 - 500);
      final q =
          snapToGrid(Vector2(7350 + 0.3 * 500, -1230 + 0.3 * 500), 500, page);
      expect(q.x, 7350);
      expect(q.y, -1230);
    });

    test('an adaptive step lands on the drawn lattice', () {
      // Invariant 3's engine half: the step comes from pick.
      final s = GridScale.pick(DisplayUnit.meters, 0.137)!;
      final step = s.minorMm ?? s.majorMm;
      final p = snapToGrid(Vector2(8000, -230), step, page);
      expect((p.x - page.originX) % step, 0);
      expect((p.y - page.originY) % step, 0);
    });

    test('refuses a non-positive step', () {
      expect(() => snapToGrid(Vector2.zero(), 0, page), throwsArgumentError);
    });
  });
}
