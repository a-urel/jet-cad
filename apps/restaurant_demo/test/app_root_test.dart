// The demo's root (spec D1, D2): a plain `ShadApp` in the zinc theme, no
// `MaterialApp`. The Material theme the canvas reads is the one `ShadApp`
// derives from the `ShadTheme`; the POS look adds its `PlanTheme` extension
// to it through `materialThemeBuilder`.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:restaurant_demo/demo_theme.dart';
import 'package:restaurant_demo/main.dart' show DemoHome;
import 'package:shadcn_ui/shadcn_ui.dart' show ShadApp, ShadTheme;

import 'support/demo_rig.dart';

void main() {
  testWidgets('RD1 the root is a ShadApp in the zinc theme, not a MaterialApp',
      (tester) async {
    await pumpDemo(tester);
    expect(find.byType(ShadApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsNothing);
    final context = tester.element(find.byType(PlanEditor));
    final brightness = tester.platformDispatcher.platformBrightness;
    expect(ShadTheme.of(context).colorScheme,
        demoShadTheme(brightness).colorScheme);
  });

  testWidgets('RD2 the derived Material theme follows the platform brightness',
      (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpDemo(tester);
    for (final b in [Brightness.dark, Brightness.light]) {
      tester.platformDispatcher.platformBrightnessTestValue = b;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final context = tester.element(find.byType(PlanEditor));
      expect(Theme.of(context).brightness, b);
      expect(Theme.of(context).colorScheme.surface,
          demoShadTheme(b).colorScheme.background);
      expect(ShadTheme.of(context).brightness, b);
    }
  });

  testWidgets(
      'RD3 the POS PlanTheme is the Material theme\'s extension '
      'under the POS look only', (tester) async {
    await pumpDemo(tester);
    PlanTheme? extension() => Theme.of(tester.element(find.byType(PlanEditor)))
        .extension<PlanTheme>();
    final b = tester.platformDispatcher.platformBrightness;
    expect(extension(), isNull);
    await tester.tap(byKey('look-pos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(extension(), posPlanTheme(b));
    await tester.tap(byKey('look-standard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(extension(), isNull);
  });

  testWidgets(
      'RD4 a bare Text takes the ShadTheme\'s text style (Roboto, the '
      'foreground), docked and in the side sheet, light and dark',
      (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    for (final b in [Brightness.light, Brightness.dark]) {
      tester.platformDispatcher.platformBrightnessTestValue = b;
      final theme = demoShadTheme(b);
      void expectStyle(DefaultTextStyle style, String where) {
        expect(style.style.fontFamily, 'Roboto', reason: '$where $b');
        expect(style.style.color, theme.colorScheme.foreground,
            reason: '$where $b');
        expect(style.style.fontSize, theme.textTheme.p.fontSize,
            reason: '$where $b');
      }

      void check(String where) {
        // The panel's line, and the route's own (what any bare Text of the
        // page or of another route gets).
        for (final at in [byKey('tables'), find.byType(DemoHome)]) {
          expectStyle(DefaultTextStyle.of(tester.element(at)), where);
        }
      }

      await pumpDemo(tester);
      await tester.pump(const Duration(milliseconds: 300));
      check('docked');
      await pumpDemo(tester, size: const Size(375, 812));
      await tester.pump(const Duration(milliseconds: 300));
      expect(byKey('side-panel-drawer'), findsNothing, reason: 'premise');
      await tester.tap(byKey('side-panel-button'));
      await tester.pumpAndSettle();
      expect(byKey('side-panel-drawer'), findsOneWidget, reason: 'premise');
      check('sheet');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(byKey('side-panel-drawer'), findsNothing, reason: 'closed');
    }
  });
}
