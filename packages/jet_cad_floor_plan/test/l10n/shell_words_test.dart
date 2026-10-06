// Spec 14d L3-L5 (revision 2): the shell's words follow the host's locale
// -- the palette, the tabs, the status line, the toolbar's tooltips with
// the language's modifier, the Export dialog, the service bar -- and
// follow a change of it while mounted.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/l10n/localizations.dart';

Widget app(FloorPlanController c, Locale locale) => MaterialApp(
    locale: locale,
    supportedLocales: floorPlanSupportedLocales,
    localizationsDelegates: floorPlanLocalizationsDelegates,
    home: Scaffold(body: FloorPlanView(controller: c, onExport: (_) {})));

Future<FloorPlanController> pump(WidgetTester tester, Locale locale) async {
  final c = FloorPlanController();
  addTearDown(c.dispose);
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app(c, locale));
  await tester.pump();
  return c;
}

String tooltipOf(WidgetTester tester, String key) =>
    tester.widget<IconButton>(find.byKey(Key(key))).tooltip!;

void main() {
  testWidgets(
      'SW1 in Turkish: the palette, the tabs, the status line, the toolbar '
      'and the Export dialog', (tester) async {
    await pump(tester, const Locale('tr'));
    for (final w in ['Seç', 'Duvar', 'Kapı', 'Ölçü', 'Dolgu', 'Araçlar']) {
      expect(find.text(w), findsWidgets, reason: w);
    }
    expect(find.text('Wall'), findsNothing);
    expect(find.text('Seç'), findsNWidgets(2), reason: 'palette, status');
    expect(tooltipOf(tester, 'toolbar-undo'), startsWith('Geri al'));
    expect(tooltipOf(tester, 'toolbar-print'), 'Yazdır… (Ctrl+P)');
    await tester.tap(find.byKey(const Key('toolbar-export')));
    await tester.pumpAndSettle();
    expect(find.text('İptal'), findsOneWidget);
    expect(find.text('Dışa aktar'), findsNWidgets(2), reason: 'title, button');
  });

  testWidgets(
      'SW2 in German: Strg in a tooltip; the service bar; a switch to '
      'English while mounted renames everything (L3, M-14d-s)', (tester) async {
    final c = await pump(tester, const Locale('de'));
    expect(find.text('Wand'), findsOneWidget);
    expect(tooltipOf(tester, 'toolbar-redo'), 'Wiederholen (Strg+Umschalt+Z)');
    c.setMode(FloorPlanMode.selection);
    await tester.pump();
    await tester.pump();
    expect(tooltipOf(tester, 'service-undo'), 'Rückgängig');
    expect(tooltipOf(tester, 'service-print'), 'Drucken…');

    await tester.pumpWidget(app(c, const Locale('en')));
    await tester.pump();
    expect(tooltipOf(tester, 'service-undo'), 'Undo');
    c.setMode(FloorPlanMode.design);
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(app(c, const Locale('tr')));
    await tester.pump();
    expect(find.text('Duvar'), findsOneWidget);
    expect(tooltipOf(tester, 'toolbar-print'), 'Yazdır… (Ctrl+P)');
    await tester.pumpWidget(app(c, const Locale('de')));
    await tester.pump();
    expect(find.text('Wand'), findsOneWidget);
    expect(tooltipOf(tester, 'toolbar-print'), 'Drucken… (Strg+P)');
  });
}
