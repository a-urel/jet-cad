// jet_cad_floor_plan's test/host/controller_test.dart C3, C4, C5, C8 and
// CD1, the service halves, assertions unchanged (spec 2b S3, A12): the
// copy, its permissions, a load in service, a refused load in service,
// unitDetails following the active document.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart'
    show placementTransform;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/service_plans.dart';
import '../support/test_kit.dart';

PlanController controller(String json) =>
    controllerFor(kits: [testKit()], json: json);

void main() {
  testWidgets(
      'MD-C3 leaving service discards the copy; re-entering shows the design '
      '(C3, M-14b2-2)', (tester) async {
    final c = controller(servicePlanText());
    final designed = parts(unitNode(c.activeDocument, '1').transform);
    c.setMode(PlanMode.service);
    move(c, '1', 750, -250);
    expect(parts(unitNode(c.activeDocument, '1').transform), isNot(designed));
    c.setMode(PlanMode.design);
    c.setMode(PlanMode.service);
    expect(parts(unitNode(c.activeDocument, '1').transform), designed);
    await tester.pump();
  });

  testWidgets('MD-C4 the copy refuses geometry and structure (C4, M-14b2-6)',
      (tester) async {
    final c = controller(servicePlanText());
    c.setMode(PlanMode.service);
    expect(c.activeDocument.commands.permissions, DraftPermissions.runtime);
    expect(() => drawLine(c), throwsA(isA<PermissionDeniedError>()));
    expect(() => move(c, '3', 10, 10), returnsNormally,
        reason: 'a move is a transform');
    await tester.pump();
  });

  testWidgets(
      'MD-C5 load clears the selection and rebuilds the copy from the new '
      'plan (C5, M-14b2-3)', (tester) async {
    final c = controller(servicePlanText());
    c.setMode(PlanMode.service);
    c.select({'1', '2'});
    expect(c.selectedUnits.value, {'1', '2'});
    move(c, '2', 900, 900);
    // The same plan, table 2 elsewhere: same handles, same labels.
    c.load(servicePlanText(secondAt: Vector2(5000, -3700)));
    expect(c.mode.value, PlanMode.service);
    expect(c.selectedUnits.value, isEmpty);
    final placed =
        placementTransform(at: Vector2(5000, -3700), basePoint: tableBase);
    expect(parts(unitNode(c.activeDocument, '2').transform), parts(placed));
    expect(c.dirty.value, isFalse);
    await tester.pump();
  });

  testWidgets(
      'MD-C8 a bad plan changes nothing in service: broken structure, '
      'unknown schema (C8, M-14b2-8)', (tester) async {
    final c = controller(servicePlanText());
    c.setMode(PlanMode.service);
    c.select({'3'});
    move(c, '3', -300, 200);
    final moved = parts(unitNode(c.activeDocument, '3').transform);
    final document = c.activeDocument;
    final good = jsonDecode(servicePlanText()) as Map<String, Object?>;
    final broken = jsonEncode({...good, 'entities': 7});
    final future = jsonEncode({...good, 'schemaVersion': 9999});
    for (final bad in [broken, future, '{}']) {
      expect(() => c.load(bad), throwsFormatException, reason: bad);
    }
    expect(c.activeDocument, same(document));
    expect(c.mode.value, PlanMode.service);
    expect(c.selectedUnits.value, {'3'});
    expect(parts(unitNode(c.activeDocument, '3').transform), moved);
    await tester.pump();
  });

  testWidgets(
      'MD-CD1 a service move changes unitDetails in service, and not the '
      'design\'s: back in design the unit is where it was designed (CD1, '
      'M-H4)', (tester) async {
    final c = controller(servicePlanText());
    final designed =
        unitNode(c.document, '1').transform.transformPoint(tableBase);
    double x() => c.unitDetails.first.center!.dx;
    double y() => c.unitDetails.first.center!.dy;
    expect(c.unitDetails.first.unit.label, '1', reason: 'premise');
    expect(x(), closeTo(designed.x, 1e-12 * designed.x.abs()));

    c.setMode(PlanMode.service);
    move(c, '1', 750, -250);
    await tester.pump();
    expect(x(), closeTo(designed.x + 750, 1e-12 * designed.x.abs()));
    expect(y(), closeTo(designed.y - 250, 1e-12 * designed.y.abs()));

    c.setMode(PlanMode.design);
    await tester.pump();
    expect(x(), closeTo(designed.x, 1e-12 * designed.x.abs()));
    expect(y(), closeTo(designed.y, 1e-12 * designed.y.abs()));
  });
}
