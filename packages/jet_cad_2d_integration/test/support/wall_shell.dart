// The wall cases' shell harness (jet_cad_floor_plan/test/wall_tool_test.dart
// :37-118 and wall_grips_test.dart:36-121), over the editor rig (R-P14:
// pumpEditor, globalOf, globalAt, status, press are the rig's): a plan of the
// architecture kit built in a new plan's document and saved, so the
// controller opens it as a file with no undo history; the pointer and key
// gestures of today's cases; the Wall tool's settings set through the
// property panel's settings fields. Public libraries only (R-P1).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'editor_rig.dart';
import 'wall_fixture.dart';

/// The pages' fixed grid step (wall_tool_test.dart:34,
/// wall_grips_test.dart:35).
const double gridStep = 10;

/// Today's 1:20 page near the far origin, grid snap on at [gridStep].
PageComponent wallPage() => PageComponent(
    scaleDenominator: 20,
    originX: ox - 2000,
    originY: oy - 2000,
    gridStepMm: gridStep);

/// A plan of the architecture kit as a file: a new plan's document given
/// [page], then [build] run on it (the kit's system regenerates what it
/// adds), saved through the controller (its manifest names the kit).
/// Opened, it has no undo history (today's fixtures' `clearHistory`).
String wallPlanJson(
    PageComponent page, void Function(DraftDocument doc) build) {
  final c = architectureController();
  try {
    c.document.commands.execute(
        SetComponentCommand<PageComponent>(c.document.rootHandle, page));
    build(c.document);
    return c.save();
  } finally {
    c.dispose();
  }
}

/// A controller over [plan], disposed at tear-down.
PlanController wallController(String plan) {
  final c = architectureController(json: plan);
  addTearDown(c.dispose);
  return c;
}

/// A click near [p]: 12 mm and -9 mm off, well inside the aperture.
Future<void> clickNear(WidgetTester tester, PlanController c, Vector2 p) =>
    clickAt(tester, c, p, 12, -9);

/// The page grid's point nearest [p], as the drag chain computes it.
Vector2 gridOf(DraftDocument doc, Vector2 p) =>
    snapToGrid(p, gridStep, doc.components.get<PageComponent>(doc.rootHandle)!);

/// Sets the active Wall tool's settings through the property panel's
/// settings fields, as today's cases set the tool's notifier
/// (`wallTool(tester).settings.value = ...`, ruling R12-1): [thickness]
/// typed and committed with Enter (which hands the focus back to the
/// canvas), then [justification] picked from its menu.
Future<void> setWallSettings(WidgetTester tester,
    {required String thickness, required Justification justification}) async {
  await tester.enterText(find.byKey(const Key('setting-thickness')), thickness);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.tap(find.byKey(const Key('setting-justification')));
  await tester.pumpAndSettle();
  await tester
      .tap(find.byKey(Key('setting-justification-${justification.name}')).last);
  await tester.pumpAndSettle();
}

/// Selects wall [h] with a click in the middle of its band, 40% along it,
/// away from both of its grips (wall_grips_test.dart:84-93).
Future<void> selectWall(WidgetTester tester, PlanController c, Handle h) async {
  final w = worldWallOf(c.document, h);
  final n = Vector2(-w.d.y, w.d.x);
  final (l, r) = facesOf(c.document.components.get<WallParams>(h)!);
  await tester
      .tapAt(globalAt(tester, c, w.s + (w.e - w.s) * 0.4 + n * ((l + r) / 2)));
  await tester.pump();
  expect(c.activeSelection.keys, [SelectionKey.root(h)]);
}

/// Wall [h]'s end [k] in world.
Vector2 endOf(DraftDocument doc, Handle h, int k) =>
    worldWallOf(doc, h).endpoint(k);
