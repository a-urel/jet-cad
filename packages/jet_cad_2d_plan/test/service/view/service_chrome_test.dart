// The service view's chrome in shadcn (spec "Canvas-owned reads", SV1-SV4):
// the bar's buttons are the chrome's parts under a host ShadTheme, the bar
// keeps `PlanTheme.serviceBarHeight`, the canvas keeps reading the Material
// theme, and a standalone view builds under a bare MaterialApp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show ChromePalette;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/canvas/plan_canvas_view.dart';
import 'package:jet_cad_2d_plan/src/chrome/icon_button.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../support/service_host.dart' show byKey, serviceController;

const _keys = [
  'service-undo',
  'service-redo',
  'service-guides',
  'service-merge',
  'service-split',
  'service-export',
  'service-print',
];

Future<void> pump(WidgetTester tester, Widget Function(Widget view) wrap,
    {PlanTheme? theme}) async {
  final c = serviceController();
  c.setMode(PlanMode.service);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(wrap(PlanServiceView(
    controller: c,
    theme: theme,
    onExport: (_) {},
    onMergeRequested: (_) {},
    onSplitRequested: (_) {},
  )));
  await tester.pump();
  await tester.pump();
}

Widget app(Widget view,
        {ThemeData? theme,
        ThemeMode mode = ThemeMode.light,
        bool shad = false}) =>
    MaterialApp(
      theme: theme ?? ThemeData(brightness: Brightness.light),
      darkTheme: ThemeData(brightness: Brightness.dark),
      themeMode: mode,
      themeAnimationDuration: Duration.zero,
      home: Scaffold(
          body: shad
              ? ShadTheme(
                  data: ShadThemeData(
                    brightness: Brightness.dark,
                    colorScheme: const ShadSlateColorScheme.dark(
                        background: Color(0xFF102030)),
                  ),
                  child: view)
              : view),
    );

ColoredBox canvasBox(WidgetTester tester) => tester.widget<ColoredBox>(find
    .ancestor(
        of: find.byType(PlanCanvasView), matching: find.byType(ColoredBox))
    .first);

void main() {
  testWidgets(
      'SV1 the service bar\'s buttons are PlanIconButtons with today\'s keys '
      'under a host ShadTheme', (tester) async {
    await pump(tester, (v) => app(v, shad: true));
    for (final key in _keys) {
      expect(tester.widget(byKey(key)), isA<PlanIconButton>(), reason: key);
    }
    final guides = tester.widget<PlanIconButton>(byKey('service-guides'));
    expect(guides.selected, isNotNull);
    expect(
        tester.widget<PlanIconButton>(byKey('service-undo')).selected, isNull);
  });

  testWidgets('SV2 PlanTheme.serviceBarHeight still sizes the bar',
      (tester) async {
    await pump(tester, (v) => app(v, shad: true),
        theme: const PlanTheme(serviceBarHeight: 61));
    expect(tester.getSize(byKey('service-bar')).height, 61);
  });

  testWidgets(
      'SV3 the canvas background, paper and brightness still come from '
      'ThemeData/PlanTheme when the ShadTheme\'s brightness differs',
      (tester) async {
    await pump(tester, (v) => app(v, shad: true));
    final material = tester.element(byKey('service-bar'));
    final scheme = Theme.of(material).colorScheme;
    expect(canvasBox(tester).color, scheme.surface);
    expect(tester.widget<PlanCanvasView>(find.byType(PlanCanvasView)).chrome,
        ChromePalette.of(Brightness.light));
    // The same with a dark Material theme under a light ShadTheme.
    await tester.pumpWidget(const SizedBox());
    await pump(
        tester,
        (v) => MaterialApp(
              theme: ThemeData(brightness: Brightness.light),
              darkTheme: ThemeData(brightness: Brightness.dark),
              themeMode: ThemeMode.dark,
              themeAnimationDuration: Duration.zero,
              home: Scaffold(
                  body: ShadTheme(
                      data: ShadThemeData(
                          brightness: Brightness.light,
                          colorScheme: const ShadSlateColorScheme.light(
                              background: Color(0xFFF0E0D0))),
                      child: v)),
            ));
    final dark = Theme.of(tester.element(byKey('service-bar'))).colorScheme;
    expect(canvasBox(tester).color, dark.surface);
    expect(tester.widget<PlanCanvasView>(find.byType(PlanCanvasView)).chrome,
        ChromePalette.of(Brightness.dark));
    // A PlanTheme canvas background wins over both.
    await tester.pumpWidget(const SizedBox());
    await pump(tester, (v) => app(v, shad: true),
        theme: const PlanTheme(canvasBackground: Color(0xFF445566)));
    expect(canvasBox(tester).color, const Color(0xFF445566));
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
        'SV4 a standalone PlanServiceView under a bare MaterialApp '
        'builds, ${mode.name}', (tester) async {
      await pump(tester, (v) => app(v, mode: mode));
      expect(tester.takeException(), isNull);
      for (final key in _keys) {
        expect(tester.widget(byKey(key)), isA<PlanIconButton>(), reason: key);
      }
      expect(byKey('service-bar'), findsOneWidget);
    });
  }
}
