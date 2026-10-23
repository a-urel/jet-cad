// Ported from the old apps/restaurant_demo/test/demo_test.dart (audit
// section 4, docs/superpowers/specs/2026-10-16-restaurant-kit-test-audit.md):
// the Salon's zones A = 1-5, B = 6-7, C = 8-11 (zone spec Z22), through
// `fitToUnits` and `setUnitFocus`, none for the Teras: DZ1 (M-Z29), DZ2.
// The screen corners come from `unitDetails.corners` through
// `worldToGlobal`, the canvas from `canvasRect`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show Transform2;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform;

import 'support/demo_rig.dart';

List<double> coefficients(ViewportTransform v) {
  final m = v.worldToScreenMatrix;
  return [m.a, m.b, m.c, m.d, m.e, m.f];
}

/// Scrolls the side panel until [key] is in view.
Future<void> reveal(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(byKey(key), 100,
      scrollable: find
          .descendant(
              of: byKey('side-panel'), matching: find.byType(Scrollable))
          .first);
  await tester.pump();
}

void main() {
  testWidgets(
      'DZ1 M-Z29: zone B frames tables 6 and 7, not 1; "Fade the others" '
      'focuses {6, 7}; All clears the focus and fits the page; the zone and '
      'the switch are kept per area, and the Teras has none', (tester) async {
    final demo = await pumpDemo(tester);
    final c = demo.area.controller;
    await enterService(tester);
    await reveal(tester, 'fade-others');
    expect(byKey('zone-toggle'), findsOneWidget);
    expect(byKey('fade-others'), findsOneWidget);
    final canvas = c.canvasRect.value!;
    final page = coefficients(c.camera.value);
    for (final n in ['1', '6', '7']) {
      expect(unitCorners(c, n), hasLength(4), reason: 'premise: one $n');
    }

    await tester.tap(byKey('zone-B'));
    await tester.pump();
    await tester.pump();
    expect(coefficients(c.camera.value), isNot(page),
        reason: 'premise: the camera moved');
    for (final n in ['6', '7']) {
      for (final p in unitCorners(c, n)) {
        expect(canvas.contains(p), isTrue, reason: '$n\'s corner $p');
      }
    }
    final one = unitCorners(c, '1');
    expect(one.every((p) => !canvas.contains(p)), isTrue,
        reason: 'table 1 is outside: $one in $canvas');
    expect(c.unitFocus.value, isNull, reason: 'fading is off');

    await tester.tap(byKey('fade-others'));
    await tester.pump();
    await tester.pump();
    expect(c.unitFocus.value, {'6', '7'});
    expect(demo.area.fadeOthers, isTrue);
    expect(demo.areas[1].zone, isNull, reason: 'the Teras keeps its own');
    expect(demo.areas[1].fadeOthers, isFalse);

    // Kept per area: the Teras has no zones; back in the Salon, B and the
    // switch are as they were.
    await tester.tap(byKey('area-1'));
    await tester.pump();
    await tester.pump();
    // The panel's end, where the zones would be: none.
    await tester.drag(byKey('side-panel'), const Offset(0, -5000));
    await tester.pump();
    expect(find.text('Log'), findsOneWidget, reason: 'premise: the end');
    expect(byKey('zone-toggle'), findsNothing);
    expect(byKey('fade-others'), findsNothing);
    expect(demo.area.controller.unitFocus.value, isNull);
    await tester.tap(byKey('area-0'));
    await tester.pump();
    await tester.pump();
    await reveal(tester, 'fade-others');
    expect(
        tester.widget<SegmentedButton<String>>(byKey('zone-toggle')).selected,
        {'B'});
    expect(tester.widget<SwitchListTile>(byKey('fade-others')).value, isTrue);
    expect(c.unitFocus.value, {'6', '7'});

    await tester.tap(byKey('zone-all'));
    await tester.pump();
    await tester.pump();
    expect(c.unitFocus.value, isNull);
    final all = coefficients(c.camera.value);
    c.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2(0.37, 0, 0, -0.37, 211.5, 307.25));
    c.fitToView();
    await tester.pump();
    await tester.pump();
    expect(coefficients(c.camera.value), all, reason: 'All fits the page');
    for (final n in ['1', '6', '7']) {
      for (final p in unitCorners(c, n)) {
        expect(canvas.contains(p), isTrue, reason: 'the page shows $n');
      }
    }

    // Fading on, zone C: the focus follows the zone.
    await tester.tap(byKey('zone-C'));
    await tester.pump();
    await tester.pump();
    expect(c.unitFocus.value, {'8', '9', '10', '11'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('DZ2 the zones\' three strings in German and Turkish (Z22)',
      (tester) async {
    await pumpDemo(tester);
    await tester.drag(byKey('side-panel'), const Offset(0, -400));
    await tester.pump();
    expect(find.text('Zones'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Fade the others'), findsOneWidget);
    await switchLanguage(tester, 'de');
    expect(find.text('Bereiche'), findsOneWidget);
    expect(find.text('Alle'), findsOneWidget);
    expect(find.text('Andere abblenden'), findsOneWidget);
    await switchLanguage(tester, 'tr');
    expect(find.text('Bölgeler'), findsOneWidget);
    expect(find.text('Tümü'), findsOneWidget);
    expect(find.text('Diğerlerini soldur'), findsOneWidget);
  });
}
