import 'package:floor_planner/main.dart';
import 'package:floor_planner/parametric/box.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// A 1:20 page anchored at (7000, 3000), grid snap off, and no entities.
/// `DraftCanvas` needs a `FlutterTextMeasurer`.
///
/// Copied from `planner_draw_test.dart`'s `drawDoc` (never import a test
/// file), less the seed line: the Box tool tests start from an empty page.
DraftDocument boxDoc(FlutterTextMeasurer m) {
  final doc = DraftDocument.empty(measurer: m);
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          scaleDenominator: 20,
          originX: 7000,
          originY: 3000,
          snapToGrid: false)));
  doc.commands.clearHistory();
  return doc;
}

/// Pumps the shell, then sets a zoomed, rotated, **non-reflecting** camera:
/// the app camera in `planner_grips_test.dart` is a reflection, whose
/// `b == c` hides a transposition.
///
/// Copied from `planner_draw_test.dart`'s `pumpDraw` (never import a test
/// file).
Future<PlannerView> pumpDraw(WidgetTester tester, DraftDocument doc) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: PlannerShell(document: doc)));
  await tester.pump();
  final view = tester.widget<PlannerView>(find.byType(PlannerView));
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear = Transform2.rotation(0.35).multiply(Transform2.scale(2.0, 2.0));
  final mid = linear.transformPoint(Vector2(7150, 3110));
  view.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
  return view;
}

/// Copied from `planner_draw_test.dart`'s `globalOf`.
Offset globalOf(WidgetTester tester, PlannerView view, double x, double y) {
  final s = view.camera.value.worldToScreen(Vector2(x, y));
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

/// Copied from `planner_draw_test.dart`'s `status`.
String status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('status-text'))).data!;

/// Copied from `planner_draw_test.dart`'s `press`.
Future<bool> press(WidgetTester tester, LogicalKeyboardKey key) async {
  final handled = await tester.sendKeyEvent(key);
  await tester.pump();
  return handled;
}

/// Copied from `planner_draw_test.dart`'s `bytes`.
String bytes(PlannerView view) =>
    DraftDocumentCodec.encodeToString(view.document);

/// [box]'s generated children, ascending: the group's own leaves, found by
/// owner (spec 06 D3) -- never by walking `GroupNode.children`, which the
/// parametric mechanism never populates for a leaf it generates.
List<Handle> boxKids(DraftDocument doc, Handle box) => [
      for (final slot in doc.leavesByOwner()[box] ?? const <int>[])
        doc.entities.handleAt(slot),
    ];

/// Every handle carrying a `BoxParams` component, ascending
/// (`ComponentStore.handles` is already sorted).
List<Handle> boxes(DraftDocument doc) =>
    doc.components.withComponent<BoxParams>().toList();

/// Draws two overlapping boxes: B, then BX4's four clicks, then a pump.
/// Copied from `planner_box_test.dart`'s BX4.
Future<void> drawTwoBoxes(WidgetTester tester, PlannerView view) async {
  await press(tester, LogicalKeyboardKey.keyB);
  await tester.tapAt(globalOf(tester, view, 7010, 3020));
  await tester.tapAt(globalOf(tester, view, 7130, 3090));
  await tester.tapAt(globalOf(tester, view, 7100, 3060));
  await tester.tapAt(globalOf(tester, view, 7190, 3120));
  await tester.pump();
}
