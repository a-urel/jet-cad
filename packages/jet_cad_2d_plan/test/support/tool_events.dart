// Pointer events for the plan's tools without a canvas (Task 12; reused by
// Tasks 13 and 14). Every event goes to the controller's active tool
// through its own ToolContext, resolved through the controller's camera,
// which a test first sets to a rotated, flipped, off-origin view
// ([useTestCamera]) so no fixture sits at the identity transform.
import 'dart:ui' show Offset;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// The test camera's pixels per millimetre.
const double kTestScale = 0.25;

/// Turned by 0.3 rad, y flipped, 0.25 px/mm, the world point
/// (4200, -1300) at the screen point (400, 300).
ViewportTransform testCamera() => ViewportTransform(
    worldToScreenMatrix: Transform2.translation(400, 300)
        .multiply(Transform2.rotation(0.3))
        .multiply(Transform2.scale(kTestScale, -kTestScale))
        .multiply(Transform2.translation(-4200, 1300)));

void useTestCamera(PlanController c) =>
    c.toolController.context.camera.value = testCamera();

/// An event at world [world] as the interaction layer would build it.
ToolPointerEvent eventAt(PlanController c, Vector2 world,
    {int buttons = 0, int pointer = 7}) {
  final cam = c.toolController.context.camera.value;
  final s = cam.worldToScreen(world);
  return ToolPointerEvent(
      screen: Offset(s.x, s.y),
      world: world,
      pointer: pointer,
      buttons: buttons,
      shift: false,
      control: false,
      meta: false,
      alt: false,
      pickRadiusWorld: kPickRadiusPixels / cam.scale);
}

/// A hover, a primary press and a release at [world], to the active tool.
void tapAt(PlanController c, Vector2 world) {
  final tools = c.toolController;
  tools.active.onPointerMove(eventAt(c, world), tools.context);
  tools.active
      .onPointerDown(eventAt(c, world, buttons: kPrimaryButton), tools.context);
  tools.active.onPointerUp(eventAt(c, world), tools.context);
}

/// A primary press at [from], eight moves to [to], [beforeUp], a release.
void dragFrom(PlanController c, Vector2 from, Vector2 to,
    {void Function()? beforeUp}) {
  final tools = c.toolController;
  tools.active.onPointerMove(eventAt(c, from), tools.context);
  tools.active
      .onPointerDown(eventAt(c, from, buttons: kPrimaryButton), tools.context);
  for (var i = 1; i <= 8; i++) {
    final p = from + (to - from) * (i / 8);
    tools.active
        .onPointerMove(eventAt(c, p, buttons: kPrimaryButton), tools.context);
  }
  beforeUp?.call();
  tools.active.onPointerUp(eventAt(c, to), tools.context);
}

/// The root-level lines of [d], ascending by handle.
List<Handle> linesOf(DraftDocument d) {
  final e = d.entities;
  return [
    for (final s in e.liveSlots)
      if (e.kindAt(s) == EntityKind.line && e.ownerAt(s) == d.rootHandle)
        e.handleAt(s),
  ]..sort((a, b) => a.value.compareTo(b.value));
}

/// Draws one line from [a] to [b] with `plan.line`, then arms `plan.select`
/// (which ends the line tool's chain). Returns the line's handle.
Handle drawLine(PlanController c, Vector2 a, Vector2 b) {
  final before = linesOf(c.document).toSet();
  if (!c.selectTool('plan.line')) throw StateError('plan.line refused');
  tapAt(c, a);
  tapAt(c, b);
  c.selectTool('plan.select');
  return linesOf(c.document).singleWhere((h) => !before.contains(h));
}

/// The midpoint of the line [line] of [d] as drawn: the drawing tools snap
/// to the page's grid, so a drawn line's ends are not the points tapped.
Vector2 drawnMidOf(DraftDocument d, Handle line) {
  final e = d.entities;
  final coords = d.geometry.read(e.geomIndexAt(e.slotOf(line)!)).coords;
  return Vector2((coords[0] + coords[2]) / 2, (coords[1] + coords[3]) / 2);
}

/// Lets the document's change stream (asynchronous) reach the controller's
/// history flags (`canUndo`, `canRedo`, `dirty`).
Future<void> settleHistory() => Future<void>.delayed(Duration.zero);
