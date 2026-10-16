// Spec 3a C6: the integration package's two fixtures. A controller over the
// kit, with the permissions asked; the editor over it, in the language asked.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/editor_rig.dart';

void main() {
  testWidgets(
      'SC-smoke the controller loads the kit with the permissions asked; '
      'the editor shows the plan in the language asked', (tester) async {
    final c = architectureController();
    addTearDown(c.dispose);
    expect([for (final k in c.kits.kits) k.id], ['architecture']);
    expect(c.missingKits, isEmpty);
    expect(c.permissions, PlanPermissions.full);
    final readOnly =
        architectureController(permissions: PlanPermissions.readOnly);
    addTearDown(readOnly.dispose);
    // M-SC-perm: architectureController dropping `permissions`.
    expect(readOnly.permissions, PlanPermissions.readOnly);

    await pumpEditor(tester, c);
    expect(find.byType(PlanEditor), findsOneWidget);
    expect(status(tester), 'Select');
    // M-SC-7: planEditorApp ignoring `locale`.
    await pumpEditor(tester, c, locale: const Locale('tr'));
    expect(status(tester), 'Seç');
    expect(tester.takeException(), isNull);
  });
}
