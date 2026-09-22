### Task 4: `page_geometry.dart` and `grid_scale.dart`

**Files:**
- Create: `lib/src/document/page_geometry.dart`,
  `lib/src/geometry/grid_scale.dart`
- Modify: `lib/jet_cad_2d.dart` (two exports)
- Test: `test/document/page_geometry_test.dart`,
  `test/geometry/grid_scale_test.dart`

**Interfaces:**
- Produces: `sheetWorldRect`, `zoomOf`, `pageWorldOf`, `worldOfPage`;
  `kMajorMinPixels`, `kMinorMinPixels`, `GridScale` (`majorMm`, `minorMm`,
  `unit`, `divisor`), `GridScale.pick`, `GridScale.ladderFor`,
  `formatLength`, `snapToGrid`.

- [ ] **Step 1: Write the failing tests.**

```dart
// test/document/page_geometry_test.dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

void main() {
  final page = PageComponent(
      originX: 7350, originY: -1230, scaleDenominator: 50);  // A4 landscape

  test('the sheet rect is origin plus effective size times D', () {
    // M-04j (D ignored) and M-04e (orientation swapped).
    final rect = sheetWorldRect(page);
    expect(rect.minX, 7350);
    expect(rect.minY, -1230);
    expect(rect.maxX, 7350 + 297 * 50);
    expect(rect.maxY, -1230 + 210 * 50);
    final portrait = sheetWorldRect(page.copyWith(orientation: PageOrientation.portrait));
    expect(portrait.maxX, 7350 + 210 * 50);
  });

  test('100 % is pixelsPerPaperMm / D', () {
    // M-04n.
    const ppm = 96.0 / 25.4;
    expect(zoomOf(ppm / 50, page, ppm), closeTo(1.0, 1e-12));
    expect(zoomOf(ppm / 100, page, ppm), closeTo(0.5, 1e-12));
    expect(zoomOf(0.137, page.copyWith(scaleDenominator: 48), ppm),
        closeTo(0.137 * 48 / ppm, 1e-12));
  });

  test('page space is world minus origin, and back', () {
    final p = pageWorldOf(Vector2(8000, -230), page);
    expect(p.x, 650);
    expect(p.y, 1000);
    expect(worldOfPage(p, page).x, 8000);
    expect(worldOfPage(p, page).y, -230);
  });
}
```

**Ruling 04-7 (recorded in the ledger; spec D7 amended at execution):** with `kMajorMinPixels = 64` and divisors 4 and 5, a ladder step's minor spacing is always at least 12.8 px, so the 8 px minor threshold can never fire from the shipped ladders on their own. The threshold and the null branch stay (the spec names them, 03 may pass finer floors, a future divisor of 10 would need them) and `pick` takes `minorMinPixels` (default `kMinorMinPixels`) so the branch is testable: M-04g fires on that test and on the painter's `minor != null` branch (Task 6).

```dart
// test/geometry/grid_scale_test.dart
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
      expect(GridScale.pick(DisplayUnit.meters, 0.1, floorMm: 250)!.majorMm, 1250);
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
    });
  });

  group('snapToGrid', () {
    final page = PageComponent(originX: 7350, originY: -1230);

    test('nearest, anchored at the sheet origin, negative side too', () {
      // M-04h (truncate) and M-04f (world anchor).
      final p = snapToGrid(Vector2(7350 + 0.7 * 500, -1230 - 0.7 * 500), 500, page);
      expect(p.x, 7350 + 500);
      expect(p.y, -1230 - 500);
      final q = snapToGrid(Vector2(7350 + 0.3 * 500, -1230 + 0.3 * 500), 500, page);
      expect(q.x, 7350);
      expect(q.y, -1230);
    });

    test('an adaptive step lands on the drawn lattice', () {
      // Invariant 3's engine half: the step comes from pick.
      final s = GridScale.pick(DisplayUnit.meters, 0.137)!;
      final p = snapToGrid(Vector2(8000, -230), s.minorMm ?? s.majorMm, page);
      expect((p.x - page.originX) % (s.minorMm ?? s.majorMm), 0);
    });

    test('refuses a non-positive step', () {
      expect(() => snapToGrid(Vector2.zero(), 0, page), throwsArgumentError);
    });
  });
}
```

- [ ] **Step 2: Run both to fail.**

- [ ] **Step 3: Implement.**

```dart
// lib/src/document/page_geometry.dart
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../geometry/aabb2.dart';
import 'page_component.dart';

/// The sheet in world millimetres: origin plus the effective size at 1:D.
Aabb2 sheetWorldRect(PageComponent page) => Aabb2.raw(
      page.originX,
      page.originY,
      page.originX + page.effectiveWidthMm * page.scaleDenominator,
      page.originY + page.effectiveHeightMm * page.scaleDenominator,
    );

/// 1.0 is 100 %: the sheet at physical size on a 96-dpi screen (spec D4).
double zoomOf(double pxPerWorldMm, PageComponent page, double pixelsPerPaperMm) =>
    pxPerWorldMm * page.scaleDenominator / pixelsPerPaperMm;

/// World minus the sheet origin — what the rulers read (spec D5).
Vector2 pageWorldOf(Vector2 world, PageComponent page) =>
    Vector2(world.x - page.originX, world.y - page.originY);

Vector2 worldOfPage(Vector2 pageMm, PageComponent page) =>
    Vector2(pageMm.x + page.originX, pageMm.y + page.originY);
```

```dart
// lib/src/geometry/grid_scale.dart
import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../document/page_component.dart';

/// A major line needs at least this many screen pixels between it and the
/// next (spec D7).
const double kMajorMinPixels = 64.0;

/// A minor line needs at least this many.
const double kMinorMinPixels = 8.0;

/// One step ladder decision, shared by the grid, the rulers and the
/// adaptive snap so they cannot disagree (spec D7).
class GridScale {
  const GridScale({required this.majorMm, required this.minorMm, required this.unit});

  final double majorMm;

  /// Null when minors would be closer than the minor threshold.
  final double? minorMm;
  final DisplayUnit unit;

  /// Minor lines per major, or 1 when there are no minors.
  int get divisor => minorMm == null ? 1 : (majorMm / minorMm!).round();

  static const List<double> _mantissas = [1, 2, 5];

  /// Ascending steps in world millimetres.
  static List<double> ladderFor(DisplayUnit unit, {double? floorMm}) {
    if (floorMm != null) {
      return [
        for (var k = 0; k <= 7; k++)
          for (final m in _mantissas) floorMm * m * math.pow(10.0, k),
      ];
    }
    if (unit.isImperial) {
      return [
        for (final inches in const [1 / 16, 1 / 8, 1 / 4, 1 / 2, 1, 2, 6])
          inches * 25.4,
        for (final feet in const [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 5000])
          feet * 304.8,
      ];
    }
    return [
      for (var k = -1; k <= 7; k++)
        for (final m in _mantissas) m * math.pow(10.0, k),
    ];
  }

  /// The smallest ladder step whose screen spacing is at least
  /// [kMajorMinPixels], with its minor; null when no step reaches it (extreme
  /// zoom-out) or the scale is not a positive finite number.
  static GridScale? pick(
    DisplayUnit unit,
    double pxPerWorldMm, {
    double? floorMm,
    double minorMinPixels = kMinorMinPixels,
  }) {
    if (!pxPerWorldMm.isFinite || pxPerWorldMm <= 0) return null;
    for (final step in ladderFor(unit, floorMm: floorMm)) {
      if (step * pxPerWorldMm >= kMajorMinPixels) {
        final divisor = _divisorFor(step, unit, floorMm);
        final minor = step / divisor;
        return GridScale(
          majorMm: step,
          minorMm: minor * pxPerWorldMm >= minorMinPixels ? minor : null,
          unit: unit,
        );
      }
    }
    return null;
  }

  /// 4 for a mantissa-2 metric step and for every imperial step, else 5.
  static int _divisorFor(double step, DisplayUnit unit, double? floorMm) {
    if (unit.isImperial && floorMm == null) return 4;
    final ratio = floorMm == null ? step : step / floorMm;
    final exponent = (math.log(ratio) / math.ln10).floor();
    final mantissa = (ratio / math.pow(10.0, exponent)).round();
    return mantissa == 2 ? 4 : 5;
  }
}

/// A length in the display unit, spec D7's table.
String formatLength(double mm, DisplayUnit unit) => switch (unit) {
      DisplayUnit.millimeters => '${_trim(mm, 3)} mm',
      DisplayUnit.centimeters => '${_trim(mm / 10, 3)} cm',
      DisplayUnit.meters => '${_trim(mm / 1000, 3)} m',
      DisplayUnit.inches => '${_trim(mm / 25.4, 4)} in',
      DisplayUnit.feetInches => _feetInches(mm),
    };

String _trim(double value, int decimals) {
  var s = value.toStringAsFixed(decimals);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s == '-0' ? '0' : s;
}

String _feetInches(double mm) {
  final sign = mm < 0 ? '-' : '';
  final sixteenths = (mm.abs() / 25.4 * 16).round();
  final feet = sixteenths ~/ 192;
  final rest = sixteenths % 192;
  final inches = rest ~/ 16;
  var numerator = rest % 16;
  var denominator = 16;
  while (numerator != 0 && numerator.isEven) {
    numerator ~/= 2;
    denominator ~/= 2;
  }
  final fraction = numerator == 0 ? '' : ' $numerator/$denominator';
  return "$sign$feet'-$inches$fraction\"";
}

/// Nearest lattice point of [stepMm] anchored at the sheet origin (spec
/// D6). Works everywhere in the world; returns a fresh vector.
Vector2 snapToGrid(Vector2 world, double stepMm, PageComponent page) {
  if (!stepMm.isFinite || stepMm <= 0) {
    throw ArgumentError.value(stepMm, 'stepMm', 'must be finite and positive');
  }
  return Vector2(
    page.originX + ((world.x - page.originX) / stepMm).roundToDouble() * stepMm,
    page.originY + ((world.y - page.originY) / stepMm).roundToDouble() * stepMm,
  );
}
```

Exports: `src/document/page_geometry.dart`, `src/geometry/grid_scale.dart`.

- [ ] **Step 4: Run to pass.** Then the `jet_cad_2d` gate line. If
  `formatLength(311.15, inches)` gives `12.2500…` trimmed wrong, the fault
  is in `_trim` — fix it, not the expectation.
- [ ] **Step 5: Commit** — `feat(engine): page geometry, the grid ladder,
  formatLength, snapToGrid`.

---

