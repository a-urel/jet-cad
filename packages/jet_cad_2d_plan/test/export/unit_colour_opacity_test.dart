// 2b spec S4 "Painting": PlanExportRequest.unitColourOpacity, the
// controller's export and print argument (today's tableColorOpacity,
// floor_plan_controller.dart:1338-1384), and a seat's fill in the export's
// underlay placed by its row's group times its instance.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show PageUnderlayFill;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanSwatch;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/export/unit_colour_underlay.dart';

import '../support/fake_page_printer.dart';
import '../support/recording_exporters.dart';
import '../support/service_fixture.dart';
import '../support/service_rig.dart' show parts;
import '../support/test_kit.dart' show unitKit;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'SP-export-seat a coloured seat\'s fill is placed by its row\'s group '
      'times its instance (M-SP-export)', () {
    final f = serviceFixture();
    final c = PlanController(kits: [unitKit()], json: f.json);
    addTearDown(c.dispose);
    expect(c.setUnitColour('A2', PlanSwatch.teal), isTrue, reason: 'premise');
    final doc = c.document;
    final seat = doc.tree[f.seatsA[1]]! as InstanceNode;
    final row = doc.tree[seat.parent]! as GroupNode;
    final fills = unitColourUnderlay(c.unitIndex, doc, 0.35);
    expect(fills, hasLength(1));
    final PageUnderlayFill fill = fills.single;
    expect(
        parts(fill.placement), parts(row.transform.multiply(seat.transform)));
    expect(fill.argb, (89 << 24) | PlanSwatch.teal.rgb);
  });

  testWidgets(
      'SP-opacity-arg export and print refuse an opacity outside [0, 1] at '
      'the call, naming unitColourOpacity; null is 0.35 (M-SP-check)',
      (tester) async {
    final rec = RecordingExporter('acme.text', 'txt', 'text/plain');
    final c = PlanController(
        kits: [unitKit()], json: serviceFixture().json, exporters: [rec]);
    addTearDown(c.dispose);
    for (final bad in [-0.01, 1.01, double.nan, double.infinity]) {
      expect(
          () => c.export(rec.id, PlanExportChoice.initial,
              unitColourOpacity: bad),
          throwsA(isA<ArgumentError>()
              .having((e) => e.name, 'name', 'unitColourOpacity')));
      expect(
          () => c.print(PlanExportChoice.initial,
              printer: FakePagePrinter(), unitColourOpacity: bad),
          throwsA(isA<ArgumentError>()
              .having((e) => e.name, 'name', 'unitColourOpacity')));
    }
    await tester.runAsync(() => c.export(rec.id, PlanExportChoice.initial));
    expect(rec.requests.single.unitColourOpacity, 0.35);
  });

  testWidgets(
      'SP-request a host\'s exporter receives the given opacity '
      '(M-SP-request)', (tester) async {
    final rec = RecordingExporter('acme.text', 'txt', 'text/plain');
    final c = PlanController(
        kits: [unitKit()], json: serviceFixture().json, exporters: [rec]);
    addTearDown(c.dispose);
    await tester.runAsync(() =>
        c.export(rec.id, PlanExportChoice.initial, unitColourOpacity: 0.6));
    expect(rec.requests.single.unitColourOpacity, 0.6);
  });
}
