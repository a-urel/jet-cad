// Spec 14d R-2, M-14d-c (V-11): German and Turkish words are longer; the
// shell must not overflow at the top bar's 656 px floor (plan 13) and up,
// with OSNAP off (its longest words), the Symbols tab, a selected wall's
// panels and the service bar.
// Ported from jet_cad_floor_plan/test/l10n/overflow_test.dart (OV-H, each
// language; OV-de and OV-tr are 2a's) (3a Task 27, Appendix A D-24);
// assertions unchanged but the rulings named: IP-R4 (the table is the
// fixture kit's, a unit labelled `1` as today's placer numbered it).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/plans.dart' show planWith;
import '../support/units.dart' show fxKit, labelUnit, placeAt, tableSymbol;

void main() {
  heightMain();
}

/// The sample plan with a four-seat table, turned, off the origin.
String furnishedPlan() => planWith((d) {
      final h = placeAt(d, tableSymbol(seats: 4), Vector2(1234.5, 2345.25),
          quarterTurns: 1);
      labelUnit(d, h, '1');
    }, kits: [architectureKit, fxKit()], first: buildSampleFlat);

void heightMain() {
  for (final code in ['en', 'de', 'tr']) {
    testWidgets(
        'OV-H-$code at 656 x 700, each root object of the sample plan and a '
        'table selected in turn: the right panel never overflows (review '
        '14d-1 F-2)', (tester) async {
      final c = PlanController(
          kits: [architectureKit, fxKit()], json: furnishedPlan());
      addTearDown(c.dispose);
      await tester.binding.setSurfaceSize(const Size(656, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          locale: Locale(code),
          supportedLocales: planSupportedLocales,
          localizationsDelegates: planLocalizationsDelegates,
          home: Scaffold(body: PlanEditor(controller: c))));
      await tester.pump();
      final doc = c.document;
      final roots = [
        for (final n in doc.tree.nodes)
          if (n.parent == doc.rootHandle) n.handle
      ];
      expect(roots.length, greaterThan(20), reason: 'premise');
      expect(c.units, isNotEmpty, reason: 'premise');
      for (final h in roots) {
        c.activeSelection.replace([SelectionKey.root(h)]);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$code, $h');
      }
    });
  }
}
