// The integration tests' editor rig (spec 3a C6): PlanEditor over a
// controller in planEditorApp, at 1440 x 900, under a zoomed, turned,
// non-reflecting camera; the status line, a key press, a world point's
// global position and the active tool; a plan holding only a page; the kit's
// types in an engine catalog; a controller's live objects of one type. Its
// own copies of the plan library's test fixtures (canvas_fixture.dart's
// pumpDraw and globalOf, design_harness.dart's status and press), which
// another package cannot import, over the public libraries only.
import 'dart:async' show unawaited;

import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, SelectionKey, Tool, ViewportTransform;
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// Pumps [c]'s editor in [locale] in a [window], 1440 x 900 unless
/// given (reset after the test). With [centre], then sets a camera turned
/// by [turn] at [scale] px/mm, **non-reflecting** (a reflection's `b == c`
/// hides a transposition), with [centre] in the middle of the drawing
/// area: the plan library's `pumpDraw` (canvas_fixture.dart:427-443) over
/// PlanEditor. [wrap], when given, wraps the app (a capture boundary, Task
/// 14's RD1; a key of its own, Task 26). [layerPanel] false leaves the
/// editor's layer panel out (Task 27).
Future<void> pumpEditor(WidgetTester tester, PlanController c,
    {Locale locale = const Locale('en'),
    Size window = const Size(1440, 900),
    Vector2? centre,
    double scale = 2,
    double turn = 0.35,
    Widget Function(Widget app)? wrap,
    bool layerPanel = true}) async {
  await tester.binding.setSurfaceSize(window);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // The editor unmounted before the controller is disposed: tear-downs run
  // last added first, and the caller's `addTearDown(c.dispose)` comes
  // before this call. A controller disposed under a mounted editor makes
  // one failing test cascade into the next ("DiagnosticsLog used after
  // dispose").
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  final app = planEditorApp(c, locale: locale, layerPanel: layerPanel);
  await tester.pumpWidget(wrap == null ? app : wrap(app));
  await tester.pump();
  if (centre == null) return;
  centreCamera(tester, c, centre, scale: scale, turn: turn, yUp: false);
  await tester.pump();
}

/// Sets [c]'s camera with world [centre] in the middle of the drawing
/// area, at [scale] px/mm, turned by [turn] rad; y up when [yUp] (the
/// canvas rig's `frameOn`), else non-reflecting ([pumpEditor]). No pump.
void centreCamera(WidgetTester tester, PlanController c, Vector2 centre,
    {required double scale, required double turn, required bool yUp}) {
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear = Transform2.rotation(turn)
      .multiply(Transform2.scale(scale, yUp ? -scale : scale));
  final mid = linear.transformPoint(centre);
  c.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
}

/// World ([x], [y])'s global position under [c]'s camera.
Offset globalOf(WidgetTester tester, PlanController c, double x, double y) {
  final s = c.camera.value.worldToScreen(Vector2(x, y));
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

/// World [p]'s global position ([globalOf] over a point).
Offset globalAt(WidgetTester tester, PlanController c, Vector2 p) =>
    globalOf(tester, c, p.x, p.y);

/// The editor's status line (`status-text`).
String status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('status-text'))).data!;

/// Sends [key], then a pump: whether a handler took it.
Future<bool> press(WidgetTester tester, LogicalKeyboardKey key) async {
  final handled = await tester.sendKeyEvent(key);
  await tester.pump();
  return handled;
}

/// A primary click at world [p] plus the raw offset `(dx, dy)` in mm, then
/// a frame (R-P14: the one copy of wall_shell's, room_plans' clickAt).
Future<void> clickAt(WidgetTester tester, PlanController c, Vector2 p,
    [double dx = 0, double dy = 0]) async {
  await tester.tapAt(globalAt(tester, c, Vector2(p.x + dx, p.y + dy)));
  await tester.pump();
}

/// A mouse drag from world [from] to world [to], past the slop at once,
/// then [pumps] frames (R-P14: the one copy of wall_shell's,
/// opening_support's and room_plans' dragWorld; the room tests pump 2).
Future<void> dragWorld(
    WidgetTester tester, PlanController c, Vector2 from, Vector2 to,
    {int pumps = 1}) async {
  final a = globalAt(tester, c, from), b = globalAt(tester, c, to);
  final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
  await gesture.down(a);
  await gesture.moveTo(a + const Offset(12, 0));
  await gesture.moveTo(b);
  await gesture.up();
  await gesture.removePointer();
  for (var i = 0; i < pumps; i++) {
    await tester.pump();
  }
}

/// Cmd+Z, then [pumps] frames: the document's change stream delivers
/// after the task (R-P14: the one copy of wall_shell's, room_plans' and
/// opening_support's undoKey; the opening tests pump 1).
Future<void> undoKey(WidgetTester tester, {int pumps = 2}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  for (var i = 0; i < pumps; i++) {
    await tester.pump();
  }
}

/// The design's selection replaced by [hs], as roots, then a frame (R-P14:
/// the one copy of room_plans' and opening_support's select).
Future<void> select(
    WidgetTester tester, PlanController c, List<Handle> hs) async {
  c.activeSelection.replace([for (final h in hs) SelectionKey.root(h)]);
  await tester.pump();
}

/// The canvas's active tool, as its interaction layer holds it: a kit's
/// tool in the plan library's guard, which forwards `isMidShape`.
Tool activeTool(WidgetTester tester) =>
    tester.widget<InteractionLayer>(find.byType(InteractionLayer)).tools.active;

/// A plan holding [page] and nothing else (no manifest kit, no DASHED
/// record): `jet_cad_floor_plan/test/support/box_rig.dart:16-28`'s
/// `boxDoc`, as the text a controller opens.
String pagePlanJson(PageComponent page) {
  final doc = DraftDocument.empty();
  PageComponent.register(doc.components);
  doc.commands
      .execute(SetComponentCommand<PageComponent>(doc.rootHandle, page));
  doc.commands.clearHistory();
  final json = ensureManifest(DraftDocumentCodec.encodeToString(doc));
  unawaited(doc.dispose());
  return json;
}

/// The kit's types (`architectureKit.types`) in an engine catalog of their
/// own, unguarded: for `ParametricSystem(c.document, kitCatalog()).drift()`.
ParametricCatalog kitCatalog() {
  final catalog = ParametricCatalog();
  for (final type in architectureKit.types) {
    type.registerInto(catalog);
  }
  return catalog;
}

/// [c]'s live objects of [typeId] carrying a `T`, ascending: today's
/// `liveObjectsOf<T>(doc)` through the controller's `typeOf` (E1).
List<Handle> liveOf<T extends Component>(PlanController c, String typeId) => [
      for (final h in c.document.components.withComponent<T>())
        if (c.typeOf(h)?.id == typeId) h,
    ];
