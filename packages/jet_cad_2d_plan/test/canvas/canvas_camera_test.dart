// Ported from jet_cad_floor_plan/test/host/camera_test.dart; assertions unchanged.
//
// CM5's second half, which Task 8 sent here because it needs a mounted
// canvas (controller ruling R-m): a camera command made before any canvas
// drops a centring not yet performed, and the plan's own first fit still
// frames the page. Task 8's first half (test/controller/camera_test.dart)
// is repeated as the premise. The fitToTables half is 2b's.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/harness.dart';
import '../support/test_kit.dart';

List<double> parts(ViewportTransform t) {
  final m = t.worldToScreenMatrix;
  return [m.a, m.b, m.c, m.d, m.e, m.f];
}

/// [t] panned by [d], by hand.
List<double> panned(ViewportTransform t, Offset d) {
  final m = t.worldToScreenMatrix;
  return [m.a, m.b, m.c, m.d, m.e + d.dx, m.f + d.dy];
}

/// [c]'s canvas in an app at 1440 x 900, pumped as today's `mount` did.
Future<void> mount(WidgetTester tester, PlanController c) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester
      .pumpWidget(MaterialApp(home: Scaffold(body: PlanCanvas(controller: c))));
  await tester.pump();
  await tester.pump();
}

/// The page fitted to [c]'s canvas as the engine fits it, unclamped (the
/// default bounds hold it).
ViewportTransform pageFitOf(PlanController c) => fitToPage(
    c.document.components.get<PageComponent>(c.document.rootHandle)!,
    c.canvasRect.value!.size);

void main() {
  testWidgets(
      'CM5 panBy with no view acts at once and drops a request not yet '
      'performed with its target; the plan\'s own first fit still frames '
      'the page (Task 2 review R-1)', (tester) async {
    final c = controllerFor(kits: [testKit()], json: slabPlanText());
    final before = c.camera.value;
    c.centerOn(const Offset(-2600, 1400), scale: 0.2);
    const d = Offset(37.25, -11.5);
    c.panBy(d);
    expect(parts(c.camera.value), panned(before, d));
    expect(() => c.panBy(const Offset(double.nan, 0)), throwsArgumentError);
    expect(parts(c.camera.value), panned(before, d));
    await mount(tester, c);
    expect(parts(c.camera.value), parts(pageFitOf(c)),
        reason: 'the plan\'s own fit, not centerOn\'s');
  });
}
