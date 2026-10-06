// Spec 14d R-2, M-14d-c (V-11): German and Turkish words are longer; the
// shell must not overflow at the top bar's 656 px floor (plan 13) and up,
// with OSNAP off (its longest words), the Symbols tab, a selected wall's
// panels and the service bar.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_view.dart';
import 'package:jet_cad_floor_plan/src/l10n/localizations.dart';

import 'panel_words_test.dart' show wallPlan;

void main() {
  for (final code in ['de', 'tr']) {
    testWidgets(
        'OV-$code no overflow from 704 px down to 656 px, OSNAP off, a wall '
        'selected, both tabs and the service bar (M-14d-c)', (tester) async {
      final (json, wall) = wallPlan();
      final c = FloorPlanController(json: json);
      addTearDown(c.dispose);
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          locale: Locale(code),
          supportedLocales: floorPlanSupportedLocales,
          localizationsDelegates: floorPlanLocalizationsDelegates,
          home: Scaffold(body: FloorPlanView(controller: c))));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.f3);
      await tester.pump();
      c.activeSelection.replace([SelectionKey.root(wall)]);
      await tester.pump();
      expect(find.byKey(const Key('osnap-text')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('osnap-text'))).data,
          {'de': 'OSNAP aus', 'tr': 'OSNAP kapalı'}[code],
          reason: 'premise: OSNAP off, in the language');
      Future<void> sweep(String what) async {
        for (var width = 704; width >= 656; width -= 4) {
          await tester.binding.setSurfaceSize(Size(width.toDouble(), 700));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$what, $width px');
        }
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        await tester.pump();
      }

      await sweep('tools');
      await tester.tap(find.byKey(const Key('tab-symbols')));
      await tester.pump();
      await sweep('symbols');
      c.setMode(FloorPlanMode.selection);
      await tester.pump();
      await tester.pump();
      await sweep('service');
    });
  }
}
