import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/page_fixture.dart';
import 'support/spy_canvas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const barH = Size(800, kRulerThickness);
  const barV = Size(kRulerThickness, 600);

  RulerPainter make(RulerAxis axis,
          {CameraController? camera, Offset? pointer}) =>
      RulerPainter(
        axis: axis,
        camera: camera ?? standardCamera(),
        page: ValueNotifier<PageComponent?>(standardPage()),
        pointer: ValueNotifier<Offset?>(pointer),
      );

  test('major ticks sit at worldToScreen of the lattice, labelled in metres',
      () {
    // M-04a (translation dropped), M-04b (scale dropped). Not M-04i (unit):
    // the loop's label expectation calls `formatLength`, the function a unit
    // mutant would change, so it moves with the mutant. `grid_scale_test.dart`
    // kills M-04i; the one literal below is what this test contributes.
    // At 0.137 px/mm the major is 500 mm (Task 4). Page x = k·500 is world
    // x = 7350 + k·500; screen x = 0.137·world − 611.5.
    final painter = make(RulerAxis.horizontal);
    painter.paint(SpyCanvas(), barH);
    final majors = painter.debugLastTicks.where((t) => t.$2).toList();
    expect(majors, isNotEmpty);
    for (final tick in majors) {
      final pageX = (tick.$1 + 611.5) / 0.137 - 7350;
      expect(pageX / 500,
          closeTo(pageX / 500 == 0 ? 0 : (pageX / 500).roundToDouble(), 1e-6));
      expect(tick.$3, formatLength(pageX.roundToDouble(), DisplayUnit.meters));
    }
    // One literal, independent of `formatLength`: 500 mm at 1:50 in metres.
    final atFiveHundred = majors.firstWhere(
        (t) => ((t.$1 + 611.5) / 0.137 - 7350).roundToDouble() == 500,
        orElse: () => throw StateError(
            'no major at page x = 500 among ${majors.map((t) => t.$3)}'));
    expect(atFiveHundred.$3, '0.5 m');

    final spacing = majors[1].$1 - majors[0].$1;
    expect(spacing, closeTo(500 * 0.137, 1e-6));
    expect(majors.first.$1, isNot(closeTo(0, 1)),
        reason: 'not at the bar edge by chance');
  });

  test('the left ruler reads upward', () {
    // M-04p: page y increases as screen y decreases.
    final painter = make(RulerAxis.vertical);
    painter.paint(SpyCanvas(), barV);
    final majors = painter.debugLastTicks.where((t) => t.$2).toList();
    expect(majors.length, greaterThan(1));
    final values = [
      for (final t in majors) double.parse(t.$3!.split(' ').first)
    ];
    for (var i = 1; i < majors.length; i++) {
      expect(majors[i].$1, greaterThan(majors[i - 1].$1),
          reason: 'ticks ordered down the bar');
      expect(values[i], lessThan(values[i - 1]),
          reason: 'labels decrease downward');
    }
  });

  test('minor ticks are shorter and unlabelled', () {
    final painter = make(RulerAxis.horizontal);
    final canvas = SpyCanvas();
    painter.paint(canvas, barH);
    final minors = painter.debugLastTicks.where((t) => !t.$2);
    expect(minors, isNotEmpty);
    for (final t in minors) {
      expect(t.$3, isNull);
    }
    final lines = canvas.named('drawLine').toList();
    expect(lines.length, greaterThanOrEqualTo(painter.debugLastTicks.length));
  });

  test('the pointer marker is drawn at the pointer, and not without one', () {
    final painter =
        make(RulerAxis.horizontal, pointer: const Offset(123.4, 50));
    final canvas = SpyCanvas();
    painter.paint(canvas, barH);
    // Flutter's wide-gamut `Color` does not round-trip through a `Paint`
    // bit-exactly, so `==` between a `Paint.color` read back and the
    // original constant is unreliable here (confirmed empirically: two
    // colours that print identically compared unequal). `toARGB32()`
    // compares the actual 8-bit channels, as `page_chrome_painter_test.dart`
    // already does for the same reason.
    final marker = canvas
        .named('drawLine')
        .where((c) => c.color?.toARGB32() == kRulerPointer.toARGB32())
        .toList();
    expect(marker, hasLength(1));
    expect((marker.single.args[0] as Offset).dx, 123.4);
    final none = SpyCanvas();
    make(RulerAxis.horizontal).paint(none, barH);
    expect(
        none
            .named('drawLine')
            .where((c) => c.color?.toARGB32() == kRulerPointer.toARGB32()),
        isEmpty);
  });

  test('past the ladder top, only the bar and the pointer', () {
    final tiny = CameraController(ViewportTransform(
        worldToScreenMatrix: const Transform2(1e-9, 0, 0, -1e-9, 400, 300)));
    final painter = make(RulerAxis.horizontal, camera: tiny);
    painter.paint(SpyCanvas(), barH);
    expect(painter.debugLastTicks, isEmpty);
  });

  test('the corner shows the unit symbol', () {
    final n = ValueNotifier<PageComponent?>(
        standardPage().copyWith(displayUnit: DisplayUnit.feetInches));
    final painter = RulerCornerPainter(page: n);
    expect(painter.debugLastSymbol(), isNull);
    painter.paint(SpyCanvas(), const Size(kRulerThickness, kRulerThickness));
    expect(painter.debugLastSymbol(), 'ft');
  });
}
