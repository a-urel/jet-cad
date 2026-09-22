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
  const GridScale(
      {required this.majorMm, required this.minorMm, required this.unit});

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
        for (final feet in const [
          1,
          2,
          5,
          10,
          20,
          50,
          100,
          200,
          500,
          1000,
          5000
        ])
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
