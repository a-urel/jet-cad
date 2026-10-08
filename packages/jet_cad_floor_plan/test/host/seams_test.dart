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
    await tester.pumpWidget(
        MaterialApp(home: PlannerShell(document: doc, selection: selection)));
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

  testWidgets(
      'SM3 a fit asks the shell\'s framing at the drawing area\'s size; '
      'null from it fits as before (zone spec Z7, M-Z15)', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final requests = _Requests();
    addTearDown(requests.dispose);
    final framed = ViewportTransform(
        worldToScreenMatrix: Transform2(0.37, 0, 0, -0.37, -14800.5, 9950.25));
    final asked = <Size>[];
    ViewportTransform? answer = framed;
    await tester.pumpWidget(MaterialApp(
        home: PlannerShell(
            document: startupPlan(measurer),
            fitRequests: requests,
            framing: (size) {
              asked.add(size);
              return answer;
            })));
    await tester.pump();
    await tester.pump();
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    final area = tester.getSize(find.byType(InteractionLayer));
    expect(asked, [area], reason: 'the first frame\'s fit');
    expect(view.camera.value, same(framed));

    answer = null;
    requests.bump();
    await tester.pump();
    expect(asked, [area, area]);
    final page = view.camera.value.worldToScreenMatrix;
    expect(page.a, isNot(0.37), reason: 'the page');

    answer = framed;
    requests.bump();
    await tester.pump();
    expect(view.camera.value, same(framed));
  });
}
