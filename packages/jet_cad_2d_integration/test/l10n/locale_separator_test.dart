// Spec Q0 N2 (M-Q0-e): a loaded plan is never settled. The UI language
// differs from the page's separator wherever it could leak in (the fixture
// rule).
// Ported from jet_cad_floor_plan/test/host/new_plan_separator_test.dart
// (NS3) through 2a's port (jet_cad_2d_plan/test/controller/
// locale_separator_test.dart: the view replaced by the report it makes,
// `reportLocale`) over the decimal separator's plan, with the source's
// room line restored (3a Task 27, Appendix A D-24); assertions unchanged.
// `reportLocale` is @internal (ruling R-P9).
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';

import '../support/plans.dart' show labelsOf, textOf;
import '../support/q0_plan.dart';

DecimalSeparator separatorOf(DraftDocument doc) =>
    doc.components.get<PageComponent>(doc.rootHandle)!.decimalSeparator;

void main() {
  testWidgets(
      'NS3 a loaded plan is never settled (N2): by the constructor or by '
      'load(), a point plan shown in Turkish stays point, its texts with .',
      (tester) async {
    final f = q0PlanJson();
    final json = f.json;
    final premise = architectureController(json: json);
    addTearDown(premise.dispose);
    expect(separatorOf(premise.document), DecimalSeparator.point,
        reason: 'premise');
    final byJson = architectureController(json: json);
    addTearDown(byJson.dispose);
    // ignore: invalid_use_of_internal_member
    byJson.reportLocale(const Locale('tr'));
    final doc = byJson.document;
    expect(separatorOf(doc), DecimalSeparator.point);
    final room = doc.components.withComponent<RoomParams>().single;
    expect(textOf(doc, labelsOf(doc, room)[1]), '12.37 m²');
    expect(byJson.save(), json, reason: "the bytes are the file's");

    final byLoad = architectureController();
    addTearDown(byLoad.dispose);
    byLoad.load(json);
    // ignore: invalid_use_of_internal_member
    byLoad.reportLocale(const Locale('tr'));
    expect(separatorOf(byLoad.document), DecimalSeparator.point);
    expect(byLoad.dirty.value, isFalse);
    expect(byLoad.save(), json);
    await tester.pump();
  });
}
