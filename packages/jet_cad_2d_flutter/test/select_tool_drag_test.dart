import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/services.dart'
    show
        KeyDownEvent,
        KeyRepeatEvent,
        KeyUpEvent,
        LogicalKeyboardKey,
        PhysicalKeyboardKey,
        SystemMouseCursors;
import 'package:flutter/widgets.dart' show KeyEventResult, Offset, SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/flutter_text_measurer.dart';
import 'package:jet_cad_2d_flutter/src/grip_cache.dart';
import 'package:jet_cad_2d_flutter/src/grip_drag.dart';
import 'package:jet_cad_2d_flutter/src/select_tool.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:jet_cad_2d_flutter/src/tool.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/grip_fixture.dart';
import 'support/selection_fixture.dart';

SelectionKey k(Handle h) => SelectionKey.root(h);

Vector2 worldOf(GripRig rig, Offset screen) =>
    rig.camera.value.screenToWorld(Vector2(screen.dx, screen.dy));

/// Every coordinate of [after] is [before]'s plus [delta] — a decision
/// about where geometry landed, so within `Tolerance` (spec D8).
void expectMovedBy(
    GeometryPayload after, GeometryPayload before, Vector2 delta) {
  for (var i = 0; i < before.coords.length; i += 2) {
    expect(after.coords[i], closeTo(before.coords[i] + delta.x, 1e-9));
    expect(after.coords[i + 1], closeTo(before.coords[i + 1] + delta.y, 1e-9));
  }
}

Vector2 rotatedAbout(double x, double y, Vector2 p, double theta) => Vector2(
    p.x + math.cos(theta) * (x - p.x) - math.sin(theta) * (y - p.y),
    p.y + math.sin(theta) * (x - p.x) + math.cos(theta) * (y - p.y));

double normalised(double a) =>
    a > math.pi ? a - 2 * math.pi : (a <= -math.pi ? a + 2 * math.pi : a);

/// The line's body, 30% along: 38 world units from each end and 25 from
/// its midpoint, so no snap point is within the aperture.
const double bodyX = 7046, bodyY = 3032;

void main() {
  test(
      'a click on a grip or on the rotation grip changes nothing (D12, '
      'M-03as); the cursor says what a press would do', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line), k(s.polyline)]);
    final vertex = screenOf(rig.camera, 7130, 3060);

    rig.tool
        .onPointerMove(pointerAt(rig.camera, vertex, buttons: 0), rig.context);
    expect(rig.tool.cursor, SystemMouseCursors.precise);
    expect(rig.grips.hot, isNonNegative);

    rig.tool.onPointerDown(pointerAt(rig.camera, vertex), rig.context);
    expect(rig.tool.pressClass, PressClass.grip);
    release(rig, vertex);
    expect(rig.selection.keys, {k(s.line), k(s.polyline)},
        reason: '02 replace-selected the line here; a grip click does nothing');

    final rotation =
        rotationGripOf(rig.grips.box!, rig.camera.value.worldToScreenMatrix)
            .centre;
    rig.tool.onPointerMove(
        pointerAt(rig.camera, rotation, buttons: 0), rig.context);
    expect(rig.tool.cursor, SystemMouseCursors.grab);
    rig.tool.onPointerDown(pointerAt(rig.camera, rotation), rig.context);
    expect(rig.tool.pressClass, PressClass.rotationGrip);
    release(rig, rotation);
    expect(rig.selection.length, 2);

    rig.tool.onPointerMove(
        pointerAt(rig.camera, screenOf(rig.camera, bodyX, bodyY), buttons: 0),
        rig.context);
    expect(rig.tool.cursor, SystemMouseCursors.move);
    expect(rig.document.commands.undoDepth, 0);
  });

  test('a body drag moves the selection under a rotated camera (M-03a)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    expect(rig.camera.value.worldToScreenMatrix.b, isNot(closeTo(0, 1e-3)));
    expect(rig.camera.value.scale, isNot(closeTo(1, 1e-3)));
    rig.selection.replace([k(s.line)]);
    final before = payloadOf(rig.document, s.line);
    final from = screenOf(rig.camera, bodyX, bodyY);
    final to = from + const Offset(37, -21);
    pressAndMove(rig, from, to);
    expect(rig.tool.dragKind, DragKind.move);
    expect(rig.tool.cursor, SystemMouseCursors.move);
    release(rig, to);
    expectMovedBy(payloadOf(rig.document, s.line), before,
        worldOf(rig, to) - worldOf(rig, from));
  });

  test(
      'no command during a drag; release adds exactly one Compound "Move" '
      '(M-03d, invariants 1 and 4)', () async {
    final s = gripScene();
    final rig = gripRig(s.document);
    final doc = rig.document;
    final labels = <String>[];
    final sub = doc.changes.listen((c) {
      if (c is CommandApplied) labels.add(c.label);
    });
    addTearDown(sub.cancel);
    rig.selection.replace([k(s.line), k(s.instA)]);
    final seed = doc.handleSeed.current;
    final live = doc.entities.liveCount;
    final from = screenOf(rig.camera, bodyX, bodyY);
    pressAndMove(rig, from, from + const Offset(20, 5));
    for (final step in const [Offset(30, 9), Offset(44, 12), Offset(51, 17)]) {
      rig.tool.onPointerMove(pointerAt(rig.camera, from + step), rig.context);
      expect(doc.commands.undoDepth, 0,
          reason: 'nothing is dispatched during a drag');
    }
    release(rig, from + const Offset(51, 17));
    expect(doc.commands.undoDepth, 1);
    await Future<void>.delayed(Duration.zero);
    expect(labels, ['Move']);
    expect(doc.handleSeed.current, seed, reason: 'invariant 4');
    expect(doc.entities.liveCount, live);
    expect(doc.tree[doc.rootHandle]!.transform.isIdentity, isTrue,
        reason: 'the root transform is never written');
  });

  test(
      'a drag back to the press pixel, or snapped back onto its base, adds '
      'nothing (M-03p)', () {
    final s = gripScene();
    final rig = gripRig(s.document, objectSnap: true);
    rig.selection.replace([k(s.line)]);
    final from = screenOf(rig.camera, bodyX, bodyY);
    pressAndMove(rig, from, from + const Offset(40, 0));
    rig.tool.onPointerMove(pointerAt(rig.camera, from), rig.context);
    release(rig, from);
    expect(rig.document.commands.undoDepth, 0,
        reason: 'the same pixel under the same camera is a bit-identical '
            'world point, so Δ == 0');

    // 8 world units along the line from its start: 8.8 px, outside the grip
    // (7 px), inside the aperture (10 px). The base snaps onto the endpoint,
    // and a release 3 px from the endpoint snaps the target onto it too.
    final along = Vector2(7010, 3020) + Vector2(120, 40).normalized() * 8.0;
    final nearEnd = screenOf(rig.camera, along.x, along.y);
    pressAndMove(rig, nearEnd, nearEnd + const Offset(60, -30));
    expect(rig.tool.dragKind, DragKind.move);
    release(rig, screenOf(rig.camera, 7010, 3020) + const Offset(3, 0));
    expect(rig.document.commands.undoDepth, 0,
        reason: 'target == base: Δ is exactly zero');
  });

  test('with grid snap on, on-grid geometry stays on the grid (M-03s)', () {
    final s = gripScene(
        page: PageComponent(originX: 7000, originY: 3000, gridStepMm: 10));
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final from = screenOf(rig.camera, bodyX, bodyY);
    final to = from + const Offset(53, 29);
    pressAndMove(rig, from, to);
    release(rig, to);
    final after = payloadOf(rig.document, s.line);
    expect(after.coords[0], isNot(7010.0), reason: 'the line really moved');
    for (var i = 0; i < 4; i++) {
      final v = after.coords[i] - (i.isEven ? 7000 : 3000);
      expect(
          Tolerance.standard.isZero(v - (v / 10).roundToDouble() * 10), isTrue,
          reason: 'coordinate $i = ${after.coords[i]} left the 10 mm lattice');
    }
  });

  test(
      'a shift-press-drag on an unselected object adds it and moves ortho '
      'in world axes (M-03f)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final line0 = payloadOf(rig.document, s.line);
    final poly0 = payloadOf(rig.document, s.polyline);
    final from = screenOf(rig.camera, 7025, 3115); // the polyline's body
    final to = screenOf(rig.camera, 7065, 3122);
    pressAndMove(rig, from, to, shift: true);
    expect(rig.selection.keys, {k(s.line), k(s.polyline)},
        reason: 'shift at the press toggles the object in (D2, class 3b)');
    release(rig, to, shift: true);
    final dx = worldOf(rig, to).x - worldOf(rig, from).x;
    for (final (after, before) in [
      (payloadOf(rig.document, s.line), line0),
      (payloadOf(rig.document, s.polyline), poly0),
    ]) {
      for (var i = 0; i < before.coords.length; i += 2) {
        expect(after.coords[i], closeTo(before.coords[i] + dx, 1e-9));
        expect(after.coords[i + 1], before.coords[i + 1],
            reason: 'shift during the drag is ortho: the minor world axis '
                'is pinned exactly');
      }
    }
  });

  test(
      'a centre grip moves the whole selection from the grip itself '
      '(M-03at, Ruling 03-9)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.circle), k(s.line)]);
    final circle0 = payloadOf(rig.document, s.circle);
    final line0 = payloadOf(rig.document, s.line);
    // 5 px off the grip's centre, inside kGripHitPixels: the press point
    // and the grip differ, so the base must be the grip's world point
    // (spec D8), not the resolved press point.
    final press = screenOf(rig.camera, 7300, 3250) + const Offset(3, -4);
    final to = press + const Offset(-31, 17);
    pressAndMove(rig, press, to);
    expect(rig.tool.pressClass, PressClass.grip);
    expect(rig.tool.dragKind, DragKind.move);
    release(rig, to);
    final delta = worldOf(rig, to) - Vector2(7300, 3250);
    expectMovedBy(payloadOf(rig.document, s.circle), circle0, delta);
    expectMovedBy(payloadOf(rig.document, s.line), line0, delta);
    expect(payloadOf(rig.document, s.circle).scalars, [25]);
  });

  test('a stretch released near an endpoint lands on it exactly (M-03au)', () {
    final s = gripScene();
    final rig = gripRig(s.document, objectSnap: true);
    rig.selection.replace([k(s.line)]);
    final vertex = screenOf(rig.camera, 7130, 3060);
    final drop = screenOf(rig.camera, 7130, 3100) + const Offset(2, -3);
    pressAndMove(rig, vertex, drop);
    expect(rig.tool.dragKind, DragKind.reshape);
    expect(rig.tool.cursor, SystemMouseCursors.precise);
    release(rig, drop);
    final after = payloadOf(rig.document, s.line);
    expect([after.coords[2], after.coords[3]], [7130, 3100],
        reason: "== : the polyline's endpoint, exactly (spec D8)");
    expect([after.coords[0], after.coords[1]], [7010, 3020]);
  });

  test(
      "coincident grips: the greater handle's end moves, the other object "
      'stays (M-03ai)', () {
    final s = gripScene();
    final doc = s.document;
    final wallA = addEntity(
        doc, doc.rootHandle, EntityKind.line, [7600, 3400, 7650, 3400], []);
    final wallB = addEntity(
        doc, doc.rootHandle, EntityKind.line, [7650, 3400, 7650, 3450], []);
    doc.commands.clearHistory();
    final rig = gripRig(doc, camera: gripCamera(centre: Vector2(7640, 3420)));
    rig.selection.replace([k(wallA), k(wallB)]);
    final corner = screenOf(rig.camera, 7650, 3400);
    pressAndMove(rig, corner, corner + const Offset(15, 20));
    release(rig, corner + const Offset(15, 20));
    expect(payloadOf(doc, wallA).coords, [7600, 3400, 7650, 3400]);
    final b = payloadOf(doc, wallB);
    expect(b.coords[0], isNot(7650.0));
    expect(b.coords.sublist(2), [7650, 3450]);
  });

  test(
      'a rotation turns about the selection box centre, far from the '
      'origin (M-03j)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final before = payloadOf(rig.document, s.line);
    // The line's world box, by hand: (7010, 3020)–(7130, 3060).
    final pivot = Vector2(7070, 3040);
    final grip =
        rotationGripOf(rig.grips.box!, rig.camera.value.worldToScreenMatrix)
            .centre;
    final to = grip + const Offset(-45, 38);
    pressAndMove(rig, grip, to);
    expect(rig.tool.pressClass, PressClass.rotationGrip);
    expect(rig.tool.dragKind, DragKind.rotate);
    expect(rig.tool.cursor, SystemMouseCursors.grabbing);
    release(rig, to);
    final w0 = worldOf(rig, grip) - pivot;
    final w1 = worldOf(rig, to) - pivot;
    final theta = normalised(math.atan2(w1.y, w1.x) - math.atan2(w0.y, w0.x));
    final after = payloadOf(rig.document, s.line);
    for (var i = 0; i < 4; i += 2) {
      final r =
          rotatedAbout(before.coords[i], before.coords[i + 1], pivot, theta);
      expect(after.coords[i], closeTo(r.x, 1e-9));
      expect(after.coords[i + 1], closeTo(r.y, 1e-9));
    }
  });

  test('shift steps the rotation by 15° (M-03w)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final before = payloadOf(rig.document, s.line);
    final pivot = Vector2(7070, 3040);
    final grip =
        rotationGripOf(rig.grips.box!, rig.camera.value.worldToScreenMatrix)
            .centre;
    final w0 = worldOf(rig, grip) - pivot;
    final a0 = math.atan2(w0.y, w0.x);
    // 0.30 rad from the press: 15° steps round it to π/12; 30° steps would
    // round it to π/6.
    final aim = pivot + Vector2(math.cos(a0 + 0.30), math.sin(a0 + 0.30)) * 70;
    final to = screenOf(rig.camera, aim.x, aim.y);
    pressAndMove(rig, grip, to, shift: true);
    final t = rig.tool.selectionPreviewTransform!;
    expect(math.atan2(t.b, t.a), closeTo(math.pi / 12, 1e-12));
    release(rig, to, shift: true);
    final after = payloadOf(rig.document, s.line);
    for (var i = 0; i < 4; i += 2) {
      final r = rotatedAbout(
          before.coords[i], before.coords[i + 1], pivot, math.pi / 12);
      expect(after.coords[i], closeTo(r.x, 1e-9));
      expect(after.coords[i + 1], closeTo(r.y, 1e-9));
    }
  });

  test(
      'permissions at press: no leaf grips, a refused move stays a click, '
      'an instance still moves (M-03ad, M-03av)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    final doc = rig.document;
    doc.commands.permissions = DraftPermissions.runtime;
    rig.selection.replace([k(s.line), k(s.instA)]);
    final vertex = screenOf(rig.camera, 7130, 3060);
    rig.tool.onPointerDown(pointerAt(rig.camera, vertex), rig.context);
    expect(rig.tool.pressClass, PressClass.selectedBody,
        reason: "no leaf grip is live, so the press lands on the line's body");
    final away = vertex + const Offset(30, 10);
    rig.tool.onPointerMove(pointerAt(rig.camera, away), rig.context);
    expect(rig.tool.phase, ToolPhase.pressed,
        reason: 'a move of a selection holding a leaf needs geometry; the '
            'press stays a click (Ruling 03-6)');
    release(rig, away);
    expect(rig.selection.keys, {k(s.line)},
        reason: 'released as a click: replace-select');
    expect(doc.commands.undoDepth, 0);

    rig.selection.replace([k(s.instA)]);
    final a0 = doc.tree[s.instA]! as InstanceNode;
    final body = a0.transform.transformPoint(Vector2(15, 5));
    final from = screenOf(rig.camera, body.x, body.y);
    final to = from + const Offset(-25, 14);
    pressAndMove(rig, from, to);
    release(rig, to);
    expect(doc.commands.undoDepth, 1,
        reason: 'runtime allows transform: a table moves, a wall cannot');
    final a1 = doc.tree[s.instA]! as InstanceNode;
    final delta = worldOf(rig, to) - worldOf(rig, from);
    expect(a1.transform.e, closeTo(a0.transform.e + delta.x, 1e-9));
    expect(a1.transform.f, closeTo(a0.transform.f + delta.y, 1e-9));
  });

  test(
      'class 3b: a refused move never runs before the click toggles once, '
      'net (Ruling 03-6; M-03be)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    final doc = rig.document;
    doc.commands.permissions = DraftPermissions.runtime;
    // s.line starts unselected: a shift-press lands class 3b.
    final vertex = screenOf(rig.camera, bodyX, bodyY);
    rig.tool.onPointerDown(
        pointerAt(rig.camera, vertex, shift: true), rig.context);
    expect(rig.tool.pressClass, PressClass.unselectedBody);
    final away = vertex + const Offset(30, 10);
    rig.tool.onPointerMove(
        pointerAt(rig.camera, away, shift: true), rig.context);
    expect(rig.tool.phase, ToolPhase.pressed,
        reason: 'geometry is refused under runtime; no drag starts past '
            'the slop (Ruling 03-6)');
    expect(rig.selection.keys, isEmpty,
        reason: 'the class 3b toggle is release-time click state; it has '
            'not run yet at the moment the slop is crossed');
    release(rig, away, shift: true);
    expect(rig.selection.keys, {k(s.line)},
        reason: "the click's shift-toggle runs exactly once, net");
    expect(doc.commands.undoDepth, 0, reason: 'no drag ran, so no command');
  });

  test(
      'a camera change mid-drag re-resolves the target from the last '
      'screen point (M-03ac)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final from = screenOf(rig.camera, bodyX, bodyY);
    final to = from + const Offset(40, 25);
    final base = worldOf(rig, from);
    pressAndMove(rig, from, to);
    // A trackpad zoom about another point: no pointer event arrives.
    rig.camera.zoomAt(const Offset(10, 10), 1.5);
    final target = worldOf(rig, to);
    final t = rig.tool.selectionPreviewTransform!;
    expect(t.e, closeTo(target.x - base.x, 1e-9));
    expect(t.f, closeTo(target.y - base.y, 1e-9));
    release(rig, to);
    rig.camera.panBy(const Offset(7, 7));
    expect(rig.tool.selectionPreviewTransform, isNull,
        reason: 'the listener left with the drag (Ruling 03-7)');

    // A second drag on the moved line's body. A listener leaked by the
    // first drag would re-resolve this one twice per camera change.
    final c = payloadOf(rig.document, s.line).coords;
    final again = screenOf(
        rig.camera, c[0] + 0.3 * (c[2] - c[0]), c[1] + 0.3 * (c[3] - c[1]));
    pressAndMove(rig, again, again + const Offset(20, 10));
    expect(rig.tool.dragKind, DragKind.move);
    var notified = 0;
    void count() => notified++;
    rig.tool.addListener(count);
    rig.camera.panBy(const Offset(-5, 3));
    rig.tool.removeListener(count);
    expect(notified, 1,
        reason: 'one camera listener per live drag: _endDrag removed the '
            "first drag's (Ruling 03-7)");
    rig.tool.cancel(rig.context);
  });

  test(
      "every key-down and repeat is the drag's; Escape cancels "
      'byte-identically (M-03aa, M-03l)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line), k(s.instA)]);
    final bytes = snapshot(rig.document);
    final from = screenOf(rig.camera, bodyX, bodyY);
    pressAndMove(rig, from, from + const Offset(40, 25));
    const zDown = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyZ,
        logicalKey: LogicalKeyboardKey.keyZ,
        timeStamp: Duration.zero);
    const zRepeat = KeyRepeatEvent(
        physicalKey: PhysicalKeyboardKey.keyZ,
        logicalKey: LogicalKeyboardKey.keyZ,
        timeStamp: Duration.zero);
    const zUp = KeyUpEvent(
        physicalKey: PhysicalKeyboardKey.keyZ,
        logicalKey: LogicalKeyboardKey.keyZ,
        timeStamp: Duration.zero);
    expect(rig.tool.onKey(zDown, rig.context), KeyEventResult.handled);
    expect(rig.tool.onKey(zRepeat, rig.context), KeyEventResult.handled,
        reason: 'Ruling 03-8: a held cmd+Z repeats');
    expect(rig.tool.onKey(zUp, rig.context), KeyEventResult.ignored);
    expect(rig.tool.phase, ToolPhase.dragging);
    const escape = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.escape,
        logicalKey: LogicalKeyboardKey.escape,
        timeStamp: Duration.zero);
    expect(rig.tool.onKey(escape, rig.context), KeyEventResult.handled);
    expect(rig.tool.phase, ToolPhase.idle);
    expect(snapshot(rig.document), bytes);
    expect(rig.document.commands.undoDepth, 0);
    expect(rig.selection.length, 2,
        reason: 'Escape during a drag cancels the drag, not the selection');
  });

  test('tool activation cancels a drag byte-identically (M-03ao)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final bytes = snapshot(rig.document);
    final from = screenOf(rig.camera, bodyX, bodyY);
    pressAndMove(rig, from, from + const Offset(40, 25));
    final other = SelectTool();
    addTearDown(other.dispose);
    rig.tools.activate(other);
    expect(rig.tool.phase, ToolPhase.idle);
    expect(snapshot(rig.document), bytes);
    rig.tools.activate(rig.tool);
  });

  test('a document change mid-drag: release dispatches nothing (M-03t)', () {
    final s = gripScene();
    final rig = gripRig(s.document);
    rig.selection.replace([k(s.line)]);
    final from = screenOf(rig.camera, bodyX, bodyY);
    final to = from + const Offset(40, 25);
    pressAndMove(rig, from, to);
    final edited = GeometryPayload(
        coords: Float64List.fromList([7010, 3020, 7140, 3080]),
        scalars: Float64List(0));
    rig.document.commands.execute(SetEntityGeometryCommand(s.line, edited));
    release(rig, to);
    expect(rig.document.commands.undoDepth, 1,
        reason: 'the external edit only');
    expect(payloadOf(rig.document, s.line), edited);
  });

  test(
      'a grip or a box gone between the press and the slop leaves the press '
      'a click: no throw, no drag, no command', () async {
    final s = gripScene();
    final rig = gripRig(s.document);
    final doc = rig.document;

    // The line's end grip is ordinal 1 of the first object; once the line
    // is gone, index 1 of the rebuilt list is the polyline's vertex 1.
    rig.selection.replace([k(s.line), k(s.polyline)]);
    final vertex = screenOf(rig.camera, 7130, 3060);
    rig.tool.onPointerDown(pointerAt(rig.camera, vertex), rig.context);
    expect(rig.tool.pressClass, PressClass.grip);
    // A cmd+Z inside the slop reaches the shell: keys are the drag's only
    // while dragging.
    doc.commands.execute(RemoveEntityCommand(s.line));
    await Future<void>.delayed(Duration.zero);
    expect(rig.grips.grips.any((r) => r.key == k(s.line)), isFalse,
        reason: 'the grip cache rebuilt without the line');
    final away = vertex + const Offset(30, 10);
    rig.tool.onPointerMove(pointerAt(rig.camera, away), rig.context);
    expect(rig.tool.phase, ToolPhase.pressed,
        reason: 'the pressed grip is gone: the press stays a click');
    release(rig, away);
    expect(doc.commands.undoDepth, 1, reason: 'the removal only');

    // The rotation grip over a selection that empties: no box, no rotate.
    rig.selection.replace([k(s.circle)]);
    final rotation =
        rotationGripOf(rig.grips.box!, rig.camera.value.worldToScreenMatrix)
            .centre;
    rig.tool.onPointerDown(pointerAt(rig.camera, rotation), rig.context);
    expect(rig.tool.pressClass, PressClass.rotationGrip);
    doc.commands.execute(RemoveEntityCommand(s.circle));
    await Future<void>.delayed(Duration.zero);
    expect(rig.grips.box, isNull);
    rig.tool.onPointerMove(
        pointerAt(rig.camera, rotation + const Offset(-30, 20)), rig.context);
    expect(rig.tool.phase, ToolPhase.pressed);
    release(rig, rotation + const Offset(-30, 20));
    expect(doc.commands.undoDepth, 2, reason: 'the two removals only');
  });

  testWidgets('a pointer cancel leaves the document byte-identical (M-03ao)',
      (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = gripScene(measurer: measurer);
    final rig = gripRig(s.document,
        camera:
            gripCamera(viewport: kGripLayerSize, centre: Vector2(7070, 3040)));
    await pumpGripLayer(tester, rig);
    rig.selection.replace([k(s.line)]);
    await tester.pump();
    final bytes = snapshot(rig.document);
    final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    final from = globalAt(tester, screenOf(rig.camera, bodyX, bodyY));
    await gesture.down(from);
    await gesture.moveTo(from + const Offset(30, 20));
    expect(rig.tool.dragKind, DragKind.move);
    await gesture.cancel();
    await tester.pump();
    expect(rig.tool.phase, ToolPhase.idle);
    expect(snapshot(rig.document), bytes);
  });

  testWidgets(
      "a move dragged past the layer's edge continues and lands "
      '(M-03ap)', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = gripScene(measurer: measurer);
    final rig = gripRig(s.document,
        camera:
            gripCamera(viewport: kGripLayerSize, centre: Vector2(7070, 3040)));
    await pumpGripLayer(tester, rig);
    rig.selection.replace([k(s.line)]);
    await tester.pump();
    final before = payloadOf(rig.document, s.line);
    final fromLocal = screenOf(rig.camera, bodyX, bodyY);
    final outside = Offset(kGripLayerSize.width + 50, fromLocal.dy);
    final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    await gesture.down(globalAt(tester, fromLocal));
    await gesture.moveTo(globalAt(tester, fromLocal + const Offset(30, 0)));
    await gesture.moveTo(globalAt(tester, outside));
    await tester.pump();
    expect(rig.tool.dragKind, DragKind.move,
        reason: 'pointer exit is not a cancel path (spec D5, 02 amended)');
    await gesture.up();
    await tester.pump();
    expectMovedBy(payloadOf(rig.document, s.line), before,
        worldOf(rig, outside) - worldOf(rig, fromLocal));
  });

  testWidgets('removing the layer mid-drag cancels byte-identically (M-03ao)',
      (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final s = gripScene(measurer: measurer);
    final rig = gripRig(s.document,
        camera:
            gripCamera(viewport: kGripLayerSize, centre: Vector2(7070, 3040)));
    await pumpGripLayer(tester, rig);
    rig.selection.replace([k(s.line)]);
    await tester.pump();
    final bytes = snapshot(rig.document);
    final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    final from = globalAt(tester, screenOf(rig.camera, bodyX, bodyY));
    await gesture.down(from);
    await gesture.moveTo(from + const Offset(30, 20));
    expect(rig.tool.dragKind, DragKind.move);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(rig.tool.phase, ToolPhase.idle,
        reason: "the layer's deactivate/dispose cancels the tool");
    expect(snapshot(rig.document), bytes);
    // The captured pointer's up still reaches the unmounted layer's
    // Listener callback; the idle tool ignores it.
    await gesture.up();
  });
}
