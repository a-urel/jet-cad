// Spec 14b-2 H8, R-5: the shell's two seams for an embedding host -- a
// selection it is handed and does not dispose, and fit requests -- and
// PlannerView without grips or a text tool.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/planner_shell.dart';
import 'package:jet_cad_floor_plan/src/planner_view.dart';
import 'package:jet_cad_floor_plan/src/startup_plan.dart';

/// A counter whose every bump notifies.
class _Requests extends ChangeNotifier {
  void bump() => notifyListeners();
}

void main() {
  testWidgets(
      'SM1 a host selection is used, and outlives the shell (M-14b2-10)',
      (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = startupPlan(measurer);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    await tester.pumpWidget(MaterialApp(
        home: PlannerShell(document: doc, selection: selection)));
    await tester.pump();
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    expect(view.selection, same(selection));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    // Still alive: a disposed ChangeNotifier asserts on addListener.
    var heard = 0;
    void listener() => heard++;
    selection.addListener(listener);
    final first = doc.tree.nodes.firstWhere((n) => n.parent == doc.rootHandle);
    selection.replace([SelectionKey.root(first.handle)]);
    expect(heard, 1);
    selection.removeListener(listener);
  });

  testWidgets('SM2 a fit request refits the camera at the view\'s size',
      (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final requests = _Requests();
    addTearDown(requests.dispose);
    await tester.pumpWidget(MaterialApp(
        home: PlannerShell(
            document: startupPlan(measurer), fitRequests: requests)));
    await tester.pump();
    await tester.pump();
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    final fitted = view.camera.value.worldToScreenMatrix;

    view.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2(0.01, 0, 0, -0.01, 37, 411));
    await tester.pump();
    expect(view.camera.value.worldToScreenMatrix.a, 0.01);

    requests.bump();
    await tester.pump();
    final again = view.camera.value.worldToScreenMatrix;
    expect([again.a, again.b, again.c, again.d, again.e, again.f],
        [fitted.a, fitted.b, fitted.c, fitted.d, fitted.e, fitted.f]);
  });
}
