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
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/src/l10n/localizations.dart';
import 'package:jet_cad_floor_plan/src/startup_plan.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tables/table_fixture.dart';

import 'panel_words_test.dart' show wallPlan;

void main() {
  heightMain();
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

/// The sample plan with a four-seat table, turned, off the origin.
String furnishedPlan() {
  final measurer = FlutterTextMeasurer();
  final doc = startupPlan(measurer);
  doc.commands.execute(placeSymbol(doc, entryOf(tableSymbol(seats: 4)),
      at: Vector2(1234.5, 2345.25), quarterTurns: 1));
  final json = DraftDocumentCodec.encodeToString(doc);
  doc.dispose();
  measurer.clear();
  return json;
}

void heightMain() {
  for (final code in ['en', 'de', 'tr']) {
    testWidgets(
        'OV-H-$code at 656 x 700, each root object of the sample plan and a '
        'table selected in turn: the right panel never overflows (review '
        '14d-1 F-2)', (tester) async {
      final c = FloorPlanController(json: furnishedPlan());
      addTearDown(c.dispose);
      await tester.binding.setSurfaceSize(const Size(656, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          locale: Locale(code),
          supportedLocales: floorPlanSupportedLocales,
          localizationsDelegates: floorPlanLocalizationsDelegates,
          home: Scaffold(body: FloorPlanView(controller: c))));
      await tester.pump();
      final doc = c.activeDocument;
      final roots = [
        for (final n in doc.tree.nodes)
          if (n.parent == doc.rootHandle) n.handle
      ];
      expect(roots.length, greaterThan(20), reason: 'premise');
      expect(TableSurvey.of(doc).tables, isNotEmpty, reason: 'premise');
      for (final h in roots) {
        c.activeSelection.replace([SelectionKey.root(h)]);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$code, $h');
      }
    });
  }
}
